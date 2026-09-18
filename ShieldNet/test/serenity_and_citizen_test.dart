import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shieldnet/core/services/citizen_impact_service.dart';
import 'package:shieldnet/features/call_filtering/domain/services/serenity_score_calculator.dart';
import 'package:shieldnet/features/community/presentation/widgets/citizen_impact_card.dart';
import 'package:shieldnet/features/call_filtering/presentation/widgets/serenity_score_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SerenityScoreCalculator Tests', () {
    test('Toutes les options activées donnent 100% et Sérénité Maximale', () {
      final res = SerenityScoreCalculator.compute(
        isCallScreeningActive: true,
        isAutoBlockEnabled: true,
        isBiometricEnabled: true,
        isContactsOnlyEnabled: true,
        isCacheFresh: true,
      );

      expect(res.score, equals(100));
      expect(res.statusTitle, equals('Sérénité Maximale'));
      expect(res.recommendations, isEmpty);
    });

    test('Protection minimale donne un statut Vulnérable avec des recommandations', () {
      final res = SerenityScoreCalculator.compute(
        isCallScreeningActive: false,
        isAutoBlockEnabled: false,
        isBiometricEnabled: false,
        isContactsOnlyEnabled: false,
        isCacheFresh: false,
      );

      expect(res.score, equals(0));
      expect(res.statusTitle, equals('Appareil Vulnérable'));
      expect(res.recommendations.length, equals(5));
    });
  });

  group('CitizenImpactService Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('L impact citoyen démarre à 0 et progresse avec les signalements', () async {
      var data = await CitizenImpactService.getImpactData();
      expect(data.reportsCount, equals(0));
      expect(data.protectedCitizensEstimate, equals(0));
      expect(data.currentRank.isUnlocked, isFalse);

      await CitizenImpactService.incrementReportsCount();
      data = await CitizenImpactService.getImpactData(localBlockedSpams: 2);

      expect(data.reportsCount, equals(1));
      expect(data.protectedCitizensEstimate, equals(45 + 4));
      expect(data.allBadges.first.isUnlocked, isTrue); // Vigie Citoyenne débloquée
    });

    testWidgets('CitizenImpactCard et SerenityScoreCard s affichent sans overflow sur petit écran (320px)', (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final impactData = await CitizenImpactService.getImpactData(localBlockedSpams: 5);
      final serenityResult = SerenityScoreCalculator.compute(
        isCallScreeningActive: false,
        isAutoBlockEnabled: false,
        isBiometricEnabled: false,
        isContactsOnlyEnabled: false,
        isCacheFresh: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              children: [
                SerenityScoreCard(result: serenityResult),
                CitizenImpactCard(data: impactData),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(CitizenImpactCard), findsOneWidget);
      expect(find.byType(SerenityScoreCard), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
