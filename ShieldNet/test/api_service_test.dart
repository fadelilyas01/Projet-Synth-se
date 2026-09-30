
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shieldnet/core/network/api_service.dart';

// ==================== MOCKS ====================
class MockDio extends Mock implements Dio {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockDio mockDio;
  late ApiService apiService;

  setUp(() {
    mockDio = MockDio();
    apiService = ApiService(dio: mockDio);
    SharedPreferences.setMockInitialValues({});
  });

  group('ApiService — Synchronisation Delta (syncBlacklistWithBackend)', () {
    test('Sync delta avec payload Map (active + removed) retourne le total synchronisé', () async {
      when(() => mockDio.get('blacklist/', queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => Response(
                data: {
                  'active': [
                    {
                      'phone_hash': 'hash_abc123',
                      'masked_number': '+1 514 ***-1234',
                      'category': 'fraud',
                      'risk_score': 95,
                      'reports_count': 12,
                      'updated_at': '2026-09-17T07:00:00Z',
                    },
                    {
                      'phone_hash': 'hash_def456',
                      'masked_number': '+1 819 ***-5678',
                      'category': 'robocall',
                      'risk_score': 80,
                      'reports_count': 5,
                      'updated_at': '2026-09-17T07:00:00Z',
                    },
                  ],
                  'removed': ['purged_hash_001', 'purged_hash_002', 'purged_hash_003'],
                  'sync_timestamp': '2026-09-17T08:00:00Z',
                },
                statusCode: 200,
                requestOptions: RequestOptions(path: 'blacklist/'),
              ));

      final count = await apiService.syncBlacklistWithBackend(delta: true);

      // 2 active + 3 removed = 5
      expect(count, 5);

      // Vérifie que le timestamp est persisté
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('last_sync_timestamp'), '2026-09-17T08:00:00Z');
    });

    test('Sync complète avec payload List retourne le nombre d\'éléments', () async {
      when(() => mockDio.get('blacklist/', queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => Response(
                data: [
                  {
                    'phone_hash': 'hash_full_001',
                    'masked_number': '+1 613 ***-0001',
                    'category': 'telemarketing',
                    'risk_score': 60,
                    'reports_count': 3,
                    'updated_at': '2026-09-17T06:00:00Z',
                  },
                ],
                statusCode: 200,
                requestOptions: RequestOptions(path: 'blacklist/'),
              ));

      final count = await apiService.syncBlacklistWithBackend(delta: false);
      expect(count, 1);
    });

    test('Sync échouée (erreur réseau) retourne 0 sans lancer d\'exception', () async {
      when(() => mockDio.get('blacklist/', queryParameters: any(named: 'queryParameters')))
          .thenThrow(DioException(
        type: DioExceptionType.connectionError,
        requestOptions: RequestOptions(path: 'blacklist/'),
      ));

      final count = await apiService.syncBlacklistWithBackend();

      expect(count, 0);
    });
  });

  group('ApiService — Signalement (submitSpamReport)', () {
    test('Signalement réussi retourne true', () async {
      when(() => mockDio.post('reports/', data: any(named: 'data')))
          .thenAnswer((_) async => Response(
                data: {'id': 'report_001', 'risk_score': 75, 'reports_count': 4},
                statusCode: 201,
                requestOptions: RequestOptions(path: 'reports/'),
              ));

      final result = await apiService.submitSpamReport(
        rawPhoneNumber: '+18195551234',
        category: 'fraud',
        comment: 'Appel frauduleux',
      );

      expect(result, true);
    });

    test('Signalement échoué retourne false', () async {
      when(() => mockDio.post('reports/', data: any(named: 'data')))
          .thenThrow(DioException(
        type: DioExceptionType.badResponse,
        requestOptions: RequestOptions(path: 'reports/'),
        response: Response(
          data: {'detail': 'Erreur interne'},
          statusCode: 500,
          requestOptions: RequestOptions(path: 'reports/'),
        ),
      ));

      final result = await apiService.submitSpamReport(
        rawPhoneNumber: '+18195559999',
        category: 'phishing',
      );

      expect(result, false);
    });
  });

  group('ApiService — Vérification de Numéro (checkNumberOnBackend)', () {
    test('Vérification réussie retourne les données du serveur', () async {
      when(() => mockDio.get(any()))
          .thenAnswer((_) async => Response(
                data: {
                  'phone_hash': 'hash_check',
                  'is_spam': true,
                  'is_whitelisted': false,
                  'risk_score': 85,
                  'reports_count': 7,
                  'category': 'fraud',
                },
                statusCode: 200,
                requestOptions: RequestOptions(path: 'check/hash_check/'),
              ));

      final result = await apiService.checkNumberOnBackend('+18195550000');

      expect(result, isNotNull);
      expect(result!['is_spam'], true);
      expect(result['risk_score'], 85);
    });

    test('Vérification hors-ligne retourne null', () async {
      when(() => mockDio.get(any()))
          .thenThrow(DioException(
        type: DioExceptionType.connectionTimeout,
        requestOptions: RequestOptions(path: 'check/hash/'),
      ));

      final result = await apiService.checkNumberOnBackend('+18195550000');
      expect(result, isNull);
    });
  });
}
