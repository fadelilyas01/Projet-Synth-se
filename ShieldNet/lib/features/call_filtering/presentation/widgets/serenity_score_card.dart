import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/services/serenity_score_calculator.dart';

/// Carte de diagnostic et de niveau de sécurité de l'appareil
/// Design épuré inspiré des audits de sécurité Google Pixel / Apple Privacy Report
class SerenityScoreCard extends StatelessWidget {
  final SerenityScoreResult result;
  final VoidCallback? onRefresh;
  final VoidCallback? onOpenSettings;

  const SerenityScoreCard({
    super.key,
    required this.result,
    this.onRefresh,
    this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = AppTheme.cardBg(isDark);
    final borderColor = AppTheme.borderColor(isDark);

    String localizedStatusTitle(String title) {
      if (title.contains('Optimale') || title.contains('Optimal')) return l10n?.serenityOptimal ?? title;
      if (title.contains('Élevée') || title.contains('High')) return l10n?.serenityHigh ?? title;
      if (title.contains('Partielle') || title.contains('Partial')) return l10n?.serenityPartial ?? title;
      if (title.contains('Vulnérable') || title.contains('Vulnerable')) return l10n?.serenityVulnerable ?? title;
      return title;
    }

    String localizedRecTitle(String title) {
      if (title.contains("filtrage d'appels") || title.contains('call screening')) return l10n?.recNativeFilterTitle ?? title;
      if (title.contains('base anti-spam') || title.contains('anti-spam database')) return l10n?.recUpdateDbTitle ?? title;
      if (title.contains('blocage automatique') || title.contains('auto-block')) return l10n?.recAutoBlockTitle ?? title;
      if (title.contains('biométrie') || title.contains('biometrics')) return l10n?.recBiometricTitle ?? title;
      if (title.contains('Contacts Uniquement') || title.contains('Contacts Only')) return l10n?.recContactsOnlyTitle ?? title;
      return title;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: result.statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  result.score >= 80 ? Icons.verified_user_outlined : Icons.security_update_warning_outlined,
                  color: result.statusColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '${l10n?.serenitySecurityLevel ?? "Niveau de sécurité"} : ${localizedStatusTitle(result.statusTitle)}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${result.score}%',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: result.statusColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: result.score / 100.0,
                        minHeight: 5,
                        backgroundColor: result.statusColor.withValues(alpha: 0.15),
                        valueColor: AlwaysStoppedAnimation<Color>(result.statusColor),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (result.recommendations.isNotEmpty) ...[
            const SizedBox(height: 12),
            InkWell(
              onTap: onOpenSettings,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: result.statusColor.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(result.recommendations.first.icon, size: 16, color: result.statusColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${l10n?.serenityRecommendation ?? "Recommandation"} : ${localizedRecTitle(result.recommendations.first.title)}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppTheme.textPrimaryDark : const Color(0xFF1E293B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(Icons.arrow_forward_ios_rounded, size: 11, color: result.statusColor),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
