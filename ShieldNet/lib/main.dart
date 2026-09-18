import 'package:shieldnet/core/utils/logger.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'core/theme/app_theme.dart';
import 'core/database/database_helper.dart';
import 'core/providers/app_providers.dart';

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

  // 1. Initialisation de la base de données SQLite locale
  await DatabaseHelper.instance.database;

  // 2. Initialisation du planificateur de synchronisation en arrière-plan
  try {
    await BackgroundSyncService.instance.initialize();
  } catch (e) {
    AppLogger.log("BackgroundSync init exception: $e");
  }

  // 3. Déclenchement automatique d'une synchronisation discrète au lancement
  try {
    BackgroundSyncService.instance.isAutoSyncEnabled().then((enabled) {
      if (enabled) {
        BackgroundSyncService.instance.syncNow().then((count) {
          AppLogger.log("Synchronisation automatique au démarrage réussie: $count numéros.");
        }).catchError((err) {
          AppLogger.log("Sync automatique au démarrage ignorée (backend hors-ligne ou erreur): $err");
        });
      }
    });
  } catch (e) {
    AppLogger.log("[Main] Échec de la vérification de synchronisation initiale: $e");
  }

  final sentryDsn = dotenv.isInitialized ? (dotenv.env['SENTRY_DSN'] ?? '').trim() : '';
  if (sentryDsn.isNotEmpty && !sentryDsn.contains('placeholder')) {
    await SentryFlutter.init(
      (options) {
        options.dsn = sentryDsn;
        options.tracesSampleRate = 1.0;
      },
      appRunner: () => runApp(
        const ProviderScope(
          child: ShieldNetApp(),
        ),
      ),
    );
  } else {
    runApp(
      const ProviderScope(
        child: ShieldNetApp(),
      ),
    );
  }
}

class ShieldNetApp extends ConsumerWidget {
  const ShieldNetApp({super.key});

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
      home: const InitialSplashScreen(),
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
    const storage = FlutterSecureStorage();
    final hasSeen = await storage.read(key: 'has_seen_onboarding');
    
    await Future.delayed(const Duration(milliseconds: 500));

    if (mounted) {
      if (hasSeen == 'true') {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MainTabNavigationScreen()),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const OnboardingPage()),
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
