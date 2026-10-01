import 'package:shieldnet/core/utils/logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/database/database_helper.dart';
import '../../../../core/security/crypto_utils.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../l10n/app_localizations.dart';
import '../controllers/blacklist_controller.dart';
import '../../../../core/services/night_shield_service.dart';
import '../../../../core/services/call_log_helper.dart';
import '../../domain/services/serenity_score_calculator.dart';
import '../widgets/clipboard_banner.dart';
import '../widgets/action_hub_row.dart';
import '../widgets/zen_shield_card.dart';
import '../widgets/simple_metric_card.dart';
import '../widgets/serenity_score_card.dart';
import '../widgets/regional_threat_card.dart';
import '../widgets/device_integrity_banner.dart';
import '../../../community/presentation/widgets/citizen_impact_card.dart';
import '../../../settings/presentation/pages/settings_page.dart';
import '../../../../core/widgets/app_logo.dart';

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage>
    with WidgetsBindingObserver {
  int _interceptedCallsCount = 0;
  final _quickCheckController = TextEditingController();
  String? _detectedClipboardNumber;
  String? _dismissedClipboardNumber;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadInterceptedMetrics();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkClipboard());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _quickCheckController.dispose();
    super.dispose();
  }

  DateTime? _lastResumeCheck;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final now = DateTime.now();
      if (_lastResumeCheck == null || now.difference(_lastResumeCheck!).inSeconds > 15) {
        _lastResumeCheck = now;
        ref.read(protectionStatusProvider.notifier).checkStatus();
        _loadInterceptedMetrics();
      }
      _checkClipboard();
    }
  }

  Future<void> _checkClipboard() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text?.trim();
      if (text == null || text.isEmpty) return;

      final digitCount = text.replaceAll(RegExp(r'\D'), '').length;
      final isValidPhone = digitCount >= 7 && digitCount <= 16 && RegExp(r'^[\+]?[\d\s\-\.\(\)]{7,20}$').hasMatch(text);

      if (isValidPhone && text != _detectedClipboardNumber && text != _dismissedClipboardNumber) {
        if (mounted) {
          setState(() {
            _detectedClipboardNumber = text;
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _loadInterceptedMetrics() async {
    try {
      final status = await Permission.phone.status;
      if (!status.isGranted) return;

      final list = await DatabaseHelper.instance.getAllBlacklistedNumbers();
      final entries = await CallLogHelper.getSafeEntries(limit: 100);
      final hashes = list.map((e) => e.phoneHash).toSet();
      int intercepted = 0;
      for (var entry in entries) {
        if (entry.number != null && hashes.contains(CryptoUtils.hashPhoneNumber(entry.number!))) {
          intercepted++;
        }
      }
      if (mounted) {
        setState(() => _interceptedCallsCount = intercepted);
      }
    } catch (e) {
      AppLogger.log('[DashboardPage] Impossible de charger les métriques d\'interception: $e');
    }
  }

  void _showQuickVerificationDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                const Icon(Icons.search_rounded, color: AppTheme.primaryColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n?.dialogCheckNumber ?? 'Vérifier un numéro',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n?.dialogCheckPrompt ?? 'Saisissez un numéro pour vérifier s\'il est signalé comme spam :',
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _quickCheckController,
                  keyboardType: TextInputType.phone,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: '+1 800 123 4567',
                    prefixIcon: const Icon(Icons.phone_outlined, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l10n?.btnCancel ?? 'Annuler'),
              ),
              ElevatedButton(
                onPressed: () {
                  final phone = _quickCheckController.text.trim();
                  if (phone.isNotEmpty) {
                    Navigator.pop(ctx);
                    _executeVerification(phone);
                  }
                },
                child: Text(l10n?.btnVerify ?? 'Vérifier'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _executeVerification(String rawPhone) async {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final checkUseCase = ref.read(checkNumberUseCaseProvider);
      final analysisEither = await checkUseCase(rawPhone);

      if (!mounted) return;
      Navigator.pop(context);

      analysisEither.fold(
        (failure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(failure.message), backgroundColor: AppTheme.accentRed),
          );
        },
        (analysis) {
          final isSpam = analysis.isSpam;
          final isWhitelisted = analysis.isWhitelisted;

          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Icon(
                    isWhitelisted
                        ? Icons.verified_user_rounded
                        : (isSpam ? Icons.warning_amber_rounded : Icons.check_circle_rounded),
                    color: isWhitelisted
                        ? AppTheme.primaryColor
                        : (isSpam ? AppTheme.accentRed : AppTheme.accentGreen),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isWhitelisted
                          ? (l10n?.dialogVerified ?? 'Numéro Vérifié')
                          : (isSpam ? (l10n?.dialogSpamDetected ?? 'Attention : Spam Détecté') : (l10n?.dialogSafeNumber ?? 'Numéro Sûr')),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    CryptoUtils.maskPhoneNumber(rawPhone),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    isWhitelisted
                        ? (l10n?.dialogVerifiedDesc ?? 'Ce numéro est vérifié et certifié par l\'administrateur.')
                        : (isSpam
                            ? (l10n?.dialogSpamDesc ?? 'Ce numéro a été identifié comme indésirable.')
                            : (l10n?.dialogSafeDesc ?? 'Aucun signalement malveillant pour ce numéro.')),
                    style: const TextStyle(fontSize: 13, height: 1.4),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n?.btnUnderstood ?? 'Compris')),
              ],
            ),
          );
        },
      );
    } catch (e) {
      if (mounted) {
        final isEn = (l10n?.localeName == 'en') || (Localizations.localeOf(context).languageCode == 'en');
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEn ? 'Error during phone number verification: $e' : 'Erreur lors de la vérification du numéro: $e'),
            backgroundColor: AppTheme.accentRed,
          ),
        );
      }
    }
  }

  String _formatCategory(String category, bool isEn) {
    final cat = category.toLowerCase().trim();
    if (isEn) {
      if (cat.contains('fraud') || cat.contains('arnaque')) return 'FRAUD / SCAM';
      if (cat.contains('telemarketing') || cat.contains('démarchage') || cat.contains('demarchage')) return 'TELEMARKETING';
      if (cat.contains('phishing') || cat.contains('hameçonnage')) return 'PHISHING';
      if (cat.contains('robocall') || cat.contains('automate') || cat.contains('silence')) return 'ROBOCALL';
      return category.toUpperCase();
    } else {
      if (cat.contains('fraud') || cat.contains('arnaque')) return 'ARNAQUE';
      if (cat.contains('telemarketing') || cat.contains('démarchage') || cat.contains('demarchage')) return 'DÉMARCHAGE';
      if (cat.contains('phishing') || cat.contains('hameçonnage')) return 'HAMEÇONNAGE';
      if (cat.contains('robocall') || cat.contains('automate') || cat.contains('silence')) return 'AUTOMATE';
      return category.toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    final protectionState = ref.watch(protectionStatusProvider);
    final blacklistAsync = ref.watch(blacklistControllerProvider);
    final isContactsOnly = ref.watch(contactsOnlyProvider);
    final nightShieldState = ref.watch(nightShieldProvider);
    final impactAsync = ref.watch(citizenImpactProvider(_interceptedCallsCount));
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = AppTheme.cardBg(isDark);
    final borderColor = AppTheme.borderColor(isDark);

    final totalBlocked = blacklistAsync.value?.length ?? 0;
    final l10n = AppLocalizations.of(context);
    final isEn = (l10n?.localeName == 'en') || (Localizations.localeOf(context).languageCode == 'en');
    final isProtectionActive = protectionState.value ?? false;
    final isSeniorMode = ref.watch(seniorModeProvider);
    final integrityAsync = ref.watch(deviceIntegrityProvider);
    final regionalThreatsAsync = ref.watch(regionalThreatsProvider);

    final serenityResult = SerenityScoreCalculator.compute(
      isCallScreeningActive: isProtectionActive,
      isAutoBlockEnabled: true,
      isBiometricEnabled: true,
      isContactsOnlyEnabled: isContactsOnly,
      isCacheFresh: totalBlocked > 0,
    );

    return Scaffold(
      appBar: AppBar(
        title: const ShieldNetLogo.withText(size: 26, fontSize: 18),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded),
            tooltip: l10n?.dialogCheckNumber ?? 'Vérifier un numéro',
            onPressed: () => _showQuickVerificationDialog(context),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(blacklistControllerProvider.notifier).syncWithServer();
          ref.invalidate(citizenImpactProvider);
          ref.invalidate(regionalThreatsProvider);
          ref.invalidate(deviceIntegrityProvider);
          ref.invalidate(bloomFilterProvider);
        },
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          children: [
            // BANDEAU ALERTE INTÉGRITÉ APPAREIL (ROOT)
            integrityAsync.maybeWhen(
              data: (integrity) => DeviceIntegrityBanner(result: integrity),
              orElse: () => const SizedBox.shrink(),
            ),

            // BANDEAU MODE SÉNIORS / ACCESSIBILITÉ
            if (isSeniorMode) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.primaryColor, width: 2),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.elderly_rounded, color: AppTheme.primaryColor, size: 30),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n?.seniorModeActiveTitle ?? 'Mode Simplifié Actif',
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppTheme.primaryColor),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            l10n?.seniorModeActiveDesc ?? 'Textes et boutons agrandis. Votre téléphone est protégé contre toute fraude.',
                            style: const TextStyle(fontSize: 13, height: 1.3),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // BANDEAU ALERTE MENACES RÉGIONALES (SPOOFING CIBLÉ)
            regionalThreatsAsync.maybeWhen(
              data: (summary) => summary != null ? RegionalThreatCard(summary: summary) : const SizedBox.shrink(),
              orElse: () => const SizedBox.shrink(),
            ),

            // BANDEAU DU PRESSE-PAPIER
            if (_detectedClipboardNumber != null) ...[
              ClipboardBanner(
                detectedNumber: _detectedClipboardNumber!,
                onVerify: () {
                  final phone = _detectedClipboardNumber!;
                  setState(() => _detectedClipboardNumber = null);
                  _executeVerification(phone);
                },
                onDismiss: () {
                  setState(() {
                    _dismissedClipboardNumber = _detectedClipboardNumber;
                    _detectedClipboardNumber = null;
                  });
                },
              ),
              const SizedBox(height: 16),
            ],

            // Carte principale de statut de protection
            protectionState.when(
              data: (isActive) => ZenShieldCard(
                isActive: isActive,
                isContactsOnly: isContactsOnly,
                isNightWindow: nightShieldState.isCurrentlyInNightWindow,
                onToggleProtection: () {
                  ref.read(protectionStatusProvider.notifier).toggleProtection();
                },
                onActivateProtection: () async {
                  final activated = await ref.read(protectionStatusProvider.notifier).requestPermission();
                  if (!context.mounted) return;
                  HapticFeedback.mediumImpact();
                  final successMsg = l10n?.protectionActiveSuccess ?? 'Protection ShieldNet activée avec succès !';
                  final permMsg = l10n?.protectionPermissionRequired ?? 'Veuillez accorder les autorisations pour activer la protection.';
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          Icon(activated ? Icons.check_circle_rounded : Icons.error_outline_rounded, color: Colors.white),
                          const SizedBox(width: 10),
                          Expanded(child: Text(activated ? successMsg : permMsg, style: const TextStyle(fontWeight: FontWeight.w600))),
                        ],
                      ),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      backgroundColor: activated ? AppTheme.accentGreen : AppTheme.accentRed,
                    ),
                  );
                },
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Text(isEn ? 'Error: $err' : 'Erreur: $err'),
            ),
            const SizedBox(height: 16),

            // Raccourcis d'actions immédiates : Vérifier un numéro & Inspecteur SMS
            ActionHubRow(onVerifyNumber: () => _showQuickVerificationDialog(context)),
            const SizedBox(height: 16),

            // Compteurs statistiques d'activité locale
            Row(
              children: [
                Expanded(
                  child: SimpleMetricCard(
                    icon: Icons.call_end_rounded,
                    color: AppTheme.accentRed,
                    count: '$_interceptedCallsCount',
                    label: l10n?.statSpamIntercepted ?? 'Spams interceptés',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SimpleMetricCard(
                    icon: Icons.shield_outlined,
                    color: AppTheme.primaryColor,
                    count: '$totalBlocked',
                    label: l10n?.statNumbersBlocked ?? 'Numéros bloqués',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Historique des derniers spams interceptés
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    l10n?.recentBlockedSpams ?? 'Derniers Spams Bloqués',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Flexible(
                  child: TextButton(
                    onPressed: () => _showQuickVerificationDialog(context),
                    child: Text(
                      l10n?.verifyCallAction ?? 'Vérifier un appel',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            blacklistAsync.when(
              loading: () => const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator())),
              error: (err, stack) => const SizedBox(),
              data: (entries) {
                if (entries.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: borderColor),
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.accentGreen.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.check_circle_outline_rounded, color: AppTheme.accentGreen, size: 36),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          l10n?.calmLineTitle ?? 'Ligne calme et sécurisée',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l10n?.calmLineDesc ?? 'Aucune menace récente détectée sur votre appareil.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                  );
                }

                final recentItems = entries.take(4).toList();
                return Container(
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderColor),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: recentItems.length,
                    separatorBuilder: (context, index) => const Divider(height: 1, indent: 56),
                    itemBuilder: (ctx, index) {
                      final item = recentItems[index];
                      return ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.accentRed.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.call_end_rounded, color: AppTheme.accentRed, size: 18),
                        ),
                        title: Text(
                          item.maskedNumber.isNotEmpty ? item.maskedNumber : (l10n?.maskedNumberDefault ?? 'Numéro masqué'),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          _formatCategory(item.category, isEn),
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.accentRed.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            l10n?.badgeBlocked ?? 'Bloqué',
                            style: const TextStyle(color: AppTheme.accentRed, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
            const SizedBox(height: 24),

            // Diagnostic et niveau de sécurité de l'appareil
            SerenityScoreCard(
              result: serenityResult,
              onOpenSettings: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsPage()));
              },
            ),
            const SizedBox(height: 16),

            // Engagement communautaire citoyen
            impactAsync.maybeWhen(
              data: (impactData) => CitizenImpactCard(
                data: impactData,
                onReportSpam: () => _showQuickVerificationDialog(context),
              ),
              orElse: () => const SizedBox.shrink(),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
