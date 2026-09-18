import 'crypto_utils.dart';

/// Service de validation et de détection des numéros d'Amérique du Nord (Canada / É-U)
/// et des numéros générés/usurpés (Spoofed / Invalid).
class PhoneNumberValidator {
  /// Motif des indicatifs régionaux valides en Amérique du Nord (+1)
  /// En NANP, le numéro national se compose de 10 chiffres débutant par un indicatif régional [2-9]XX
  static final RegExp _nanpRegex = RegExp(r'^\+1[2-9]\d{9}$');

  /// Vérifie si un numéro provient du Canada ou des États-Unis (Code pays +1)
  static bool isNorthAmericanNumber(String rawPhoneNumber) {
    final normalized = CryptoUtils.normalizePhoneNumber(rawPhoneNumber);
    return _nanpRegex.hasMatch(normalized);
  }

  /// Détecte si un numéro est généré, fictif, usurpé (Spoofed) ou mathématiquement invalide.
  static bool isGeneratedOrSpoofedNumber(String rawPhoneNumber) {
    final normalized = CryptoUtils.normalizePhoneNumber(rawPhoneNumber);
    
    // Si le numéro n'a pas les 11 chiffres (+1 + 10 chiffres)
    final digitsOnly = normalized.replaceAll(RegExp(r'\D'), '');
    if (digitsOnly.length != 11 || !digitsOnly.startsWith('1')) {
      return true; // Mauvais format -> considéré comme suspect/généré
    }

    final nationalNumber = digitsOnly.substring(1); // 10 chiffres sans le +1

    // 1. Détection des chiffres répétitifs (ex: 1111111111, 8190000000, 5149999999)
    if (RegExp(r'(\d)\1{6,}').hasMatch(nationalNumber)) {
      return true;
    }

    // 2. Détection des séquences répétitives ou générées (ex: 1234567890, 0123456789)
    if (nationalNumber == '1234567890' || nationalNumber == '0123456789' || nationalNumber == '9876543210') {
      return true;
    }

    // 3. Détection des indicatifs réservés/invalides (ex: 555-0100 à 555-0199 réservés pour la fiction)
    if (nationalNumber.substring(3, 6) == '555') {
      return true;
    }

    // 4. Détection des numéros surtaxés connus (ex: 900, 976)
    final areaCode = nationalNumber.substring(0, 3);
    if (areaCode == '900' || areaCode == '976') {
      return true;
    }

    return false;
  }

  /// Détermine si un numéro doit être BLOQUÉ PAR DÉFAUT
  /// (Si hors Canada/USA OU s'il est généré/usurpé)
  static bool shouldBlockByDefault(String rawPhoneNumber) {
    final normalized = CryptoUtils.normalizePhoneNumber(rawPhoneNumber);

    // Règle 1: Bloquer tout numéro qui ne provient PAS du Canada/États-Unis (+1)
    if (!normalized.startsWith('+1')) {
      return true;
    }

    // Règle 2: Bloquer tout numéro généré ou usurpé
    if (isGeneratedOrSpoofedNumber(rawPhoneNumber)) {
      return true;
    }

    return false;
  }
}
