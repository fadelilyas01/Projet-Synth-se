import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shieldnet/core/database/database_helper.dart';
import 'package:shieldnet/core/network/api_service.dart';
import 'package:shieldnet/core/services/offline_sync_service.dart';
import 'package:shieldnet/features/call_filtering/data/repositories/blacklist_repository_impl.dart';

class MockDatabaseHelper extends Mock implements DatabaseHelper {}
class MockApiService extends Mock implements ApiService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockDatabaseHelper mockDb;
  late MockApiService mockApi;
  late OfflineSyncService offlineSyncService;

  setUpAll(() {
    registerFallbackValue(PendingSpamReport(
      phoneHash: 'fallback_hash',
      rawNumber: '5550000',
      maskedNumber: '555****',
      category: 'fraud',
      createdAt: '',
    ));
    registerFallbackValue(BlacklistedNumber(
      phoneHash: 'fallback_hash',
      category: 'fraud',
      riskScore: 70,
      reportsCount: 1,
      updatedAt: '',
    ));
  });

  setUp(() {
    mockDb = MockDatabaseHelper();
    mockApi = MockApiService();
    offlineSyncService = OfflineSyncService(db: mockDb, api: mockApi);
  });

  group('OfflineSyncService — Tests de synchronisation résiliente', () {
    test('getPendingCount retourne le total des éléments en attente dans SQLite', () async {
      when(() => mockDb.getPendingTotalCount()).thenAnswer((_) async => 5);

      final count = await offlineSyncService.getPendingCount();

      expect(count, equals(5));
      verify(() => mockDb.getPendingTotalCount()).called(1);
    });

    test('flushQueue rejoue avec succès les signalements et supprime les éléments traités', () async {
      final reports = [
        PendingSpamReport(
          id: 1,
          phoneHash: 'hash_1',
          rawNumber: '+18195551234',
          maskedNumber: '+1 819 555-****',
          category: 'fraud',
          comment: 'Appel fraude',
          createdAt: '2026-09-26T00:00:00Z',
        ),
      ];

      when(() => mockDb.getPendingReports()).thenAnswer((_) async => reports);
      when(() => mockDb.getPendingSafeDisputes()).thenAnswer((_) async => []);
      when(() => mockApi.submitSpamReport(
            rawPhoneNumber: '+18195551234',
            category: 'fraud',
            comment: 'Appel fraude',
          )).thenAnswer((_) async => true);
      when(() => mockDb.deletePendingReport(1)).thenAnswer((_) async => 1);
      when(() => mockDb.checkpointWAL()).thenAnswer((_) async {});

      final result = await offlineSyncService.flushQueue();

      expect(result.syncedReports, equals(1));
      expect(result.syncedDisputes, equals(0));
      expect(result.failedItems, equals(0));
      expect(result.hasWorkDone, isTrue);

      verify(() => mockDb.deletePendingReport(1)).called(1);
      verify(() => mockDb.checkpointWAL()).called(1);
    });

    test('flushQueue rejoue avec succès les contestations légitimes et nettoie la base', () async {
      final disputes = [
        PendingSafeDispute(
          id: 10,
          phoneHash: 'hash_clinic',
          rawNumber: '+18195559999',
          maskedNumber: '+1 819 555-****',
          reason: 'medical',
          comment: 'Clinique médicale UQO',
          createdAt: '2026-09-26T00:00:00Z',
        ),
      ];

      when(() => mockDb.getPendingReports()).thenAnswer((_) async => []);
      when(() => mockDb.getPendingSafeDisputes()).thenAnswer((_) async => disputes);
      when(() => mockApi.submitSafeReport(
            rawPhoneNumber: '+18195559999',
            phoneHash: 'hash_clinic',
            maskedNumber: '+1 819 555-****',
            reason: 'medical',
            comment: 'Clinique médicale UQO',
          )).thenAnswer((_) async => {'status': 'processed'});
      when(() => mockDb.deletePendingSafeDispute(10)).thenAnswer((_) async => 1);
      when(() => mockDb.checkpointWAL()).thenAnswer((_) async {});

      final result = await offlineSyncService.flushQueue();

      expect(result.syncedReports, equals(0));
      expect(result.syncedDisputes, equals(1));
      expect(result.failedItems, equals(0));
      expect(result.totalSynced, equals(1));

      verify(() => mockDb.deletePendingSafeDispute(10)).called(1);
    });

    test('flushQueue incrémente retryCount si l API échoue', () async {
      final reports = [
        PendingSpamReport(
          id: 42,
          phoneHash: 'hash_fail',
          rawNumber: '+18195550000',
          maskedNumber: '+1 819 555-****',
          category: 'financial_scam',
          createdAt: '2026-09-26T00:00:00Z',
        ),
      ];

      when(() => mockDb.getPendingReports()).thenAnswer((_) async => reports);
      when(() => mockDb.getPendingSafeDisputes()).thenAnswer((_) async => []);
      when(() => mockApi.submitSpamReport(
            rawPhoneNumber: any(named: 'rawPhoneNumber'),
            category: any(named: 'category'),
            comment: any(named: 'comment'),
          )).thenAnswer((_) async => false);
      when(() => mockDb.incrementPendingReportRetry(42)).thenAnswer((_) async {});
      when(() => mockDb.checkpointWAL()).thenAnswer((_) async {});

      final result = await offlineSyncService.flushQueue();

      expect(result.syncedReports, equals(0));
      expect(result.failedItems, equals(1));
      verify(() => mockDb.incrementPendingReportRetry(42)).called(1);
      verifyNever(() => mockDb.deletePendingReport(any()));
    });
  });

  group('BlacklistRepositoryImpl — Sauvegarde résiliente hors-ligne', () {
    test('submitSpamReport bascule automatiquement en file hors-ligne en cas d erreur réseau', () async {
      final repo = BlacklistRepositoryImpl(localDatabase: mockDb, remoteApi: mockApi);

      // Simuler une coupure réseau complète
      when(() => mockApi.submitSpamReport(
            rawPhoneNumber: any(named: 'rawPhoneNumber'),
            category: any(named: 'category'),
            comment: any(named: 'comment'),
          )).thenThrow(Exception('No internet connection'));

      when(() => mockDb.insertPendingReport(any())).thenAnswer((_) async => 1);
      when(() => mockDb.insertOrUpdateBlacklistedNumber(any())).thenAnswer((_) async {});
      when(() => mockDb.checkpointWAL()).thenAnswer((_) async {});

      final result = await repo.submitSpamReport(
        rawPhoneNumber: '8195551234',
        category: 'fraud',
        comment: 'Fausse agence du revenu',
      );

      // Le repository doit retourner un succès pour l utilisateur
      expect(result.isRight(), isTrue);
      // Et le numéro doit être mis en file et bloqué localement
      verify(() => mockDb.insertPendingReport(any())).called(1);
      verify(() => mockDb.insertOrUpdateBlacklistedNumber(any())).called(1);
      verify(() => mockDb.checkpointWAL()).called(1);
    });
  });
}
