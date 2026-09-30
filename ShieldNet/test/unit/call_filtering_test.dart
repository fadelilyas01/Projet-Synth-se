import 'package:flutter_test/flutter_test.dart';
import 'package:shieldnet/core/security/phone_number_validator.dart';
import 'package:shieldnet/core/security/automated_spam_verifier.dart';
import 'package:shieldnet/core/services/regional_compliance_service.dart';

void main() {
  group('Call Filtering & Protection Tests', () {
    test('Validation des numéros Amérique du Nord (+1 NANP)', () {
      expect(PhoneNumberValidator.isNorthAmericanNumber('+18191234567'), isTrue);
      expect(PhoneNumberValidator.isNorthAmericanNumber('+33612345678'), isFalse);
    });

    test('Détection des numéros générés ou usurpés (Spoofing)', () {
      expect(PhoneNumberValidator.isGeneratedOrSpoofedNumber('+11111111111'), isTrue);
      expect(PhoneNumberValidator.isGeneratedOrSpoofedNumber('+18191234567'), isFalse);
    });

    test('Évaluation algorithmique du spam entrant', () {
      final internationalSpam = AutomatedSpamVerifier.verifyNumber('+33612345678');
      expect(internationalSpam.isVerifiedSpam, isTrue);
      expect(internationalSpam.calculatedRiskScore, greaterThanOrEqualTo(40));

      final legitimateNumber = AutomatedSpamVerifier.verifyNumber('+18191234567');
      expect(legitimateNumber.isVerifiedSpam, isFalse);
    });

    test('Garantie absolue d\'immunité des numéros d\'urgence (911, 811, 988)', () {
      // Québec
      final qcNorm = RegionalComplianceManager.getLocalNorm('CA', 'QC');
      final qcEmergencies = qcNorm['emergency_numbers'] as List;
      expect(qcEmergencies.any((e) => e['number'] == '911' && e['immune'] == true), isTrue);
      expect(qcEmergencies.any((e) => e['number'] == '811' && e['immune'] == true), isTrue);
      expect(qcEmergencies.any((e) => e['number'] == '988' && e['immune'] == true), isTrue);

      // Canada général
      final caNorm = RegionalComplianceManager.getLocalNorm('CA', 'ON');
      final caEmergencies = caNorm['emergency_numbers'] as List;
      expect(caEmergencies.any((e) => e['number'] == '911' && e['immune'] == true), isTrue);

      // USA
      final usNorm = RegionalComplianceManager.getLocalNorm('US', 'NY');
      final usEmergencies = usNorm['emergency_numbers'] as List;
      expect(usEmergencies.any((e) => e['number'] == '911' && e['immune'] == true), isTrue);
    });

    test('Respect des règles de rétention régionales (Loi 25 vs LPRPDE vs TCPA)', () {
      final qcNorm = RegionalComplianceManager.getLocalNorm('CA', 'QC');
      expect(qcNorm['data_retention_days'], equals(30));

      final caNorm = RegionalComplianceManager.getLocalNorm('CA', 'ON');
      expect(caNorm['data_retention_days'], equals(60));

      final usNorm = RegionalComplianceManager.getLocalNorm('US', 'CA');
      expect(usNorm['data_retention_days'], equals(45));
    });
  });
}
