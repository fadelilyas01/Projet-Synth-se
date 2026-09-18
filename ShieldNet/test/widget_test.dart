import 'package:flutter_test/flutter_test.dart';
import 'package:shieldnet/core/security/crypto_utils.dart';
import 'package:shieldnet/core/security/phone_number_validator.dart';
import 'package:shieldnet/core/security/automated_spam_verifier.dart';

void main() {
  group('Tests Unitaires de Sécurité & Validation ShieldNet', () {
    test('Anonymisation SHA-256 avec sel', () {
      final hash1 = CryptoUtils.hashPhoneNumber('+18191234567');
      final hash2 = CryptoUtils.hashPhoneNumber('+1 (819) 123-4567');

      expect(hash1, equals(hash2));
      expect(hash1.length, equals(64));
    });

    test('Validation des numéros Amérique du Nord (+1 NANP)', () {
      expect(PhoneNumberValidator.isNorthAmericanNumber('+18191234567'), isTrue);
      expect(PhoneNumberValidator.isNorthAmericanNumber('+33612345678'), isFalse);
    });

    test('Détection des numéros générés ou usurpés', () {
      expect(PhoneNumberValidator.isGeneratedOrSpoofedNumber('+11111111111'), isTrue);
      expect(PhoneNumberValidator.isGeneratedOrSpoofedNumber('+18191234567'), isFalse);
    });

    test('Évaluation algorithmique automatique', () {
      final result = AutomatedSpamVerifier.verifyNumber('+33612345678');
      expect(result.isVerifiedSpam, isTrue);
      expect(result.calculatedRiskScore, greaterThanOrEqualTo(40));
    });
  });
}
