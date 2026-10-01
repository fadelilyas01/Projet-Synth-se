import 'package:shieldnet/core/utils/logger.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/theme/app_theme.dart';
import 'core/database/database_helper.dart';
import 'core/providers/app_providers.dart';
import 'core/security/crypto_utils.dart';

import 'features/call_filtering/presentation/pages/dashboard_page.dart';
import 'features/call_filtering/presentation/pages/activity_page.dart';
import 'features/settings/presentation/pages/settings_page.dart';
import 'features/onboarding/presentation/pages/onboarding_page.dart';

import 'core/services/background_sync_service.dart';

export 'core/providers/app_providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    AppLogger.log("[Main] Fichier .env non présent ou illisible, configuration par défaut: $e");
  }

  // Synchronisation sécurisée du sel cryptographique avec le Keystore Android
  try {
    final salt = CryptoUtils.resolveSalt();
    if (salt.isNotEmpty) {
      const MethodChannel('com.shieldnet.security')
          .invokeMethod('setCryptoSalt', {'salt': salt});
    }
  } catch (e) {
    AppLogger.log("[Main] Sel Keystore non synchronisé: $e");
  }

  // Initialisation précoce du cache SQLite local
  await DatabaseHelper.instance.database;

  // Enregistrement du worker de synchronisation en tâche de fond (WorkManager)
  try {
    await BackgroundSyncService.instance.initialize();
  } catch (e) {
    AppLogger.log("BackgroundSync init exception: $e");
  }

  // Tente une actualisation discrète de la liste noire au démarrage si l'option est active
  try {
    BackgroundSyncService.instance.isAutoSyncEnabled().then((enabled) {
      if (enabled) {
        BackgroundSyncService.instance.syncNow().then((count) {
          AppLogger.log("Synchronisation automatique au démarrage: $count numéros synchronisés.");
        }).catchError((err) {
          AppLogger.log("Sync au démarrage ignorée (backend hors-ligne ou pas de réseau): $err");
        });
      }
    });
  } catch (e) {
    AppLogger.log("[Main] Échec du déclenchement de la sync initiale: $e");
  }

  // Détection instantanée de l'onboarding via SharedPreferences (en mémoire sans latence Keystore)
  bool hasSeenOnboarding = false;
  try {
    final prefs = await SharedPreferences.getInstance();
    hasSeenOnboarding = prefs.getBool('has_seen_onboarding') ?? false;
    if (!hasSeenOnboarding) {
      const storage = FlutterSecureStorage();
      final secureVal = await storage.read(key: 'has_seen_onboarding');
      if (secureVal == 'true') {
        hasSeenOnboarding = true;
        await prefs.setBool('has_seen_onboarding', true);
      }
    }
  } catch (e) {
    AppLogger.log("[Main] Erreur lecture statut onboarding: $e");
  }

  final sentryDsn = dotenv.isInitialized ? (dotenv.env['SENTRY_DSN'] ?? '').trim() : '';
  if (sentryDsn.isNotEmpty && !sentryDsn.contains('placeholder')) {
    await SentryFlutter.init(
      (options) {
        options.dsn = sentryDsn;
        options.tracesSampleRate = 1.0;
      },
      appRunner: () => runApp(
        ProviderScope(
          child: ShieldNetApp(hasSeenOnboarding: hasSeenOnboarding),
        ),
      ),
    );
  } else {
    runApp(
      ProviderScope(
        child: ShieldNetApp(hasSeenOnboarding: hasSeenOnboarding),
      ),
    );
  }
}

class ShieldNetApp extends ConsumerWidget {
  final bool hasSeenOnboarding;
  const ShieldNetApp({super.key, this.hasSeenOnboarding = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);

    return MaterialApp(
      title: 'ShieldNet Pro Anti-Spam',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('fr', ''),
        Locale('en', ''),
      ],
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      home: hasSeenOnboarding
          ? const MainTabNavigationScreen()
          : const OnboardingPage(),
      onUnknownRoute: (settings) {
        AppLogger.log('[Navigation] Route inconnue interceptée: ${settings.name}');
        return MaterialPageRoute(
          builder: (_) => const MainTabNavigationScreen(),
        );
      },
    );
  }
}

class InitialSplashScreen extends StatefulWidget {
  const InitialSplashScreen({super.key});

  @override
  State<InitialSplashScreen> createState() => _InitialSplashScreenState();
}

class _InitialSplashScreenState extends State<InitialSplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkOnboarding();
  }

  Future<void> _checkOnboarding() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      var hasSeen = prefs.getBool('has_seen_onboarding') ?? false;
      if (!hasSeen) {
        const storage = FlutterSecureStorage();
        final secureVal = await storage.read(key: 'has_seen_onboarding');
        hasSeen = (secureVal == 'true');
      }

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => hasSeen ? const MainTabNavigationScreen() : const OnboardingPage(),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MainTabNavigationScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? AppTheme.backgroundDark : AppTheme.backgroundLight,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.shield_outlined, size: 68, color: AppTheme.primaryColor),
            ),
            const SizedBox(height: 22),
            Text(
              'ShieldNet',
              style: TextStyle(
                color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              Localizations.maybeLocaleOf(context)?.languageCode == 'en'
                  ? 'Telecom Security & Privacy'
                  : 'Sécurité Télécom & Confidentialité',
              style: TextStyle(
                color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 36),
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: AppTheme.primaryColor),
            ),
          ],
        ),
      ),
    );
  }
}

class MainTabNavigationScreen extends ConsumerStatefulWidget {
  const MainTabNavigationScreen({super.key});

  @override
  ConsumerState<MainTabNavigationScreen> createState() => _MainTabNavigationScreenState();
}

class _MainTabNavigationScreenState extends ConsumerState<MainTabNavigationScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    DashboardPage(),
    ActivityPage(),
    SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    ref.watch(localeProvider);
    final l10n = AppLocalizations.of(context);
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    final protectionLabel = l10n?.tabProtection ?? (isEn ? 'Protection' : 'Protection');
    final activityLabel = l10n?.tabActivity ?? (isEn ? 'Activity' : 'Activité');
    final settingsLabel = l10n?.tabSettings ?? (isEn ? 'Settings' : 'Paramètres');

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        indicatorColor: AppTheme.primaryColor.withValues(alpha: 0.15),
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.shield_outlined),
            selectedIcon: const Icon(Icons.shield, color: AppTheme.primaryColor),
            label: protectionLabel,
          ),
          NavigationDestination(
            icon: const Icon(Icons.history_outlined),
            selectedIcon: const Icon(Icons.history, color: AppTheme.primaryColor),
            label: activityLabel,
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings, color: AppTheme.primaryColor),
            label: settingsLabel,
          ),
        ],
      ),
    );
  }
}
