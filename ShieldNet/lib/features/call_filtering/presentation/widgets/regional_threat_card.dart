import 'package:flutter/material.dart';
import '../../../../core/models/regional_threat.dart';
import '../../../../core/theme/app_theme.dart';

/// Carte d'alerte et de veille sur les menaces téléphoniques régionales ciblées (Spoofing)
class RegionalThreatCard extends StatelessWidget {
  final RegionalThreatSummary summary;

  const RegionalThreatCard({
    super.key,
    required this.summary,
  });

  void _showDetailsBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Row(
                children: [
                  Icon(Icons.radar_rounded, color: AppTheme.accentOrange, size: 24),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Radar Régional des Arnaques',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Analyse en temps réel des vagues d\'usurpation d\'identité (Spoofing) ciblées par indicatif québécois et canadien.',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 16),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.5,
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: summary.regions.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (ctx, index) {
                    final item = summary.regions[index];
                    final isCritical = item.isCritical;
                    final isHigh = item.isHigh;
                    final badgeColor = isCritical
                        ? AppTheme.accentRed
                        : (isHigh ? AppTheme.accentOrange : AppTheme.accentGreen);

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(vertical: 4),
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          item.areaCode,
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: badgeColor,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      title: Text(
                        item.regionName,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      subtitle: Text(
                        '${item.totalSpams} signalements • Type: ${item.topCategory}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: badgeColor, width: 1),
                        ),
                        child: Text(
                          item.alertLevel,
                          style: TextStyle(
                            color: badgeColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Compris', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final highest = summary.highestAlert;
    if (highest == null) return const SizedBox.shrink();

    final isCritical = highest.isCritical;
    final isHigh = highest.isHigh;
    final alertColor = isCritical
        ? AppTheme.accentRed
        : (isHigh ? AppTheme.accentOrange : AppTheme.primaryColor);

    return InkWell(
      onTap: () => _showDetailsBottomSheet(context),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: alertColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: alertColor.withValues(alpha: 0.35), width: 1.5),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: alertColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isCritical ? Icons.warning_amber_rounded : Icons.cell_tower_rounded,
                color: alertColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Alerte Indicatif (${highest.areaCode})',
                        style: TextStyle(
                          color: alertColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: alertColor,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          highest.alertLevel,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Vague active d\'appels frauduleux ciblant la région : ${highest.regionName}.',
                    style: const TextStyle(fontSize: 12, height: 1.3),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
