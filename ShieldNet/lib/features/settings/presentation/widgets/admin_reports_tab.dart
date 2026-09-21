import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

/// Onglet des signalements utilisateur avec actions de modération
class AdminReportsTab extends StatelessWidget {
  final List<Map<String, dynamic>> reports;
  final bool isLoading;
  final void Function(String phoneHash, String action) onModerate;
  final void Function(String reportId) onDeleteReport;

  const AdminReportsTab({
    super.key,
    required this.reports,
    required this.isLoading,
    required this.onModerate,
    required this.onDeleteReport,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = AppTheme.cardBg(isDark);
    final borderColor = AppTheme.borderColor(isDark);

    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (reports.isEmpty) {
      return const Center(child: Text('Aucun signalement utilisateur.', style: TextStyle(color: Colors.grey)));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: reports.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final r = reports[index];
        final id = r['id'] as String? ?? '';
        final masked = r['masked_number'] as String? ?? 'Numéro';
        final phoneHash = r['phone_hash'] as String? ?? '';
        final category = r['category'] as String? ?? '';
        final comment = r['comment'] as String? ?? '';
        final reporter = r['reporter_email'] as String? ?? 'Anonyme';

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: borderColor)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(masked, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                    child: Text(category, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              if (comment.isNotEmpty) ...[
                Text('"$comment"', style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 12)),
                const SizedBox(height: 6),
              ],
              Text('Par : $reporter', style: const TextStyle(fontSize: 11, color: Colors.grey)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.check_circle_outline, size: 16, color: AppTheme.accentGreen),
                    label: const Text('Blanchir', style: TextStyle(color: AppTheme.accentGreen, fontSize: 12)),
                    onPressed: () => onModerate(phoneHash, 'whitelist'),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    icon: const Icon(Icons.block, size: 16, color: AppTheme.accentRed),
                    label: const Text('Bloquer', style: TextStyle(color: AppTheme.accentRed, fontSize: 12)),
                    onPressed: () => onModerate(phoneHash, 'block'),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18, color: Colors.grey),
                    tooltip: 'Supprimer ce signalement',
                    onPressed: () => onDeleteReport(id),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
