import 'package:shieldnet/core/utils/logger.dart';
import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import '../network/api_service.dart';
import '../database/database_helper.dart';

const String kPeriodicSyncTask = 'shieldnet_periodic_sync';
const String kOneOffSyncTask = 'shieldnet_oneoff_sync';
const String kSyncTag = 'blacklist_sync';

/// Point d'entrée pour l'exécution en arrière-plan (Workmanager)
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    try {
      try {
        await dotenv.load(fileName: ".env");
      } catch (e) {
        AppLogger.log("[BackgroundSync] Fichier .env non chargé, valeurs par défaut: $e");
      }

      final api = ApiService();
      final count = await api.syncBlacklistWithBackend();
      await DatabaseHelper.instance.checkpointWAL();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_sync_time', DateTime.now().toIso8601String());
      await prefs.setInt('last_sync_count', count);
      await prefs.setString('last_sync_status', 'SUCCESS');

      AppLogger.log("[BackgroundSync] Succès: $count numéros synchronisés et WAL vérifié.");
      return true;
    } catch (e) {
      AppLogger.log("[BackgroundSync] Erreur d'exécution: $e");
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('last_sync_status', 'ERROR: $e');
      } catch (err) {
        AppLogger.log("[BackgroundSync] Échec de l'enregistrement du statut d'erreur: $err");
      }
      return false;
    }
  });
}

class BackgroundSyncService {
  BackgroundSyncService._();
  static final BackgroundSyncService instance = BackgroundSyncService._();

  static const String _keyAutoSync = 'settings_auto_sync_enabled';
  static const String _keyIntervalHours = 'settings_sync_interval_hours';
  static const String _keyLastSync = 'last_sync_time';
  static const String _keyLastCount = 'last_sync_count';
  static const String _keyLastStatus = 'last_sync_status';

  bool _initialized = false;

  /// Initialise WorkManager et planifie la tâche si l'auto-sync est activé
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      await Workmanager().initialize(
        callbackDispatcher,
      );
      _initialized = true;

      final isEnabled = await isAutoSyncEnabled();
      if (isEnabled) {
        final hours = await getSyncIntervalHours();
        await schedulePeriodicSync(hours: hours);
      }
    } catch (e) {
      AppLogger.log("Workmanager initialization warning: $e");
    }
  }

  /// Déclenche une synchronisation immédiate (en avant-plan ou déclenchée par l'UI)
  Future<int> syncNow() async {
    try {
      final api = ApiService();
      final count = await api.syncBlacklistWithBackend();
      await DatabaseHelper.instance.checkpointWAL();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyLastSync, DateTime.now().toIso8601String());
      await prefs.setInt(_keyLastCount, count);
      await prefs.setString(_keyLastStatus, 'SUCCESS');

      return count;
    } catch (e) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyLastStatus, 'ERROR: $e');
      rethrow;
    }
  }

  /// Planifie la synchronisation périodique avec l'intervalle configuré
  Future<void> schedulePeriodicSync({int hours = 1}) async {
    final clampedHours = hours < 1 ? 1 : hours;
    try {
      // Workmanager Android imposes a minimum interval of 15 minutes
      final frequency = Duration(hours: clampedHours);

      await Workmanager().registerPeriodicTask(
        kPeriodicSyncTask,
        kPeriodicSyncTask,
        frequency: frequency,
        tag: kSyncTag,
        constraints: Constraints(
          networkType: NetworkType.connected,
        ),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
      );
      AppLogger.log("[BackgroundSync] Tâche périodique planifiée toutes les $clampedHours h.");
    } catch (e) {
      AppLogger.log("[BackgroundSync] Erreur de planification: $e");
    }
  }

  /// Annule la synchronisation périodique en arrière-plan
  Future<void> cancelPeriodicSync() async {
    try {
      await Workmanager().cancelByUniqueName(kPeriodicSyncTask);
      AppLogger.log("[BackgroundSync] Tâche périodique annulée.");
    } catch (e) {
      AppLogger.log("[BackgroundSync] Erreur lors de l'annulation: $e");
    }
  }

  /// Récupère l'état d'activation de la synchronisation automatique
  Future<bool> isAutoSyncEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyAutoSync) ?? true; // Actif par défaut
  }

  /// Met à jour l'activation de la synchronisation automatique
  Future<void> setAutoSyncEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAutoSync, enabled);
    if (enabled) {
      final hours = await getSyncIntervalHours();
      await schedulePeriodicSync(hours: hours);
    } else {
      await cancelPeriodicSync();
    }
  }

  /// Récupère l'intervalle de synchronisation en heures (défaut: 1 heure)
  Future<int> getSyncIntervalHours() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyIntervalHours) ?? 1;
  }

  /// Met à jour l'intervalle de synchronisation
  Future<void> setSyncIntervalHours(int hours) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyIntervalHours, hours);
    final isEnabled = await isAutoSyncEnabled();
    if (isEnabled) {
      await schedulePeriodicSync(hours: hours);
    }
  }

  /// Récupère les informations de la dernière synchronisation
  Future<Map<String, dynamic>> getLastSyncInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final lastTimeStr = prefs.getString(_keyLastSync);
    final count = prefs.getInt(_keyLastCount) ?? 0;
    final status = prefs.getString(_keyLastStatus) ?? 'NONE';

    DateTime? lastTime;
    if (lastTimeStr != null) {
      lastTime = DateTime.tryParse(lastTimeStr);
    }

    return {
      'lastSyncTime': lastTime,
      'lastSyncCount': count,
      'lastSyncStatus': status,
    };
  }
}
