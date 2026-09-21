// Réexport des entités de résultat d'analyse de phishing
// depuis le détecteur core vers la couche domain de la feature sms_inspector.
//
// Ce fichier permet aux widgets et use cases de la feature sms_inspector
// de dépendre de la couche domain plutôt que directement du service core,
// respectant ainsi la règle de dépendance de la Clean Architecture.
export 'package:shieldnet/core/services/sms_phishing_detector.dart'
    show PhishingAnalysisResult, PhishingRiskLevel;
