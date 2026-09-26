import 'package:flutter_test/flutter_test.dart';
import 'package:shieldnet/core/services/sms_phishing_detector.dart';

void main() {
  group('SmsPhishingDetector Tests', () {
    test('Un message anodin sans lien ni menace doit être classé Sécuritaire', () {
      const message = 'Salut, on se retrouve ce soir à 19h pour dîner ?';
      final result = SmsPhishingDetector.analyze(message);

      expect(result.level, equals(PhishingRiskLevel.safe));
      expect(result.riskScore, lessThan(30));
      expect(result.extractedUrls, isEmpty);
      expect(result.detectedRedFlags, isEmpty);
    });

    test('Un SMS typique de fausse livraison avec raccourcisseur doit être classé Dangereux', () {
      const message = 'Chronopost: Votre colis 389201 n a pas pu etre livre. Frais de douane en attente sur bit.ly/colis-chronopost-urgent';
      final result = SmsPhishingDetector.analyze(message);

      expect(result.level, equals(PhishingRiskLevel.dangerous));
      expect(result.riskScore, greaterThanOrEqualTo(65));
      expect(result.extractedUrls, isNotEmpty);
      expect(result.detectedRedFlags.any((f) => f.contains('colis') || f.contains('chronopost')), isTrue);
      expect(result.detectedRedFlags.any((f) => f.contains('raccourcisseur')), isTrue);
    });

    test('Un SMS d usurpation bancaire avec adresse IP doit être détecté comme Dangereux', () {
      const message = 'Securite Banque: Votre compte a ete suspendu suite a une activite suspecte. Reconnectez-vous immediatement: http://192.168.1.100/login';
      final result = SmsPhishingDetector.analyze(message);

      expect(result.level, equals(PhishingRiskLevel.dangerous));
      expect(result.riskScore, greaterThanOrEqualTo(65));
      expect(result.detectedRedFlags.any((f) => f.contains('IP')), isTrue);
    });

    test('Un message contenant un lien avec extension suspecte (.xyz) doit augmenter le risque', () {
      const message = 'Offre exclusive rien que pour vous sur http://super-promo.xyz';
      final result = SmsPhishingDetector.analyze(message);

      expect(result.riskScore, greaterThanOrEqualTo(30));
      expect(result.extractedUrls, contains('http://super-promo.xyz'));
    });

    test('Un SMS de code 2FA/OTP légitime ne doit pas déclencher de faux positif', () {
      const message = 'Desjardins: Votre code de confirmation temporaire est 849201. Valide 5 minutes. Ne le transmettez a personne.';
      final result = SmsPhishingDetector.analyze(message);

      expect(result.level, equals(PhishingRiskLevel.safe));
      expect(result.riskScore, equals(0));
      expect(result.verdictTitle, contains('2FA/OTP'));
      expect(result.extractedUrls, isEmpty);
      expect(result.detectedRedFlags, isEmpty);
    });

    test('Un lien officiel gouvernemental québécois certifié doit être reconnu sans alerte abusive', () {
      const message = 'Avis Revenu Québec: votre avis de cotisation est disponible sur https://www.revenuquebec.ca/fr/espace-citoyens';
      final result = SmsPhishingDetector.analyze(message);

      expect(result.level, equals(PhishingRiskLevel.safe));
      expect(result.riskScore, lessThanOrEqualTo(25));
      expect(result.verdictTitle, equals('Message Officiel Vérifié'));
      expect(result.extractedUrls, contains('https://www.revenuquebec.ca/fr/espace-citoyens'));
      expect(result.detectedRedFlags.any((f) => f.contains('Usurpation d\'organisme')), isFalse);
    });

    test('Une tentative de typosquatting avec mutation de marque doit être classée Dangereuse', () {
      const message = 'Desjardins: Activite inhabituelle detectee. Mettez a jour vos acces sur https://desjard1ns-accesd.com/login';
      final result = SmsPhishingDetector.analyze(message);

      expect(result.level, equals(PhishingRiskLevel.dangerous));
      expect(result.riskScore, greaterThanOrEqualTo(65));
      expect(result.detectedRedFlags.any((f) => f.contains('Typosquatting') || f.contains('usurpant')), isTrue);
    });

    test('Un domaine composé frauduleux usurpant Hydro-Québec doit être détecté', () {
      const message = 'Hydro-Québec: Solde impaye de 145.20. Reglez maintenant sur https://hydroquebec-facturation.net';
      final result = SmsPhishingDetector.analyze(message);

      expect(result.level, equals(PhishingRiskLevel.dangerous));
      expect(result.riskScore, greaterThanOrEqualTo(65));
      expect(result.detectedRedFlags.any((f) => f.contains('usurpant la marque officielle')), isTrue);
    });
  });
}
