import 'dart:async';
import 'package:shieldnet/core/utils/logger.dart';
import '../database/database_helper.dart';
import '../network/api_service.dart';

/// Résultat du traitement de la file d'attente hors-ligne
class OfflineFlushResult {
  final int syncedReports;
  final int syncedDisputes;
  final int failedItems;

  const OfflineFlushResult({
    required this.syncedReports,
    required this.syncedDisputes,
    required this.failedItems,
  });

  int get totalSynced => syncedReports + syncedDisputes;
  bool get hasWorkDone => totalSynced > 0;
}

/// Service de gestion et de vidage de la file d'attente hors-ligne (Offline Queue)
/// Rejoue automatiquement les signalements et contestations enregistrés hors connexion
/// dès que le réseau redevient disponible.
class OfflineSyncService {
  final DatabaseHelper _db;
  final ApiService _api;
  bool _isFlushing = false;

  OfflineSyncService({DatabaseHelper? db, ApiService? api})
      : _db = db ?? DatabaseHelper.instance,
        _api = api ?? ApiService();

  static final OfflineSyncService instance = OfflineSyncService();

  /// Indique si un vidage de la file est actuellement en cours
  bool get isFlushing => _isFlushing;

  /// Retourne le nombre d'actions en attente
  Future<int> getPendingCount() async {
    try {
      return await _db.getPendingTotalCount();
    } catch (e) {
      AppLogger.log('[OfflineSync] Erreur lecture compteur file: $e');
      return 0;
    }
  }

  /// Vide la file d'attente en rejouant les requêtes auprès du serveur
  Future<OfflineFlushResult> flushQueue() async {
    if (_isFlushing) {
      AppLogger.log('[OfflineSync] Vidage déjà en cours, requête ignorée.');
      return const OfflineFlushResult(syncedReports: 0, syncedDisputes: 0, failedItems: 0);
    }

    _isFlushing = true;
    int syncedReports = 0;
    int syncedDisputes = 0;
    int failedItems = 0;

    try {
      // 1. Rejouer les signalements indésirables en attente
      final pendingReports = await _db.getPendingReports();
      for (final report in pendingReports) {
        if (report.id == null) continue;
        try {
          final success = await _api.submitSpamReport(
            rawPhoneNumber: report.rawNumber,
            category: report.category,
            comment: report.comment,
          );

          if (success) {
            await _db.deletePendingReport(report.id!);
            syncedReports++;
            AppLogger.log('[OfflineSync] Signalement #${report.id} synchronisé avec succès.');
          } else {
            await _db.incrementPendingReportRetry(report.id!);
            failedItems++;
          }
        } catch (e) {
          await _db.incrementPendingReportRetry(report.id!);
          failedItems++;
          AppLogger.log('[OfflineSync] Échec rejeu signalement #${report.id}: $e');
        }
      }

      // 2. Rejouer les contestations légitimes en attente
      final pendingDisputes = await _db.getPendingSafeDisputes();
      for (final dispute in pendingDisputes) {
        if (dispute.id == null) continue;
        try {
          final res = await _api.submitSafeReport(
            rawPhoneNumber: dispute.rawNumber,
            phoneHash: dispute.phoneHash,
            maskedNumber: dispute.maskedNumber,
            reason: dispute.reason,
            comment: dispute.comment,
          );

          if (res != null) {
            await _db.deletePendingSafeDispute(dispute.id!);
            syncedDisputes++;
            AppLogger.log('[OfflineSync] Contestation #${dispute.id} synchronisée avec succès.');
          } else {
            await _db.incrementPendingSafeDisputeRetry(dispute.id!);
            failedItems++;
          }
        } catch (e) {
          await _db.incrementPendingSafeDisputeRetry(dispute.id!);
          failedItems++;
          AppLogger.log('[OfflineSync] Échec rejeu contestation #${dispute.id}: $e');
        }
      }

      await _db.checkpointWAL();
    } catch (e) {
      AppLogger.log('[OfflineSync] Erreur globale lors du vidage: $e');
    } finally {
      _isFlushing = false;
    }

    return OfflineFlushResult(
      syncedReports: syncedReports,
      syncedDisputes: syncedDisputes,
      failedItems: failedItems,
    );
  }
}
