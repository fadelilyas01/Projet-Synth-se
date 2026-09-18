import 'crypto_utils.dart';
import 'phone_number_validator.dart';

/// Résultat d'évaluation heuristique automatique d'un numéro
class SpamVerificationResult {
  final String phoneNumber;
  final String phoneHash;
  final int calculatedRiskScore; // 0 à 100
  final bool isVerifiedSpam;
  final String primaryRiskFactor;
  final List<String> detectedAnomalies;

  SpamVerificationResult({
    required this.phoneNumber,
    required this.phoneHash,
    required this.calculatedRiskScore,
    required this.isVerifiedSpam,
    required this.primaryRiskFactor,
    required this.detectedAnomalies,
  });
}

/// Algorithme Automatique de Vérification Heuristique Anti-Spam
class AutomatedSpamVerifier {
  /// Évalue automatiquement tout numéro de téléphone et détermine son score de spam par défaut
  static SpamVerificationResult verifyNumber(String rawPhoneNumber) {
    final rawDigits = rawPhoneNumber.replaceAll(RegExp(r'\D'), '');
    final phoneHash = CryptoUtils.hashPhoneNumber(rawPhoneNumber);

    // Règle spéciale : Codes courts de service / 2FA (3 à 6 chiffres)
    if (rawDigits.length >= 3 && rawDigits.length <= 6) {
      return SpamVerificationResult(
        phoneNumber: rawPhoneNumber,
        phoneHash: phoneHash,
        calculatedRiskScore: 10,
        isVerifiedSpam: false,
        primaryRiskFactor: 'Numéro court / Code de service ou 2FA',
        detectedAnomalies: ['Format court (potentiel code d\'authentification 2FA)'],
      );
    }

    final normalized = CryptoUtils.normalizePhoneNumber(rawPhoneNumber);
    final List<String> anomalies = [];
    int score = 0;

    // -------------------------------------------------------------------
    // RÈGLE HEURISTIQUE 1: Origine géographique (Canada / USA vs Hors +1)
    // -------------------------------------------------------------------
    if (!normalized.startsWith('+1')) {
      score += 55;
      anomalies.add('Origine géographique hors Amérique du Nord (+1)');
    }

    // -------------------------------------------------------------------
    // RÈGLE HEURISTIQUE 2: Anomalies de structure & Usurpation (Spoofing)
    // -------------------------------------------------------------------
    if (PhoneNumberValidator.isGeneratedOrSpoofedNumber(rawPhoneNumber)) {
      score += 65;
      anomalies.add('Structure de numéro générée, répétitive ou mathématiquement invalide');
    }

    // -------------------------------------------------------------------
    // RÈGLE HEURISTIQUE 3: Plages surtaxées ou fictives connues
    // -------------------------------------------------------------------
    final digitsOnly = normalized.replaceAll(RegExp(r'\D'), '');
    if (digitsOnly.length == 11 && digitsOnly.startsWith('1')) {
      final areaCode = digitsOnly.substring(1, 4);
      if (areaCode == '900' || areaCode == '976') {
        score += 80;
        anomalies.add('Indicatif à tarif surtaxé connu (900/976)');
      }
    }

    // Plafonner le score entre 0 et 100
    final finalScore = score.clamp(0, 100);

    // Un numéro est vérifié comme SPAM si le score >= 40 ou s'il comporte des anomalies majeures
    final bool isSpam = finalScore >= 40 || anomalies.isNotEmpty;

    String primaryFactor = 'Numéro standard';
    if (anomalies.isNotEmpty) {
      primaryFactor = anomalies.first;
    }

    return SpamVerificationResult(
      phoneNumber: rawPhoneNumber,
      phoneHash: phoneHash,
      calculatedRiskScore: finalScore,
      isVerifiedSpam: isSpam,
      primaryRiskFactor: primaryFactor,
      detectedAnomalies: anomalies,
    );
  }
}
