import 'package:shieldnet/core/utils/logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:call_log/call_log.dart' as call_log;
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/database/database_helper.dart';
import '../../../../core/security/crypto_utils.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../l10n/app_localizations.dart';
import '../controllers/blacklist_controller.dart';
import '../../../../core/services/night_shield_service.dart';
import '../../../../core/services/citizen_impact_service.dart';
import '../../domain/services/serenity_score_calculator.dart';
import '../widgets/pulse_radar_shield.dart';
import '../widgets/serenity_score_card.dart';
import '../../../sms_inspector/presentation/pages/sms_inspector_page.dart';
import '../../../community/presentation/widgets/citizen_impact_card.dart';
import '../../../settings/presentation/pages/settings_page.dart';

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
  CitizenImpactData? _impactData;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadInterceptedMetrics();
    _loadImpactData();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkClipboard());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _quickCheckController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(protectionStatusProvider.notifier).checkStatus();
      _loadInterceptedMetrics();
      _loadImpactData();
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

  Future<void> _loadImpactData() async {
    try {
      final data = await CitizenImpactService.getImpactData(localBlockedSpams: _interceptedCallsCount);
      if (mounted) setState(() => _impactData = data);
    } catch (_) {}
  }

  Future<void> _loadInterceptedMetrics() async {
    try {
      final status = await Permission.phone.status;
      if (!status.isGranted) return;

      final list = await DatabaseHelper.instance.getAllBlacklistedNumbers();
      final entries = await call_log.CallLog.get();
      final hashes = list.map((e) => e.phoneHash).toSet();
      int intercepted = 0;
      for (var entry in entries.take(100)) {
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

    final checkUseCase = ref.read(checkNumberUseCaseProvider);
    final analysisEither = await checkUseCase(rawPhone);

    if (!mounted) return;
    Navigator.pop(context); // Fermer le loader

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
  }

  @override
  Widget build(BuildContext context) {
    final protectionState = ref.watch(protectionStatusProvider);
    final blacklistAsync = ref.watch(blacklistControllerProvider);
    final isContactsOnly = ref.watch(contactsOnlyProvider);
    final nightShieldState = ref.watch(nightShieldProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = AppTheme.cardBg(isDark);
    final borderColor = AppTheme.borderColor(isDark);

    final totalBlocked = blacklistAsync.value?.length ?? 0;
    final l10n = AppLocalizations.of(context);
    final isProtectionActive = protectionState.value ?? false;

    final serenityResult = SerenityScoreCalculator.compute(
      isCallScreeningActive: isProtectionActive,
      isAutoBlockEnabled: true,
      isBiometricEnabled: true,
      isContactsOnlyEnabled: isContactsOnly,
      isCacheFresh: totalBlocked > 0,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('ShieldNet', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.5)),
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
          _loadImpactData();
        },
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          children: [
            // BANDEAU DU PRESSE-PAPIER (DÉTECTION AUTOMATIQUE)
            if (_detectedClipboardNumber != null) ...[
              _buildClipboardBanner(cardBg, borderColor, isDark),
              const SizedBox(height: 16),
            ],

            // 1. CARTE DE PROTECTION "ZEN" AVEC RADAR CONCENTRIQUE
            protectionState.when(
              data: (isActive) => _buildZenShieldCard(isActive, isContactsOnly, nightShieldState.isCurrentlyInNightWindow, l10n),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Text('Erreur: $err'),
            ),
            const SizedBox(height: 16),

            // 2. SCORE DE SÉRÉNITÉ NUMÉRIQUE
            SerenityScoreCard(
              result: serenityResult,
              onOpenSettings: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsPage()));
              },
            ),
            const SizedBox(height: 16),

            // 3. ACTIONS RAPIDES : VÉRIFICATION & INSPECTEUR SMS
            _buildActionHub(context, cardBg, borderColor, isDark, l10n),
            const SizedBox(height: 20),

            // 2. STATISTIQUES SIMPLES & VALORISANTES
            Row(
              children: [
                Expanded(
                  child: _buildSimpleMetricCard(
                    icon: Icons.block_rounded,
                    color: AppTheme.accentRed,
                    count: '$_interceptedCallsCount',
                    label: l10n?.statSpamIntercepted ?? 'Spams interceptés',
                    cardBg: cardBg,
                    borderColor: borderColor,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _buildSimpleMetricCard(
                    icon: Icons.shield_rounded,
                    color: AppTheme.accentGreen,
                    count: '$totalBlocked',
                    label: l10n?.statNumbersBlocked ?? 'Numéros bloqués',
                    cardBg: cardBg,
                    borderColor: borderColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // IMPACT CITOYEN & ENTRAIDE
            if (_impactData != null) ...[
              CitizenImpactCard(
                data: _impactData!,
                onReportSpam: () => _showQuickVerificationDialog(context),
              ),
              const SizedBox(height: 24),
            ],

            // 3. RECENTS SPAMS CONNUS
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
                          item.category.toUpperCase(),
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
          ],
        ),
      ),
    );
  }

  Widget _buildClipboardBanner(Color cardBg, Color borderColor, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.accentCyan.withValues(alpha: 0.6), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: AppTheme.accentCyan.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.accentCyan.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.content_paste_search_rounded, color: AppTheme.accentCyan, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Numéro copié détecté',
                  style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  _detectedClipboardNumber!,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentCyan,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              final phone = _detectedClipboardNumber!;
              setState(() => _detectedClipboardNumber = null);
              _executeVerification(phone);
            },
            child: const Text('Vérifier', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 6),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 18, color: Colors.grey),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () {
              setState(() {
                _dismissedClipboardNumber = _detectedClipboardNumber;
                _detectedClipboardNumber = null;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActionHub(BuildContext context, Color cardBg, Color borderColor, bool isDark, AppLocalizations? l10n) {
    return Row(
      children: [
        // 1. Bouton Vérifier un Numéro
        Expanded(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                _showQuickVerificationDialog(context);
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.search_rounded, color: AppTheme.primaryColor, size: 20),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Vérifier Numéro',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Annuaire anti-spam',
                            style: TextStyle(fontSize: 10, color: Colors.grey),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),

        // 2. Bouton Inspecteur SMS & Phishing
        Expanded(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SmsInspectorPage()),
                );
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.accentCyan.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.mark_email_read_rounded, color: AppTheme.accentCyan, size: 20),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Inspecteur SMS',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Détection phishing',
                            style: TextStyle(fontSize: 10, color: Colors.grey),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildZenShieldCard(bool isActive, bool isContactsOnly, bool isNightWindow, AppLocalizations? l10n) {
    final shieldStatusText = !isActive
        ? (l10n?.shieldSuspended ?? 'Filtrage suspendu')
        : (isContactsOnly
            ? (l10n?.shieldStrictBadge ?? 'Bouclier Strict (Contacts Seuls)')
            : (l10n?.shieldRealtime ?? 'Bouclier en temps réel'));
    final shieldTitle = isActive
        ? (isContactsOnly
            ? (l10n?.shieldStrictTitle ?? 'Protection Maximale')
            : (l10n?.shieldProtected ?? 'Vous êtes protégé'))
        : (l10n?.shieldInactive ?? 'Protection inactive');
    final shieldDesc = isActive
        ? (isContactsOnly
            ? (l10n?.shieldStrictDesc ?? 'Seuls vos contacts enregistrés sont autorisés à sonner.')
            : (l10n?.shieldActiveDesc ?? 'ShieldNet filtre automatiquement les appels malveillants.'))
        : (l10n?.shieldInactiveDesc ?? 'Activez le filtrage pour bloquer les appels indésirables.');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 26),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: isActive
            ? AppTheme.shieldActiveGradient
            : AppTheme.shieldInactiveGradient,
        boxShadow: [
          BoxShadow(
            color: (isActive ? AppTheme.accentGreen : AppTheme.accentRed).withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          // Badge Bouclier Nocturne si actif
          if (isNightWindow) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.indigo.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.bedtime_rounded, size: 13, color: Colors.white),
                  SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Bouclier Nocturne Actif',
                      style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Badge d'état subtil
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: !isActive
                        ? const Color(0xFFFCA5A5)
                        : (isContactsOnly ? AppTheme.accentOrange : AppTheme.accentCyan),
                  ),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    shieldStatusText,
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Bouclier animé avec radar pulsant à ondes concentriques
          PulseRadarShield(
            isActive: isActive,
            isContactsOnly: isContactsOnly,
            onTap: () {
              ref.read(protectionStatusProvider.notifier).toggleProtection();
            },
          ),
          const SizedBox(height: 16),
          Text(
            shieldTitle,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            shieldDesc,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.92), fontSize: 13),
          ),
          if (!isActive) ...[
            const SizedBox(height: 18),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: ElevatedButton.icon(
                onPressed: () async {
                  HapticFeedback.lightImpact();
                  final activated = await ref.read(protectionStatusProvider.notifier).requestPermission();
                  if (!mounted) return;
                  HapticFeedback.mediumImpact();
                  final successMsg = l10n?.protectionActiveSuccess ?? 'Protection ShieldNet activée avec succès !';
                  final permMsg = l10n?.protectionPermissionRequired ?? 'Veuillez accorder les autorisations pour activer la protection.';
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          Icon(
                            activated ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              activated ? successMsg : permMsg,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      backgroundColor: activated ? AppTheme.accentGreen : AppTheme.accentRed,
                    ),
                  );
                },
                icon: const Icon(Icons.flash_on_rounded, size: 18),
                label: Text(l10n?.btnActivateProtection ?? 'Activer la protection', style: const TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppTheme.accentRed,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 3,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSimpleMetricCard({
    required IconData icon,
    required Color color,
    required String count,
    required String label,
    required Color cardBg,
    required Color borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: color, size: 20),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('Live', style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(count, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
