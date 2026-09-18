import 'package:flutter_test/flutter_test.dart';
import 'package:shieldnet/core/security/automated_spam_verifier.dart';

void main() {
  group('AutomatedSpamVerifier Tests', () {
    test('Un numéro local valide ne doit pas être bloqué', () {
      final result = AutomatedSpamVerifier.verifyNumber('819-123-4567');
      expect(result.isVerifiedSpam, false);
      expect(result.calculatedRiskScore, lessThan(40));
    });

    test('Un numéro à tarification spéciale (ex: 1-900) doit augmenter le score de risque', () {
      final result = AutomatedSpamVerifier.verifyNumber('1-900-555-1234');
      
      // On s'attend à ce que l'analyse détecte une anomalie liée aux numéros surtaxés
      expect(result.detectedAnomalies.any((a) => a.contains('surtaxé') || a.contains('900')), true);
      // Le score devrait être significativement plus élevé qu'un numéro normal
      expect(result.calculatedRiskScore, greaterThanOrEqualTo(50));
    });

    test('Un numéro trop court ou invalide doit être détecté', () {
      final result = AutomatedSpamVerifier.verifyNumber('12345');
      
      expect(result.detectedAnomalies.isNotEmpty, true);
      expect(result.isVerifiedSpam, false); // Invalide ne veut pas toujours dire spam, mais c'est suspect
    });
  });
}
