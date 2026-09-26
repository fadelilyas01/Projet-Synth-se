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
    return const Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shield, size: 100, color: AppTheme.primaryColor),
            SizedBox(height: 20),
            Text('ShieldNet', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
            SizedBox(height: 40),
            CircularProgressIndicator(color: AppTheme.primaryColor),
          ],
        ),
      ),
    );
  }
}

class MainTabNavigationScreen extends StatefulWidget {
  const MainTabNavigationScreen({super.key});

  @override
  State<MainTabNavigationScreen> createState() => _MainTabNavigationScreenState();
}

class _MainTabNavigationScreenState extends State<MainTabNavigationScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    DashboardPage(),
    ActivityPage(),
    SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final protectionLabel = l10n?.tabProtection ?? 'Protection';
    final activityLabel = l10n?.tabActivity ?? 'Activité';
    final settingsLabel = l10n?.tabSettings ?? 'Paramètres';

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
