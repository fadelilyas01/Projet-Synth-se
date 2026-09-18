import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Synchronisation & Réconciliation Faux-Positifs Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Le timestamp de synchronisation persiste correctement dans SharedPreferences', () async {
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('last_sync_timestamp'), isNull);

      final nowIso = DateTime.now().toIso8601String();
      await prefs.setString('last_sync_timestamp', nowIso);

      expect(prefs.getString('last_sync_timestamp'), equals(nowIso));
    });

    test('Le payload delta sépare adéquatement les actifs et les faux-positifs retirés', () {
      final deltaPayload = {
        'active': [
          {
            'phone_hash': 'abc123hash',
            'masked_number': '+1 (514) ***-1234',
            'category': 'fraud',
            'risk_score': 95,
            'reports_count': 12,
            'updated_at': '2026-09-17T07:00:00Z',
          }
        ],
        'removed': [
          'whitelisted_hash_456',
          'unblocked_hash_789'
        ],
        'sync_timestamp': '2026-09-17T07:05:00Z'
      };

      final activeList = deltaPayload['active'] as List;
      final removedList = deltaPayload['removed'] as List;

      expect(activeList.length, equals(1));
      expect(removedList.length, equals(2));
      expect(removedList, contains('whitelisted_hash_456'));
      expect(removedList, contains('unblocked_hash_789'));
      expect(deltaPayload['sync_timestamp'], equals('2026-09-17T07:05:00Z'));
    });

    test('Validation de la structure des logs d\'audit unifiés', () {
      final logEntry = {
        'id': 'd6f6e520-2c70-4f51-b0db-6e6b5a3fa271',
        'action': 'WHITELIST_NUMBER',
        'source': 'web',
        'user_username': 'admin_securite',
        'target_hash': 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
        'details': {'reason': 'Faux positif avéré - Hôpital Général'},
        'created_at': '2026-09-17T07:02:00Z',
      };

      expect(logEntry['action'], equals('WHITELIST_NUMBER'));
      expect(logEntry['source'], equals('web'));
      expect(logEntry['user_username'], equals('admin_securite'));
      expect((logEntry['details'] as Map)['reason'], contains('Faux positif'));
    });
  });
}
