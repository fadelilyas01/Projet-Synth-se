import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Utilitaire cryptographique pour la conformité RGPD et la confidentialité.
class CryptoUtils {
  /// Normalise un numéro de téléphone au format E.164 (ex. +18191234567)
  /// pour garantir que deux saisies différentes du même numéro produisent le même Hash.
  static String normalizePhoneNumber(String phoneNumber) {
    // Ne garder que le '+' initial et les chiffres
    final cleaned = phoneNumber.trim();
    final hasPlus = cleaned.startsWith('+');
    
    // Supprimer tout caractère non numérique
    final digitsOnly = cleaned.replaceAll(RegExp(r'\D'), '');

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

  static String hashPhoneNumber(String phoneNumber, {String? salt}) {
    final normalized = normalizePhoneNumber(phoneNumber);
    String? envSalt;
    try {
      if (dotenv.isInitialized) {
        envSalt = dotenv.env['HASH_SALT'] ?? dotenv.env['CRYPTO_SALT'];
      }
    } catch (_) {}
    final secretKey = salt ?? envSalt ?? 'ShieldNet_Secure_Salt_2026_UQO';
    return _doHash({'normalized': normalized, 'secretKey': secretKey});
  }

  /// Version asynchrone utilisant compute() (Isolates) pour ne pas figer l'UI lors de traitements en masse.
  static Future<String> hashPhoneNumberAsync(String phoneNumber, {String? salt}) async {
    final normalized = normalizePhoneNumber(phoneNumber);
    String? envSalt;
    try {
      if (dotenv.isInitialized) {
        envSalt = dotenv.env['HASH_SALT'] ?? dotenv.env['CRYPTO_SALT'];
      }
    } catch (_) {}
    final secretKey = salt ?? envSalt ?? 'ShieldNet_Secure_Salt_2026_UQO';
    
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
