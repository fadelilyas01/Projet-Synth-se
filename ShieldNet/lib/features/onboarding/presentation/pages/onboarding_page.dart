import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shieldnet/core/theme/app_theme.dart';
import 'package:shieldnet/main.dart';

class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  int _currentPage = 0;
  final PageController _pageController = PageController();

  final List<Map<String, dynamic>> _onboardingData = [
    {
      "title": "Protection Anti-Spam",
      "subtitle": "Tranquillité absolue au quotidien",
      "text": "ShieldNet filtre les appels malveillants et le démarchage agressif en temps réel sans jamais perturber votre ligne.",
      "icon": Icons.shield_rounded,
      "gradient": [AppTheme.primaryColor, AppTheme.primaryDarkColor],
      "features": [
        "Blocage automatique des spams connus",
        "Filtrage en arrière-plan sans sonnerie",
        "Vérification instantanée des numéros suspects",
      ],
    },
    {
      "title": "Confidentialité Totale",
      "subtitle": "Vos données ne quittent jamais votre appareil",
      "text": "Chaque numéro est chiffré et haché localement (SHA-256 avec sel cryptographique). Aucun répertoire n'est transmis à nos serveurs.",
      "icon": Icons.lock_rounded,
      "gradient": [AppTheme.accentGreen, const Color(0xFF047857)],
      "features": [
        "Anonymisation cryptographique locale",
        "Zéro partage de vos contacts personnels",
        "Conforme aux normes de sécurité strictes",
      ],
    },
    {
      "title": "Prêt en 1 Geste",
      "subtitle": "Activez le bouclier intelligent",
      "text": "Accordez les autorisations nécessaires pour permettre à ShieldNet d'intercepter les spams avant qu'ils ne sonnent.",
      "icon": Icons.flash_on_rounded,
      "gradient": [AppTheme.primaryLightColor, AppTheme.primaryDarkColor],
      "features": [
        "Rôle de filtrage d'appels natif",
        "Détection préventive des SMS frauduleux",
        "Protection active 24h/24 en toute discrétion",
      ],
    }
  ];

  Future<void> _requestPermissionsAndFinish() async {
    HapticFeedback.mediumImpact();
    await [
      Permission.phone,
      Permission.contacts,
      Permission.sms,
    ].request();

    const storage = FlutterSecureStorage();
    await storage.write(key: 'has_seen_onboarding', value: 'true');

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainTabNavigationScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isLastPage = _currentPage == _onboardingData.length - 1;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar: Logo & Passer
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.shield, color: AppTheme.primaryColor, size: 24),
                      SizedBox(width: 8),
                      Text(
                        'ShieldNet',
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: -0.5),
                      ),
                    ],
                  ),
                  if (!isLastPage)
                    TextButton(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        _requestPermissionsAndFinish();
                      },
                      child: const Text('Passer', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                    )
                  else
                    const SizedBox(height: 48),
                ],
              ),
            ),

            // Carrousel de diapositives
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (value) {
                  setState(() => _currentPage = value);
                },
                itemCount: _onboardingData.length,
                itemBuilder: (context, index) {
                  final data = _onboardingData[index];
                  final List<Color> gradient = data["gradient"] as List<Color>;
                  final List<String> features = data["features"] as List<String>;

                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 12.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 10),
                        // Badge d'icône avec halo et dégradé
                        Container(
                          width: 110,
                          height: 110,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: gradient,
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: gradient.first.withValues(alpha: 0.35),
                                blurRadius: 28,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Icon(
                            data["icon"] as IconData,
                            size: 52,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 28),

                        // Titre et sous-titre
                        Text(
                          data["title"] as String,
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          data["subtitle"] as String,
                          style: TextStyle(
                            fontSize: 13,
                            color: gradient.first,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 14),

                        // Description
                        Text(
                          data["text"] as String,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 22),

                        // Liste de points forts
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: AppTheme.cardBg(isDark),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppTheme.borderColor(isDark)),
                          ),
                          child: Column(
                            children: features.map((feat) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4.0),
                                child: Row(
                                  children: [
                                    Icon(Icons.check_circle_rounded, color: gradient.first, size: 18),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        feat,
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Indicateurs pilules
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _onboardingData.length,
                  (index) => _buildDot(index: index),
                ),
              ),
            ),

            // Bouton Suivant / Commencer
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: isLastPage ? AppTheme.accentGreen : AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    elevation: 4,
                    shadowColor: (isLastPage ? AppTheme.accentGreen : AppTheme.primaryColor).withValues(alpha: 0.4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    if (isLastPage) {
                      _requestPermissionsAndFinish();
                    } else {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 350),
                        curve: Curves.easeInOutCubic,
                      );
                    }
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        isLastPage ? 'Activer la protection' : 'Continuer',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      Icon(isLastPage ? Icons.shield_rounded : Icons.arrow_forward_rounded, size: 20),
                    ],
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildDot({required int index}) {
    final isSelected = _currentPage == index;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      height: 8,
      width: isSelected ? 28 : 8,
      decoration: BoxDecoration(
        color: isSelected
            ? AppTheme.primaryColor
            : Colors.grey.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}
