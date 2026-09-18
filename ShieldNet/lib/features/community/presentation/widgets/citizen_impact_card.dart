import 'package:flutter/material.dart';
import '../../../../core/services/citizen_impact_service.dart';
import '../../../../core/theme/app_theme.dart';

class CitizenImpactCard extends StatelessWidget {
  final CitizenImpactData data;
  final VoidCallback? onReportSpam;

  const CitizenImpactCard({
    super.key,
    required this.data,
    this.onReportSpam,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = AppTheme.cardBg(isDark);
    final borderColor = AppTheme.borderColor(isDark);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 12,
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
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.accentOrange.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.people_alt_rounded, color: AppTheme.accentOrange, size: 20),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Impact Citoyen',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Protection collaborative',
                            style: TextStyle(fontSize: 11, color: Colors.grey),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: data.currentRank.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: data.currentRank.color.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(data.currentRank.icon, size: 14, color: data.currentRank.color),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          data.currentRank.title,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: data.currentRank.color),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Compteur estimé
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                    : [const Color(0xFFF1F5F9), const Color(0xFFE2E8F0)],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(Icons.favorite_rounded, color: AppTheme.accentRed, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '~${data.protectedCitizensEstimate} concitoyens protégés',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        data.reportsCount == 0
                            ? 'Signalez un spam pour protéger les autres utilisateurs.'
                            : 'Grâce à vos ${data.reportsCount} signalement(s) validé(s).',
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Ligne des badges
          Row(
            children: data.allBadges.map((badge) {
              return Expanded(
                child: Tooltip(
                  message: '${badge.title} : ${badge.description}',
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: badge.isUnlocked
                          ? badge.color.withValues(alpha: 0.12)
                          : Colors.grey.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: badge.isUnlocked ? badge.color.withValues(alpha: 0.4) : Colors.transparent,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          badge.icon,
                          size: 20,
                          color: badge.isUnlocked ? badge.color : Colors.grey.shade400,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          badge.title,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: badge.isUnlocked ? FontWeight.bold : FontWeight.normal,
                            color: badge.isUnlocked ? badge.color : Colors.grey,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
