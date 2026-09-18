import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/services/serenity_score_calculator.dart';

/// Carte visuelle du Score de Sérénité Numérique ("Peace of Mind Index")
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
            children: [
              // Jauge circulaire stylisée avec pourcentage
              SizedBox(
                width: 56,
                height: 56,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: result.score / 100.0,
                      strokeWidth: 6,
                      backgroundColor: result.statusColor.withValues(alpha: 0.15),
                      valueColor: AlwaysStoppedAnimation<Color>(result.statusColor),
                      strokeCap: StrokeCap.round,
                    ),
                    Center(
                      child: Text(
                        '${result.score}%',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: result.statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: result.statusColor,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            result.statusTitle,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: result.statusColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      result.score == 100
                          ? 'Toutes les barrières de protection sont activées.'
                          : '${result.recommendations.length} action(s) recommandée(s) pour 100% de protection.',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              if (result.score < 100)
                IconButton(
                  icon: const Icon(Icons.tune_rounded, size: 20),
                  tooltip: 'Améliorer mon score',
                  onPressed: onOpenSettings,
                ),
            ],
          ),

          if (result.recommendations.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 10),
            // Première recommandation prioritaire
            InkWell(
              onTap: onOpenSettings,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: result.statusColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(result.recommendations.first.icon, size: 18, color: result.statusColor),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Conseil : ${result.recommendations.first.title} (+${result.recommendations.first.scoreBonus}%)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: result.statusColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(Icons.arrow_forward_ios_rounded, size: 12, color: result.statusColor),
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
