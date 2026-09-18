import 'package:shared_preferences/shared_preferences.dart';
import 'package:shieldnet/core/utils/logger.dart';
import 'package:dio/dio.dart';
import '../database/database_helper.dart';
import '../security/crypto_utils.dart';
import 'api_client.dart';

class ApiService {
  final Dio _dio;

  ApiService({Dio? dio}) : _dio = dio ?? ApiClient.createDio();

  /// Synchronise la liste noire globale depuis le serveur backend vers la base SQLite locale.
  /// Prend en charge la synchronisation différentielle (delta sync) et la purge locale
  /// des faux-positifs débloqués ou blanchis par les administrateurs.
  Future<int> syncBlacklistWithBackend({bool delta = true}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      Map<String, dynamic>? queryParams;

      if (delta) {
        final lastSync = prefs.getString('last_sync_timestamp');
        if (lastSync != null && lastSync.isNotEmpty) {
          queryParams = {'since': lastSync};
        }
      }

      final response = await _dio.get('blacklist/', queryParameters: queryParams);

      if (response.statusCode == 200 && response.data != null) {
        // Cas 1 : Réponse Delta (Dictionnaire avec 'active' et 'removed')
        if (response.data is Map) {
          final map = response.data as Map;
          final List rawActive = (map['active'] as List?) ?? [];
          final List<String> removedHashes = ((map['removed'] as List?) ?? [])
              .map((e) => e.toString())
              .toList();

          // 1. Insertion / mise à jour par lot des numéros actifs
          final activeNumbers = rawActive.map((item) {
            return BlacklistedNumber.fromMap({
              'phone_hash': item['phone_hash'],
              'masked_number': item['masked_number'],
              'category': item['category'],
              'risk_score': item['risk_score'],
              'reports_count': item['reports_count'],
              'updated_at': item['updated_at'] ?? DateTime.now().toIso8601String(),
            });
          }).toList();

          if (activeNumbers.isNotEmpty) {
            await DatabaseHelper.instance.batchInsertOrUpdateBlacklistedNumbers(activeNumbers);
          }

          // 2. Purge locale des faux positifs blanchis par l'admin
          if (removedHashes.isNotEmpty) {
            final purgedCount = await DatabaseHelper.instance.deleteBatchBlacklistedNumbers(removedHashes);
            AppLogger.log("[Sync] Purge de $purgedCount faux-positifs réussie.");
          }

          // 3. Mémoriser le timestamp de synchronisation
          final serverSyncTime = map['sync_timestamp'] as String? ?? DateTime.now().toIso8601String();
          await prefs.setString('last_sync_timestamp', serverSyncTime);

          return activeNumbers.length + removedHashes.length;
        }

        // Cas 2 : Réponse Liste Complète standard
        if (response.data is List) {
          final List data = response.data;
          final numbers = data.map((item) {
            return BlacklistedNumber.fromMap({
              'phone_hash': item['phone_hash'],
              'masked_number': item['masked_number'],
              'category': item['category'],
              'risk_score': item['risk_score'],
              'reports_count': item['reports_count'],
              'updated_at': item['updated_at'] ?? DateTime.now().toIso8601String(),
            });
          }).toList();

          if (numbers.isNotEmpty) {
            await DatabaseHelper.instance.batchInsertOrUpdateBlacklistedNumbers(numbers);
          }

          await prefs.setString('last_sync_timestamp', DateTime.now().toIso8601String());
          return numbers.length;
        }
      }
      return 0;
    } catch (e) {
      AppLogger.log("Erreur de synchronisation réseau: $e");
      return 0;
    }
  }

  /// Récupère le statut global de synchronisation et la version actuelle
  Future<Map<String, dynamic>?> getSyncStatus() async {
    try {
      final response = await _dio.get('sync/status/');
      if (response.statusCode == 200 && response.data is Map) {
        return response.data as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      AppLogger.log("Erreur récupération statut synchronisation: $e");
      return null;
    }
  }

  /// Soumet un nouveau signalement indésirable au backend
  Future<bool> submitSpamReport({
    required String rawPhoneNumber,
    required String category,
    String? comment,
  }) async {
    final phoneHash = await CryptoUtils.hashPhoneNumberAsync(rawPhoneNumber);
    final maskedNumber = CryptoUtils.maskPhoneNumber(rawPhoneNumber);

    try {
      final response = await _dio.post(
        'reports/',
        data: {
          'phone_hash': phoneHash,
          'masked_number': maskedNumber,
          'category': category,
          'comment': comment ?? '',
        },
      );
      
      if (response.statusCode == 201) {
        // Mettre à jour le cache local immédiatement
        await DatabaseHelper.instance.insertOrUpdateBlacklistedNumber(
          BlacklistedNumber(
            phoneHash: phoneHash,
            maskedNumber: maskedNumber,
            category: category,
            riskScore: response.data['risk_score'] ?? 50,
            reportsCount: response.data['reports_count'] ?? 1,
            updatedAt: DateTime.now().toIso8601String(),
          ),
        );
        return true;
      }
      return false;
    } catch (e) {
      AppLogger.log("Erreur envoi signalement: $e");
      return false;
    }
  }

  /// Vérifie le score de risque d'un numéro auprès du serveur
  Future<Map<String, dynamic>?> checkNumberOnBackend(String rawPhoneNumber) async {
    final phoneHash = await CryptoUtils.hashPhoneNumberAsync(rawPhoneNumber);
    try {
      final response = await _dio.get('check/$phoneHash/');
      if (response.statusCode == 200) {
        return response.data as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      AppLogger.log("Erreur vérification numéro: $e");
      return null;
    }
  }

  /// Soumet un avis favorable ou une contestation de faux-positif au serveur Django
  Future<Map<String, dynamic>?> submitSafeReport({
    required String rawPhoneNumber,
    required String reason,
    String? comment,
  }) async {
    final phoneHash = await CryptoUtils.hashPhoneNumberAsync(rawPhoneNumber);
    final maskedNumber = CryptoUtils.maskPhoneNumber(rawPhoneNumber);

    try {
      final response = await _dio.post(
        'reports/safe/',
        data: {
          'phone_hash': phoneHash,
          'masked_number': maskedNumber,
          'reason': reason,
          'comment': comment ?? '',
        },
      );
      if (response.statusCode == 200 && response.data is Map) {
        return response.data as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      AppLogger.log("Erreur envoi contestation légitime: $e");
      return null;
    }
  }
}

