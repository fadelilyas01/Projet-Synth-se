import '../../../../core/services/sms_phishing_detector.dart';

// Détection heuristique de phishing SMS
// L'analyse s'exécute entièrement en local sans transmission réseau
class AnalyzeSmsUseCase {
  /// Analyse le contenu d'un SMS et retourne le résultat de détection de phishing.
  ///
  /// [smsContent] : Le texte brut du message SMS à analyser.
  /// Retourne un [PhishingAnalysisResult] contenant le score de risque,
  /// les URLs extraites, les drapeaux rouges détectés et les recommandations.
  PhishingAnalysisResult call(String smsContent) {
    return SmsPhishingDetector.analyze(smsContent);
  }
}
