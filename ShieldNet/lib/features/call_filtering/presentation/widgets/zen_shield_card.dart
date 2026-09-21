import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../l10n/app_localizations.dart';
import 'pulse_radar_shield.dart';

/// Carte principale de protection « Zen » avec radar concentrique animé
class ZenShieldCard extends StatelessWidget {
  final bool isActive;
  final bool isContactsOnly;
  final bool isNightWindow;
  final VoidCallback onToggleProtection;
  final VoidCallback onActivateProtection;

  const ZenShieldCard({
    super.key,
    required this.isActive,
    required this.isContactsOnly,
    required this.isNightWindow,
    required this.onToggleProtection,
    required this.onActivateProtection,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

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
            onTap: onToggleProtection,
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
                onPressed: () {
                  HapticFeedback.lightImpact();
                  onActivateProtection();
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
}
