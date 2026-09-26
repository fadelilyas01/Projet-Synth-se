import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// Utilitaire cryptographique pour la conformité Loi 25 (Québec) et le respect de la vie privée
class CryptoUtils {
  /// Normalise un numéro de téléphone au format E.164 (ex. +18191234567)
  /// pour garantir que deux saisies différentes du même numéro produisent le même Hash.
  static String normalizePhoneNumber(String phoneNumber) {
    // Ne garder que le '+' initial et les chiffres
    final cleaned = phoneNumber.trim();
    final hasPlus = cleaned.startsWith('+');
    
    // Supprimer tout caractère non numérique
    final digitsOnly = cleaned.replaceAll(RegExp(r'\D'), '');
    if (digitsOnly.isEmpty) return '';

    if (hasPlus) {
      return '+$digitsOnly';
    } else {
      // Par défaut pour l'Amérique du Nord s'il y a 10 chiffres (ex: 8191234567 -> +18191234567)
      if (digitsOnly.length == 10) {
        return '+1$digitsOnly';
      } else if (digitsOnly.length == 11 && digitsOnly.startsWith('1')) {
        return '+$digitsOnly';
      }
      return '+$digitsOnly';
    }
  }

  static String? _cachedSalt;

  /// Permet de définir dynamiquement le sel cryptographique (ex. depuis le Keystore).
  static void setCryptoSalt(String salt) {
    _cachedSalt = salt;
  }

  /// Résout le sel cryptographique selon la hiérarchie de sécurité :
  /// 1. Paramètre explicite fourni
  /// 2. Variable compilée (--dart-define=HASH_SALT=...)
  /// 3. Variable d'environnement .env (HASH_SALT ou CRYPTO_SALT)
  /// 4. Sel mis en cache mémoire (Keystore / injection)
  /// 5. Mode développement / tests unitaires uniquement (kDebugMode)
  static String resolveSalt([String? explicitSalt]) {
    if (explicitSalt != null && explicitSalt.isNotEmpty) {
      return explicitSalt;
    }
    const defineSalt = String.fromEnvironment('HASH_SALT');
    if (defineSalt.isNotEmpty) {
      return defineSalt;
    }
    try {
      if (dotenv.isInitialized) {
        final envSalt = dotenv.env['HASH_SALT'] ?? dotenv.env['CRYPTO_SALT'];
        if (envSalt != null && envSalt.isNotEmpty) {
          return envSalt;
        }
      }
    } catch (_) {}
    if (_cachedSalt != null && _cachedSalt!.isNotEmpty) {
      return _cachedSalt!;
    }
    if (kDebugMode) {
      return 'ShieldNet_Secure_Salt_2026_UQO';
    }
    throw StateError(
      'Sel cryptographique introuvable en production. '
      'Veuillez définir HASH_SALT via .env ou --dart-define=HASH_SALT=...',
    );
  }

  static String hashPhoneNumber(String phoneNumber, {String? salt}) {
    final normalized = normalizePhoneNumber(phoneNumber);
    final secretKey = resolveSalt(salt);
    return _doHash({'normalized': normalized, 'secretKey': secretKey});
  }

  /// Version asynchrone utilisant compute() (Isolates) pour ne pas figer l'UI lors de traitements en masse.
  static Future<String> hashPhoneNumberAsync(String phoneNumber, {String? salt}) async {
    final normalized = normalizePhoneNumber(phoneNumber);
    final secretKey = resolveSalt(salt);

    return compute(_doHash, {
      'normalized': normalized,
      'secretKey': secretKey,
    });
  }

  static String _doHash(Map<String, String> data) {
    final keyBytes = utf8.encode(data['secretKey']!);
    final inputBytes = utf8.encode(data['normalized']!);
    final hmac = Hmac(sha256, keyBytes);
    final digest = hmac.convert(inputBytes);
    return digest.toString();
  }

  /// Masque un numéro de téléphone pour affichage UI (ex: "+1 819 *** **67")
  static String maskPhoneNumber(String phoneNumber) {
    final cleaned = phoneNumber.trim();
    if (cleaned.length < 6) return '***';
    final start = cleaned.substring(0, 5);
    final end = cleaned.substring(cleaned.length - 2);
    return '$start *** **$end';
  }
}
