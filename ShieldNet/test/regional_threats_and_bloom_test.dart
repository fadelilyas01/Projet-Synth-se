import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dio/dio.dart';
import 'package:shieldnet/core/models/regional_threat.dart';
import 'package:shieldnet/core/security/bloom_filter_client.dart';
import 'package:shieldnet/core/security/device_integrity_checker.dart';
import 'package:shieldnet/core/network/api_service.dart';
import 'package:shieldnet/features/call_filtering/presentation/widgets/regional_threat_card.dart';
import 'package:shieldnet/features/call_filtering/presentation/widgets/device_integrity_banner.dart';

class MockDio extends Mock implements Dio {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RegionalThreat Models & Parsing', () {
    test('Parse payload JSON correctement et sélectionne le niveau le plus critique', () {
      final json = {
        'generated_at': '2026-09-26T08:00:00Z',
        'total_regions_tracked': 2,
        'regions': [
          {
            'area_code': '514',
            'region_name': 'Montréal',
            'total_spams': 10,
            'top_category': 'telemarketing',
            'max_risk_score': 50,
            'alert_level': 'MODÉRÉ',
          },
          {
            'area_code': '819',
            'region_name': 'Outaouais',
            'total_spams': 45,
            'top_category': 'fraud',
            'max_risk_score': 95,
            'alert_level': 'CRITIQUE',
          },
        ],
      };

      final summary = RegionalThreatSummary.fromJson(json);
      expect(summary.totalRegionsTracked, 2);
      expect(summary.regions.length, 2);
      expect(summary.highestAlert?.areaCode, '819');
      expect(summary.highestAlert?.isCritical, isTrue);
      expect(summary.highestAlert?.isHigh, isFalse);
    });

    test('Retourne null si la liste des régions est vide', () {
      final summary = RegionalThreatSummary.fromJson({
        'total_regions_tracked': 0,
        'regions': [],
      });
      expect(summary.highestAlert, isNull);
    });
  });

  group('RegionalThreatCard Widget', () {
    testWidgets('Affiche le badge d\'alerte et ouvre le dialogue de détails au tap', (tester) async {
      final summary = RegionalThreatSummary.fromJson({
        'total_regions_tracked': 1,
        'regions': [
          {
            'area_code': '819',
            'region_name': 'Outaouais / Gatineau',
            'total_spams': 42,
            'top_category': 'fraud',
            'max_risk_score': 95,
            'alert_level': 'CRITIQUE',
          }
        ],
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RegionalThreatCard(summary: summary),
          ),
        ),
      );

      expect(find.text('Alerte Indicatif (819)'), findsOneWidget);
      expect(find.text('CRITIQUE'), findsOneWidget);
      expect(find.textContaining('Outaouais / Gatineau'), findsOneWidget);

      // Tap pour ouvrir le modal
      await tester.tap(find.byType(RegionalThreatCard));
      await tester.pumpAndSettle();

      expect(find.text('Radar Régional des Arnaques'), findsOneWidget);
      expect(find.text('Compris'), findsOneWidget);

      // Fermeture du modal
      await tester.tap(find.text('Compris'));
      await tester.pumpAndSettle();

      expect(find.text('Radar Régional des Arnaques'), findsNothing);
    });
  });

  group('DeviceIntegrityBanner Widget', () {
    testWidgets('Ne s\'affiche pas si l\'appareil est sain (non compromis)', (tester) async {
      const safeResult = DeviceIntegrityResult(
        isSafe: true,
        isRootDetected: false,
        detectedAnomalies: [],
        securitySummary: 'Système intègre',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DeviceIntegrityBanner(result: safeResult),
          ),
        ),
      );

      expect(find.byType(Container), findsNothing);
      expect(find.textContaining('Root'), findsNothing);
    });

    testWidgets('Affiche une alerte rouge si l\'appareil est compromis (Root)', (tester) async {
      const compromisedResult = DeviceIntegrityResult(
        isSafe: false,
        isRootDetected: true,
        detectedAnomalies: ['Binaire su détecté'],
        securitySummary: 'Root actif',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DeviceIntegrityBanner(result: compromisedResult),
          ),
        ),
      );

      expect(find.text('Sécurité Système : Appareil Rooté'), findsOneWidget);
      expect(find.textContaining('accès super-utilisateur'), findsOneWidget);
    });
  });

  group('BloomFilterClient In-Memory Verification', () {
    test('Évaluation probabiliste et respect de la propriété zéro faux-négatif', () {
      final bytes = Uint8List(1024); // 8192 bits
      const testHash = 'a1b2c3d4e5f60718293a4b5c6d7e8f90';

      // Calcul des index et positionnement des bits
      final h1 = BigInt.parse(testHash.substring(0, 16), radix: 16);
      final h2 = BigInt.parse(testHash.substring(16, 32), radix: 16) | BigInt.one;
      const sizeBits = 8192;
      const hashCount = 4;
      final bigSize = BigInt.from(sizeBits);

      for (int i = 0; i < hashCount; i++) {
        final bitIndex = ((h1 + BigInt.from(i) * h2) % bigSize).toInt();
        bytes[bitIndex ~/ 8] |= (1 << (bitIndex % 8));
      }

      final filter = BloomFilterClient(
        sizeBits: sizeBits,
        hashCount: hashCount,
        bitArray: bytes,
        entriesCount: 1,
      );

      // Le hash inséré doit retourner true
      expect(filter.contains(testHash), isTrue);

      // Un hash aléatoire non inséré a une probabilité quasi-certaine de retourner false
      const unknownHash = 'ffffffffffffffffffffffffffffffff';
      expect(filter.contains(unknownHash), isFalse);
    });
  });

  group('ApiService — Menaces Régionales & Filtre de Bloom', () {
    late MockDio mockDio;
    late ApiService apiService;

    setUp(() {
      mockDio = MockDio();
      apiService = ApiService(dio: mockDio);
    });

    test('getRegionalThreats retourne le modèle parsé en cas de succès 200', () async {
      when(() => mockDio.get('threats/regional/')).thenAnswer(
        (_) async => Response(
          data: {
            'generated_at': '2026-09-26T08:00:00Z',
            'total_regions_tracked': 1,
            'regions': [
              {
                'area_code': '819',
                'region_name': 'Outaouais',
                'total_spams': 30,
                'top_category': 'fraud',
                'max_risk_score': 90,
                'alert_level': 'CRITIQUE',
              }
            ],
          },
          statusCode: 200,
          requestOptions: RequestOptions(path: 'threats/regional/'),
        ),
      );

      final result = await apiService.getRegionalThreats();
      expect(result, isNotNull);
      expect(result!.regions.length, 1);
      expect(result.highestAlert?.areaCode, '819');
    });

    test('downloadBloomFilter configure BloomFilterClient.activeFilter en cas de succès', () async {
      final dummyBytes = Uint8List(64);
      final b64 = base64Encode(dummyBytes);

      when(() => mockDio.get('sync/bloom/', queryParameters: any(named: 'queryParameters'))).thenAnswer(
        (_) async => Response(
          data: {
            'format': 'bloom_filter_v1',
            'size_bits': 512,
            'hash_count': 4,
            'entries_count': 5,
            'bit_array_base64': b64,
          },
          statusCode: 200,
          requestOptions: RequestOptions(path: 'sync/bloom/'),
        ),
      );

      final filter = await apiService.downloadBloomFilter(sizeBits: 512);
      expect(filter, isNotNull);
      expect(filter!.entriesCount, 5);
      expect(BloomFilterClient.activeFilter, equals(filter));
    });
  });
}
