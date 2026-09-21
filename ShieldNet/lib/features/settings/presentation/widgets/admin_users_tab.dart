import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

/// Onglet de gestion des utilisateurs inscrits
class AdminUsersTab extends StatelessWidget {
  final List<Map<String, dynamic>> users;
  final bool isLoading;

  const AdminUsersTab({
    super.key,
    required this.users,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = AppTheme.cardBg(isDark);
    final borderColor = AppTheme.borderColor(isDark);

    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (users.isEmpty) {
      return const Center(child: Text('Aucun utilisateur enregistré.', style: TextStyle(color: Colors.grey)));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: users.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final u = users[index];
        final email = u['email'] as String? ?? 'Sans email';
        final name = u['name'] as String? ?? '';
        final isStaff = u['is_staff'] as bool? ?? false;
        final reportsCount = u['reports_count'] as int? ?? 0;

        return Container(
          decoration: BoxDecoration(color: cardBg, border: Border.all(color: borderColor)),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isStaff ? AppTheme.accentOrange.withValues(alpha: 0.15) : AppTheme.primaryColor.withValues(alpha: 0.1),
              child: Icon(
                isStaff ? Icons.admin_panel_settings_rounded : Icons.person_rounded,
                color: isStaff ? AppTheme.accentOrange : AppTheme.primaryColor,
              ),
            ),
            title: Row(
              children: [
                Expanded(child: Text(name.isNotEmpty ? name : email.split('@')[0], style: const TextStyle(fontWeight: FontWeight.bold))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isStaff ? AppTheme.accentOrange.withValues(alpha: 0.15) : AppTheme.accentGreen.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(isStaff ? 'ADMIN' : 'MEMBRE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isStaff ? AppTheme.accentOrange : AppTheme.accentGreen)),
                ),
              ],
            ),
            subtitle: Text('$email • $reportsCount signalement(s) soumis', style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ),
        );
      },
    );
  }
}
