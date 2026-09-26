import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shieldnet/core/providers/app_providers.dart';
import 'package:shieldnet/l10n/app_localizations.dart';
import 'package:shieldnet/features/call_filtering/presentation/pages/dashboard_page.dart';
import 'package:shieldnet/features/call_filtering/presentation/controllers/blacklist_controller.dart';
import 'package:shieldnet/features/call_filtering/domain/entities/blacklisted_entry.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    dotenv.testLoad(fileInput: '''
API_BASE_URL=http://127.0.0.1:8000/api/v1/
API_KEY=test_key
HASH_SALT=test_salt
''');
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget buildTestApp({required ProviderContainer container}) {
    return UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: [
          Locale('fr', ''),
          Locale('en', ''),
        ],
        locale: Locale('fr', ''),
        home: DashboardPage(),
      ),
    );
  }

  group('Mode Interface Simplifiée (Seniors / Aînés) — Tests Unitaires & Widgets', () {
    test('SeniorModeNotifier bascule et persiste dans SharedPreferences', () async {
      final notifier = SeniorModeNotifier();
      expect(notifier.state, isFalse);

      await notifier.toggle(true);
      expect(notifier.state, isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('settings_senior_mode'), isTrue);

      await notifier.toggle(false);
      expect(notifier.state, isFalse);
      expect(prefs.getBool('settings_senior_mode'), isFalse);
    });

    test('AppSettingsNotifier.setSeniorMode met à jour à la fois AppSettingsState et seniorModeProvider', () async {
      final container = ProviderContainer();
      final notifier = container.read(appSettingsProvider.notifier);

      expect(container.read(seniorModeProvider), isFalse);

      await notifier.setSeniorMode(true);
      expect(container.read(appSettingsProvider).seniorMode, isTrue);
      expect(container.read(seniorModeProvider), isTrue);

      await notifier.setSeniorMode(false);
      expect(container.read(appSettingsProvider).seniorMode, isFalse);
      expect(container.read(seniorModeProvider), isFalse);
    });

    testWidgets('DashboardPage affiche le bandeau Mode Simplifié quand activé', (tester) async {
      SharedPreferences.setMockInitialValues({'settings_senior_mode': true});
      await tester.binding.setSurfaceSize(const Size(400, 900));

      final container = ProviderContainer(
        overrides: [
          protectionStatusProvider.overrideWith((ref) => ProtectionNotifier(ref.watch(callScreeningServiceProvider))..state = const AsyncValue.data(true)),
          blacklistControllerProvider.overrideWith((ref) => BlacklistNotifier(
                getBlacklistUseCase: ref.watch(getBlacklistUseCaseProvider),
                syncBlacklistUseCase: ref.watch(syncBlacklistUseCaseProvider),
                repository: ref.watch(blacklistRepositoryProvider),
              )..state = const AsyncValue.data(<BlacklistedEntry>[])),
        ],
      );

      await tester.pumpWidget(buildTestApp(container: container));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Mode Simplifié Actif'), findsOneWidget);
      expect(find.byIcon(Icons.elderly_rounded), findsOneWidget);
    });

    testWidgets('DashboardPage masque le bandeau Mode Simplifié quand désactivé', (tester) async {
      SharedPreferences.setMockInitialValues({'settings_senior_mode': false});
      await tester.binding.setSurfaceSize(const Size(400, 900));

      final container = ProviderContainer(
        overrides: [
          protectionStatusProvider.overrideWith((ref) => ProtectionNotifier(ref.watch(callScreeningServiceProvider))..state = const AsyncValue.data(true)),
          blacklistControllerProvider.overrideWith((ref) => BlacklistNotifier(
                getBlacklistUseCase: ref.watch(getBlacklistUseCaseProvider),
                syncBlacklistUseCase: ref.watch(syncBlacklistUseCaseProvider),
                repository: ref.watch(blacklistRepositoryProvider),
              )..state = const AsyncValue.data(<BlacklistedEntry>[])),
        ],
      );

      await tester.pumpWidget(buildTestApp(container: container));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Mode Simplifié Actif'), findsNothing);
    });
  });
}
