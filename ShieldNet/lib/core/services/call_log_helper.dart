import 'package:call_log/call_log.dart';
import 'package:permission_handler/permission_handler.dart';
import '../utils/logger.dart';

/// Helper thread-safe pour interroger le journal d'appels natif sans risque
/// de collision d'appels de méthode ou de crash "Reply already submitted" dans sk.fourq.calllog.
class CallLogHelper {
  static Future<Iterable<CallLogEntry>>? _inFlightQuery;

  /// Récupère les entrées du journal d'appels de façon atomique et sécurisée.
  /// Si une requête est déjà en cours, attend son résultat plutôt que d'émettre
  /// un appel concurrent sur le MethodChannel Android.
  static Future<List<CallLogEntry>> getSafeEntries({int limit = 50}) async {
    try {
      final status = await Permission.phone.status;
      if (!status.isGranted) {
        return const [];
      }

      if (_inFlightQuery != null) {
        final existing = await _inFlightQuery!;
        return existing.take(limit).toList();
      }

      _inFlightQuery = CallLog.get();
      final entries = await _inFlightQuery!;
      return entries.take(limit).toList();
    } catch (e) {
      AppLogger.log('[CallLogHelper] Erreur sécurisée lors de la lecture du journal d\'appels: $e');
      return const [];
    } finally {
      _inFlightQuery = null;
    }
  }
}
