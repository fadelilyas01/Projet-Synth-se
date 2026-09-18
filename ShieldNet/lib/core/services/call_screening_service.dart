import 'package:shieldnet/core/utils/logger.dart';
import 'package:flutter/services.dart';

/// Service Dart communiquant avec la couche native (Android / iOS)
class CallScreeningService {
  static const MethodChannel _channel = MethodChannel('com.shieldnet.shieldnet/call_screening');

  /// Demande à l'utilisateur de définir ShieldNet comme application de filtrage par défaut
  Future<bool> requestCallScreeningRole() async {
    try {
      final bool active = await _channel.invokeMethod('requestCallScreeningRole');
      return active;
    } on PlatformException catch (e) {
      AppLogger.log("Erreur demande rôle CallScreening: ${e.message}");
      return false;
    }
  }

  /// Vérifie si le rôle de filtrage est actif
  Future<bool> isCallScreeningActive() async {
    try {
      final bool active = await _channel.invokeMethod('isCallScreeningActive');
      return active;
    } on PlatformException catch (e) {
      AppLogger.log("Erreur statut CallScreening: ${e.message}");
      return false;
    }
  }

  /// Teste le pont natif SQLite <-> Kotlin en interrogeant directement Android
  Future<Map<String, dynamic>> testDatabaseBridge() async {
    try {
      final result = await _channel.invokeMethod('testDatabaseBridge');
      if (result is Map) {
        return Map<String, dynamic>.from(result);
      }
      return {
        'connected': false,
        'message': 'Format de réponse invalide',
      };
    } on PlatformException catch (e) {
      return {
        'connected': false,
        'message': 'Erreur plateforme: ${e.message}',
      };
    } catch (e) {
      return {
        'connected': false,
        'message': 'Erreur inattendue: $e',
      };
    }
  }

  /// Demande à la couche native Kotlin de tester si un numéro est bloqué
  Future<bool> checkNumberWithNative(String phoneNumber) async {
    try {
      final bool? isBlocked = await _channel.invokeMethod<bool>(
        'checkNumber',
        {'number': phoneNumber},
      );
      return isBlocked ?? false;
    } catch (e) {
      AppLogger.log("Erreur vérification numéro via pont natif: $e");
      return false;
    }
  }

  /// Active ou désactive le mode Contacts Uniquement dans la couche native
  Future<bool> setContactsOnlyMode(bool enabled) async {
    try {
      final bool? success = await _channel.invokeMethod<bool>(
        'setContactsOnlyMode',
        {'enabled': enabled},
      );
      return success ?? false;
    } catch (e) {
      AppLogger.log("Erreur activation mode contacts uniquement: $e");
      return false;
    }
  }

  /// Vérifie si le mode Contacts Uniquement est actif côté natif
  Future<bool> isContactsOnlyMode() async {
    try {
      final bool? active = await _channel.invokeMethod<bool>('isContactsOnlyMode');
      return active ?? false;
    } catch (e) {
      AppLogger.log("Erreur statut mode contacts uniquement: $e");
      return false;
    }
  }
}
