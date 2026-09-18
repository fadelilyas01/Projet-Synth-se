import 'package:flutter_test/flutter_test.dart';
import 'package:shieldnet/core/security/crypto_utils.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() {
  group('CryptoUtils Tests', () {
    test('La normalisation E.164 doit formater correctement les numéros nord-américains', () {
      expect(CryptoUtils.normalizePhoneNumber('819-123-4567'), '+18191234567');
      expect(CryptoUtils.normalizePhoneNumber(' (819) 123 4567 '), '+18191234567');
      expect(CryptoUtils.normalizePhoneNumber('1-819-123-4567'), '+18191234567');
      expect(CryptoUtils.normalizePhoneNumber('+18191234567'), '+18191234567');
    });

    test('Le hachage HMAC-SHA256 doit être déterministe', () {
      dotenv.testLoad(fileInput: 'CRYPTO_SALT=test_salt');
      final hash1 = CryptoUtils.hashPhoneNumber('8191234567');
      final hash2 = CryptoUtils.hashPhoneNumber('+1 819 123 4567');
      
      // Les deux numéros pointent vers la même entité, le hash doit être identique
      expect(hash1, equals(hash2));
      
      // Vérifier que le hash fait 64 caractères (longueur standard SHA-256 en héxadécimal)
      expect(hash1.length, 64);
    });

    test('Le masquage du numéro doit cacher les chiffres du milieu', () {
      expect(CryptoUtils.maskPhoneNumber('+18191234567'), '+1819 *** **67');
      expect(CryptoUtils.maskPhoneNumber('123'), '***'); // Numéro trop court
    });
  });
}
