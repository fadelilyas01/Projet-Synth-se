import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../sms_inspector/presentation/pages/sms_inspector_page.dart';

/// Hub d'actions rapides : Vérifier un numéro + Inspecteur SMS
class ActionHubRow extends StatelessWidget {
  final VoidCallback onVerifyNumber;

  const ActionHubRow({
    super.key,
    required this.onVerifyNumber,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = AppTheme.cardBg(isDark);
    final borderColor = AppTheme.borderColor(isDark);

    return Row(
      children: [
        // 1. Bouton Vérifier un Numéro
        Expanded(
          child: _buildActionButton(
            context: context,
            cardBg: cardBg,
            borderColor: borderColor,
            isDark: isDark,
            icon: Icons.search_rounded,
            iconColor: AppTheme.primaryColor,
            title: 'Vérifier Numéro',
            subtitle: 'Annuaire anti-spam',
            onTap: () {
              HapticFeedback.selectionClick();
              onVerifyNumber();
            },
          ),
        ),
        const SizedBox(width: 12),

        // 2. Bouton Inspecteur SMS & Phishing
        Expanded(
          child: _buildActionButton(
            context: context,
            cardBg: cardBg,
            borderColor: borderColor,
            isDark: isDark,
            icon: Icons.mark_email_read_rounded,
            iconColor: AppTheme.accentCyan,
            title: 'Inspecteur SMS',
            subtitle: 'Détection phishing',
            onTap: () {
              HapticFeedback.selectionClick();
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SmsInspectorPage()),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required BuildContext context,
    required Color cardBg,
    required Color borderColor,
    required bool isDark,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
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
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
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
    );
  }
}
