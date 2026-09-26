import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/theme/app_theme.dart';
import '../pages/developer_diagnostic_page.dart';

/// Onglet Vue d'Ensemble & Métriques de la console d'administration
class AdminOverviewTab extends ConsumerWidget {
  final Map<String, dynamic>? stats;
  final Map<String, dynamic>? syncStatus;
  final bool isLoadingStats;
  final bool isSyncingClient;
  final VoidCallback onPurge;
  final VoidCallback onConsensusAudit;
  final VoidCallback onDeltaSync;
  final VoidCallback onFullSync;
  final VoidCallback onRefresh;

  const AdminOverviewTab({
    super.key,
    required this.stats,
    required this.syncStatus,
    required this.isLoadingStats,
    required this.isSyncingClient,
    required this.onPurge,
    required this.onConsensusAudit,
    required this.onDeltaSync,
    required this.onFullSync,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = AppTheme.cardBg(isDark);
    final borderColor = AppTheme.borderColor(isDark);

    if (isLoadingStats) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Carte d'accès Admin / Gestionnaire
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: AppTheme.brandGradient,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const Icon(Icons.shield_rounded, color: Colors.white, size: 36),
              const SizedBox(width: 14),
              Expanded(
                child: Consumer(
                  builder: (context, ref, _) {
                    final currentUser = ref.watch(authNotifierProvider);
                    final isAdmin = currentUser?.isAdmin ?? false;
                    final displayEmail = currentUser?.email ?? 'admin@shieldnet.app';
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isAdmin ? 'Contrôle Administrateur Total' : 'Espace Gestionnaire & Modération',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isAdmin
                              ? 'Connecté en tant que $displayEmail avec privilèges complets (Web & Mobile).'
                              : 'Connecté en tant que $displayEmail avec rôle de gestion opérationnelle.',
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Métriques globales
        const Text('MÉTRIQUES SERVEUR EN TEMPS RÉEL', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.grey, letterSpacing: 1.1)),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.6,
          children: [
            _buildStatBox('Numéros Bloqués', '${stats?['total_blocked'] ?? 0}', AppTheme.accentRed, Icons.block_rounded, cardBg, borderColor),
            _buildStatBox('Numéros Blanchis', '${stats?['total_whitelisted'] ?? 0}', AppTheme.accentGreen, Icons.verified_user_rounded, cardBg, borderColor),
            _buildStatBox('Signalements', '${stats?['total_reports'] ?? 0}', AppTheme.primaryColor, Icons.report_problem_rounded, cardBg, borderColor),
            _buildStatBox('Utilisateurs', '${stats?['total_users'] ?? 0}', AppTheme.accentOrange, Icons.people_alt_rounded, cardBg, borderColor),
            _buildStatBox('Avis Légitimes', '${stats?['total_safe_reports'] ?? 0}', Colors.teal, Icons.thumb_up_alt_rounded, cardBg, borderColor),
            _buildStatBox('Auto-Consensus', '${stats?['total_auto_consensus'] ?? 0}', Colors.deepPurpleAccent, Icons.how_to_reg_rounded, cardBg, borderColor),
          ],
        ),
        const SizedBox(height: 24),

        // Maintenance & Purge BDD
        const Text('MAINTENANCE & SÉCURITÉ BDD', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.grey, letterSpacing: 1.1)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: borderColor)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.cleaning_services_rounded, color: AppTheme.accentGreen, size: 22),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Maintenance Automatisée & Consensualité',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text('Purge les signalements obsolètes (>30j) ou lance l\'audit de consensualité pour réhabiliter automatiquement les faux positifs légitimes.', style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 12),
              Consumer(
                builder: (context, ref, _) {
                  final isAdmin = ref.watch(authNotifierProvider)?.isAdmin ?? false;
                  return Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      if (isAdmin)
                        ElevatedButton.icon(
                          icon: const Icon(Icons.auto_delete_outlined, size: 18),
                          label: const Text('Nettoyage BDD'),
                          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentGreen, foregroundColor: Colors.white),
                          onPressed: onPurge,
                        ),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.fact_check_rounded, size: 18),
                        label: const Text('Audit Consensualité'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
                        onPressed: onConsensusAudit,
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Synchronisation
        const Text('SYNCHRONISATION EN TEMPS RÉEL & DELTA SYNC', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.grey, letterSpacing: 1.1)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: borderColor)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.sync_rounded, color: Colors.cyan, size: 22),
                  const SizedBox(width: 8),
                  const Expanded(child: Text('Synchronisation Différentielle Client', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: Colors.cyan.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                    child: Text('v${syncStatus?['total_version'] ?? 1}', style: const TextStyle(color: Colors.cyan, fontWeight: FontWeight.bold, fontSize: 11)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Numéros actifs en production: ${syncStatus?['active_count'] ?? stats?['total_blacklisted'] ?? '—'} • Cache invalidé automatiquement lors des actions admin.',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: isSyncingClient
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.flash_on_rounded, size: 16),
                      label: const Text('Delta Sync', style: TextStyle(fontSize: 12)),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.cyan, foregroundColor: Colors.white),
                      onPressed: isSyncingClient ? null : onDeltaSync,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.cloud_download_rounded, size: 16),
                      label: const Text('Sync Totale', style: TextStyle(fontSize: 12)),
                      onPressed: isSyncingClient ? null : onFullSync,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Diagnostics
        const Text('DIAGNOSTICS TECHNIQUES DE BAS NIVEAU', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.grey, letterSpacing: 1.1)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: borderColor)),
          child: ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: AppTheme.primaryColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.terminal_rounded, color: AppTheme.primaryColor),
            ),
            title: const Text('Diagnostic Pont Kotlin & SQLite', style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: const Text('Vérification CallScreeningService, latence et WAL', style: TextStyle(fontSize: 12)),
            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const DeveloperDiagnosticPage()));
            },
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildStatBox(String label, String value, Color color, IconData icon, Color bg, Color border) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16), border: Border.all(color: border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
              Icon(icon, color: color, size: 20),
            ],
          ),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey)),
        ],
      ),
    );
  }
}
