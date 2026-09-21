import '../../../../core/services/sms_phishing_detector.dart';

/// Use case encapsulant l'analyse de phishing d'un message SMS.
///
/// Respecte le principe Single Responsibility : une seule responsabilité,
/// une seule raison de changer. Les widgets de présentation appellent
/// ce use case au lieu d'invoquer directement le détecteur.
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
