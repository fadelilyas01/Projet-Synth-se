import 'package:shieldnet/core/utils/logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/database/database_helper.dart';
import 'developer_diagnostic_page.dart';

class AdminConsolePage extends ConsumerStatefulWidget {
  const AdminConsolePage({super.key});

  @override
  ConsumerState<AdminConsolePage> createState() => _AdminConsolePageState();
}

class _AdminConsolePageState extends ConsumerState<AdminConsolePage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Données
  bool _isLoadingStats = true;
  Map<String, dynamic>? _stats;

  bool _isLoadingBlacklist = false;
  List<Map<String, dynamic>> _blacklist = [];
  String _blacklistFilter = 'all';
  final _searchBlacklistController = TextEditingController();
  
  // Pagination
  int _blacklistPage = 1;
  bool _hasMoreBlacklist = true;
  bool _isLoadingMoreBlacklist = false;
  final ScrollController _blacklistScrollController = ScrollController();

  bool _isLoadingReports = false;
  List<Map<String, dynamic>> _reports = [];

  bool _isLoadingUsers = false;
  List<Map<String, dynamic>> _users = [];

  bool _isLoadingAuditLogs = false;
  List<Map<String, dynamic>> _auditLogs = [];

  Map<String, dynamic>? _syncStatus;
  bool _isSyncingClient = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _blacklistScrollController.addListener(_onBlacklistScroll);
    _loadAllAdminData();
  }

  void _onBlacklistScroll() {
    if (_blacklistScrollController.position.pixels >= _blacklistScrollController.position.maxScrollExtent - 200) {
      _loadMoreBlacklist();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchBlacklistController.dispose();
    _blacklistScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadAllAdminData() async {
    _loadStats();
    _loadSyncStatus();
    _loadBlacklist();
    _loadReports();
    _loadUsers();
    _loadAuditLogs();
  }

  Future<void> _loadSyncStatus() async {
    try {
      final auth = ref.read(authServiceProvider);
      final status = await auth.getSyncStatus();
      if (mounted) setState(() => _syncStatus = status);
    } catch (e) {
      AppLogger.log('[AdminConsole] Erreur chargement sync status: $e');
    }
  }

  Future<void> _loadAuditLogs() async {
    setState(() => _isLoadingAuditLogs = true);
    try {
      final auth = ref.read(authServiceProvider);
      final logs = await auth.getAdminAuditLogs();
      if (mounted) setState(() { _auditLogs = logs; _isLoadingAuditLogs = false; });
    } catch (e) {
      AppLogger.log('[AdminConsole] Erreur chargement audit logs: $e');
      if (mounted) setState(() => _isLoadingAuditLogs = false);
    }
  }

  Future<void> _triggerManualSync({required bool delta}) async {
    setState(() => _isSyncingClient = true);
    try {
      final api = ref.read(apiServiceProvider);
      final count = await api.syncBlacklistWithBackend(delta: delta);
      await DatabaseHelper.instance.checkpointWAL();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(delta
                ? 'Sync différentielle réussie: $count élément(s) synchronisés/purgés.'
                : 'Sync complète réussie: $count numéros en cache local.'),
            backgroundColor: AppTheme.accentGreen,
          ),
        );
      }
      _loadSyncStatus();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Échec de la synchronisation: $e'), backgroundColor: AppTheme.accentRed),
        );
      }
    } finally {
      if (mounted) setState(() => _isSyncingClient = false);
    }
  }

  Future<void> _loadStats() async {
    setState(() => _isLoadingStats = true);
    try {
      final auth = ref.read(authServiceProvider);
      final stats = await auth.getAdminStats();
      if (mounted) setState(() { _stats = stats; _isLoadingStats = false; });
    } catch (e) {
      AppLogger.log('[AdminConsole] Erreur chargement statistiques: $e');
      if (mounted) setState(() => _isLoadingStats = false);
    }
  }

  Future<void> _loadBlacklist({bool refresh = true}) async {
    if (refresh) {
      setState(() {
        _isLoadingBlacklist = true;
        _blacklistPage = 1;
        _hasMoreBlacklist = true;
        _blacklist.clear();
      });
    }

    try {
      final auth = ref.read(authServiceProvider);
      final list = await auth.getAdminBlacklist(
        query: _searchBlacklistController.text.trim(),
        filter: _blacklistFilter,
        page: _blacklistPage,
        limit: 50,
      );
      
      if (mounted) {
        setState(() {
          if (refresh) {
            _blacklist = list;
          } else {
            _blacklist.addAll(list);
          }
          if (list.length < 50) {
            _hasMoreBlacklist = false;
          }
          _isLoadingBlacklist = false;
          _isLoadingMoreBlacklist = false;
        });
      }
    } catch (e) {
      AppLogger.log('[AdminConsole] Erreur chargement liste noire: $e');
      if (mounted) {
        setState(() {
          _isLoadingBlacklist = false;
          _isLoadingMoreBlacklist = false;
        });
      }
    }
  }

  Future<void> _loadMoreBlacklist() async {
    if (_isLoadingBlacklist || _isLoadingMoreBlacklist || !_hasMoreBlacklist) return;
    setState(() {
      _isLoadingMoreBlacklist = true;
      _blacklistPage++;
    });
    await _loadBlacklist(refresh: false);
  }

  Future<void> _loadReports() async {
    setState(() => _isLoadingReports = true);
    try {
      final auth = ref.read(authServiceProvider);
      final reports = await auth.getAdminReports();
      if (mounted) setState(() { _reports = reports; _isLoadingReports = false; });
    } catch (e) {
      AppLogger.log('[AdminConsole] Erreur chargement signalements: $e');
      if (mounted) setState(() => _isLoadingReports = false);
    }
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoadingUsers = true);
    try {
      final auth = ref.read(authServiceProvider);
      final users = await auth.getAdminUsers();
      if (mounted) setState(() { _users = users; _isLoadingUsers = false; });
    } catch (e) {
      AppLogger.log('[AdminConsole] Erreur chargement utilisateurs: $e');
      if (mounted) setState(() => _isLoadingUsers = false);
    }
  }

  Future<void> _moderate(String phoneHash, String action) async {
    try {
      final auth = ref.read(authServiceProvider);
      final msg = await auth.moderateNumber(phoneHash: phoneHash, action: action);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: action == 'whitelist' ? AppTheme.accentGreen : AppTheme.accentRed),
        );
        _loadStats();
        _loadBlacklist();
        _loadReports();
        _loadAuditLogs();
        _loadSyncStatus();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: AppTheme.accentRed),
        );
      }
    }
  }

  Future<void> _deleteNumber(String phoneHash) async {
    try {
      final auth = ref.read(authServiceProvider);
      await auth.deleteAdminBlacklistNumber(phoneHash);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Numéro supprimé de la liste noire.'), backgroundColor: AppTheme.accentGreen),
        );
        _loadStats();
        _loadBlacklist();
        _loadAuditLogs();
        _loadSyncStatus();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: AppTheme.accentRed),
        );
      }
    }
  }

  Future<void> _deleteReport(String reportId) async {
    try {
      final auth = ref.read(authServiceProvider);
      await auth.deleteAdminReport(reportId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Signalement supprimé.'), backgroundColor: AppTheme.accentGreen),
        );
        _loadStats();
        _loadReports();
        _loadAuditLogs();
        _loadSyncStatus();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: AppTheme.accentRed),
        );
      }
    }
  }

  Future<void> _purgeJunk() async {
    try {
      final auth = ref.read(authServiceProvider);
      final res = await auth.purgeDatabase();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['detail'] as String? ?? 'Nettoyage terminé.'), backgroundColor: AppTheme.accentGreen),
        );
        _loadAllAdminData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: AppTheme.accentRed),
        );
      }
    }
  }

  Future<void> _runConsensusAudit() async {
    try {
      final auth = ref.read(authServiceProvider);
      final res = await auth.runConsensusAudit();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['detail'] as String? ?? 'Audit de consensualité terminé.'),
            backgroundColor: AppTheme.accentGreen,
          ),
        );
        _loadAllAdminData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: AppTheme.accentRed),
        );
      }
    }
  }

  void _showAddNumberDialog() {
    final phoneController = TextEditingController();
    String category = 'fraud';
    int riskScore = 80;
    bool isBlocked = true;
    bool isWhitelisted = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.add_moderator_rounded, color: AppTheme.accentOrange),
              SizedBox(width: 8),
              Expanded(
                child: Text('Ajouter un Numéro', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Numéro de téléphone',
                    hintText: '+1 819 123 4567',
                    prefixIcon: Icon(Icons.phone_rounded),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: category,
                  decoration: const InputDecoration(labelText: 'Catégorie'),
                  items: const [
                    DropdownMenuItem(value: 'fraud', child: Text('Fraude / Arnaque')),
                    DropdownMenuItem(value: 'financial_scam', child: Text('Arnaque Financière')),
                    DropdownMenuItem(value: 'phishing', child: Text('Hameçonnage / Phishing')),
                    DropdownMenuItem(value: 'robocall', child: Text('Robocall Automatisé')),
                    DropdownMenuItem(value: 'telemarketing', child: Text('Démarchage Commercial')),
                    DropdownMenuItem(value: 'other', child: Text('Autre Nuisance')),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => category = val);
                  },
                ),
                const SizedBox(height: 16),
                Text('Score de Risque : $riskScore/100', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                Slider(
                  value: riskScore.toDouble(),
                  min: 0,
                  max: 100,
                  divisions: 20,
                  label: '$riskScore',
                  onChanged: (val) => setDialogState(() => riskScore = val.toInt()),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Bloquer immédiatement', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  value: isBlocked,
                  onChanged: (val) => setDialogState(() {
                    isBlocked = val;
                    if (val) isWhitelisted = false;
                  }),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Blanchir (Faux positif)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  value: isWhitelisted,
                  onChanged: (val) => setDialogState(() {
                    isWhitelisted = val;
                    if (val) isBlocked = false;
                  }),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () async {
                final phone = phoneController.text.trim();
                if (phone.isEmpty) return;
                final messenger = ScaffoldMessenger.of(context);
                Navigator.pop(ctx);
                try {
                  final auth = ref.read(authServiceProvider);
                  await auth.addAdminBlacklistNumber(
                    phoneNumber: phone,
                    category: category,
                    riskScore: riskScore,
                    isBlocked: isBlocked,
                    isWhitelisted: isWhitelisted,
                  );
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Numéro enregistré avec succès.'), backgroundColor: AppTheme.accentGreen),
                  );
                  _loadAllAdminData();
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(content: Text('Erreur: $e'), backgroundColor: AppTheme.accentRed),
                  );
                }
              },
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = AppTheme.cardBg(isDark);
    final borderColor = AppTheme.borderColor(isDark);

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.admin_panel_settings_rounded, color: AppTheme.accentOrange),
            SizedBox(width: 8),
            Text('Administration Totale', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Tout actualiser',
            onPressed: _loadAllAdminData,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: AppTheme.accentOrange,
          unselectedLabelColor: Colors.grey,
          indicatorColor: AppTheme.accentOrange,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard_rounded), text: 'Vue d\'ensemble'),
            Tab(icon: Icon(Icons.format_list_bulleted_rounded), text: 'Liste Noire'),
            Tab(icon: Icon(Icons.report_problem_rounded), text: 'Signalements'),
            Tab(icon: Icon(Icons.people_alt_rounded), text: 'Utilisateurs'),
            Tab(icon: Icon(Icons.history_rounded), text: 'Audit & Traces'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // 1. VUE D'ENSEMBLE & ACTIONS
          _buildOverviewTab(cardBg, borderColor, isDark),

          // 2. GESTION DE LA LISTE NOIRE
          _buildBlacklistTab(cardBg, borderColor),

          // 3. SIGNALEMENTS & MODÉRATION
          _buildReportsTab(cardBg, borderColor),

          // 4. GESTION DES UTILISATEURS
          _buildUsersTab(cardBg, borderColor),

          // 5. JOURNAL D'AUDIT ET TRAÇABILITÉ WEB/MOBILE
          _buildAuditLogsTab(cardBg, borderColor),
        ],
      ),
      floatingActionButton: _tabController.index == 1
          ? FloatingActionButton.extended(
              backgroundColor: AppTheme.accentOrange,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Ajouter un Numéro'),
              onPressed: _showAddNumberDialog,
            )
          : null,
    );
  }

  // ======================== TAB 1: OVERVIEW ========================
  Widget _buildOverviewTab(Color cardBg, Color borderColor, bool isDark) {
    if (_isLoadingStats) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Carte d'accès Admin Unifié
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: AppTheme.brandGradient,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Row(
            children: [
              Icon(Icons.shield_rounded, color: Colors.white, size: 36),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Contrôle Administrateur Total', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    SizedBox(height: 2),
                    Text('Connecté en tant que admin@shieldnet.app avec privilèges complets (Web & Mobile).', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
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
            _buildStatBox('Numéros Bloqués', '${_stats?['total_blocked'] ?? 0}', AppTheme.accentRed, Icons.block_rounded, cardBg, borderColor),
            _buildStatBox('Numéros Blanchis', '${_stats?['total_whitelisted'] ?? 0}', AppTheme.accentGreen, Icons.verified_user_rounded, cardBg, borderColor),
            _buildStatBox('Signalements', '${_stats?['total_reports'] ?? 0}', AppTheme.primaryColor, Icons.report_problem_rounded, cardBg, borderColor),
            _buildStatBox('Utilisateurs', '${_stats?['total_users'] ?? 0}', AppTheme.accentOrange, Icons.people_alt_rounded, cardBg, borderColor),
            _buildStatBox('Avis Légitimes', '${_stats?['total_safe_reports'] ?? 0}', Colors.teal, Icons.thumb_up_alt_rounded, cardBg, borderColor),
            _buildStatBox('Auto-Consensus', '${_stats?['total_auto_consensus'] ?? 0}', Colors.deepPurpleAccent, Icons.auto_awesome_rounded, cardBg, borderColor),
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
                  Text('Maintenance Automatisée & Consensualité', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ],
              ),
              const SizedBox(height: 6),
              const Text('Purge les signalements obsolètes (>30j) ou lance l\'audit de consensualité pour réhabiliter automatiquement les faux positifs légitimes.', style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.auto_delete_outlined, size: 18),
                    label: const Text('Nettoyage BDD'),
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentGreen, foregroundColor: Colors.white),
                    onPressed: _purgeJunk,
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                    label: const Text('Audit Consensualité'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
                    onPressed: _runConsensusAudit,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Synchronisation Client-Serveur & Invalidation
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
                  const Expanded(
                    child: Text('Synchronisation Différentielle Client', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.cyan.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'v${_syncStatus?['total_version'] ?? 1}',
                      style: const TextStyle(color: Colors.cyan, fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Numéros actifs en production: ${_syncStatus?['active_count'] ?? _stats?['total_blacklisted'] ?? '—'} • Cache invalidé automatiquement lors des actions admin.',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: _isSyncingClient
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.flash_on_rounded, size: 16),
                      label: const Text('Delta Sync', style: TextStyle(fontSize: 12)),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.cyan, foregroundColor: Colors.white),
                      onPressed: _isSyncingClient ? null : () => _triggerManualSync(delta: true),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.cloud_download_rounded, size: 16),
                      label: const Text('Sync Totale', style: TextStyle(fontSize: 12)),
                      onPressed: _isSyncingClient ? null : () => _triggerManualSync(delta: false),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Outils Système & Diagnostic Kotlin
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

  // ======================== TAB 2: BLACKLIST ========================
  Widget _buildBlacklistTab(Color cardBg, Color borderColor) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            controller: _searchBlacklistController,
            decoration: InputDecoration(
              hintText: 'Rechercher un numéro ou empreinte...',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: IconButton(
                icon: const Icon(Icons.clear_rounded),
                onPressed: () {
                  _searchBlacklistController.clear();
                  _loadBlacklist();
                },
              ),
            ),
            onSubmitted: (_) => _loadBlacklist(),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              FilterChip(
                label: const Text('Tous'),
                selected: _blacklistFilter == 'all',
                onSelected: (val) { setState(() => _blacklistFilter = 'all'); _loadBlacklist(); },
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: const Text('Bloqués'),
                selected: _blacklistFilter == 'blocked',
                onSelected: (val) { setState(() => _blacklistFilter = 'blocked'); _loadBlacklist(); },
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: const Text('Blanchis'),
                selected: _blacklistFilter == 'whitelisted',
                onSelected: (val) { setState(() => _blacklistFilter = 'whitelisted'); _loadBlacklist(); },
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: const Text('Auto-Consensus'),
                selected: _blacklistFilter == 'auto_consensus',
                onSelected: (val) { setState(() => _blacklistFilter = 'auto_consensus'); _loadBlacklist(); },
              ),
            ],
          ),
        ),
        const Divider(height: 16),
        Expanded(
          child: _isLoadingBlacklist
              ? const Center(child: CircularProgressIndicator())
              : _blacklist.isEmpty
                  ? const Center(child: Text('Aucun numéro trouvé.', style: TextStyle(color: Colors.grey)))
                  : ListView.separated(
                      controller: _blacklistScrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: _blacklist.length + (_hasMoreBlacklist ? 1 : 0),
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        if (index == _blacklist.length) {
                          return const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        final item = _blacklist[index];
                        final masked = item['masked_number'] as String? ?? 'Numéro masqué';
                        final phoneHash = item['phone_hash'] as String? ?? '';
                        final category = item['category'] as String? ?? 'fraud';
                        final riskScore = item['risk_score'] as int? ?? 0;
                        final isWhitelisted = item['is_whitelisted'] as bool? ?? false;
                        final isBlocked = item['is_blocked'] as bool? ?? true;
                        final whitelistReason = item['whitelist_reason'] as String? ?? '';
                        final isAutoConsensus = whitelistReason == 'auto_consensus';
                        final safeCount = item['safe_reports_count'] as int? ?? 0;

                        return Container(
                          decoration: BoxDecoration(color: cardBg, border: Border.all(color: borderColor)),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: isWhitelisted
                                  ? (isAutoConsensus ? Colors.deepPurple.withValues(alpha: 0.15) : AppTheme.accentGreen.withValues(alpha: 0.1))
                                  : AppTheme.accentRed.withValues(alpha: 0.1),
                              child: Icon(
                                isWhitelisted
                                    ? (isAutoConsensus ? Icons.auto_awesome_rounded : Icons.verified_user_rounded)
                                    : Icons.block_rounded,
                                color: isWhitelisted
                                    ? (isAutoConsensus ? Colors.deepPurpleAccent : AppTheme.accentGreen)
                                    : AppTheme.accentRed,
                              ),
                            ),
                            title: Row(
                              children: [
                                Expanded(child: Text(masked, style: const TextStyle(fontWeight: FontWeight.bold))),
                                if (isAutoConsensus)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.deepPurple.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: Colors.deepPurpleAccent, width: 0.8),
                                    ),
                                    child: const Text('Auto-Consensus', style: TextStyle(color: Colors.deepPurpleAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                                  ),
                              ],
                            ),
                            subtitle: Text(
                              'Score: $riskScore/100 • $category${safeCount > 0 ? ' • $safeCount avis légitime(s)' : ''}\nHash: ${phoneHash.length >= 12 ? phoneHash.substring(0, 12) : phoneHash}...',
                              style: const TextStyle(fontSize: 11),
                            ),
                            isThreeLine: true,
                            trailing: PopupMenuButton<String>(
                              onSelected: (action) {
                                if (action == 'delete') {
                                  _deleteNumber(phoneHash);
                                } else {
                                  _moderate(phoneHash, action);
                                }
                              },
                              itemBuilder: (ctx) => [
                                if (!isWhitelisted)
                                  const PopupMenuItem(value: 'whitelist', child: Text('Blanchir (Whitelist)')),
                                if (!isBlocked)
                                  const PopupMenuItem(value: 'block', child: Text('Bloquer')),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Supprimer de la base', style: TextStyle(color: AppTheme.accentRed)),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  // ======================== TAB 3: REPORTS ========================
  Widget _buildReportsTab(Color cardBg, Color borderColor) {
    if (_isLoadingReports) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_reports.isEmpty) {
      return const Center(child: Text('Aucun signalement utilisateur.', style: TextStyle(color: Colors.grey)));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _reports.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final r = _reports[index];
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
                    onPressed: () => _moderate(phoneHash, 'whitelist'),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    icon: const Icon(Icons.block, size: 16, color: AppTheme.accentRed),
                    label: const Text('Bloquer', style: TextStyle(color: AppTheme.accentRed, fontSize: 12)),
                    onPressed: () => _moderate(phoneHash, 'block'),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18, color: Colors.grey),
                    tooltip: 'Supprimer ce signalement',
                    onPressed: () => _deleteReport(id),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ======================== TAB 4: USERS ========================
  Widget _buildUsersTab(Color cardBg, Color borderColor) {
    if (_isLoadingUsers) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_users.isEmpty) {
      return const Center(child: Text('Aucun utilisateur enregistré.', style: TextStyle(color: Colors.grey)));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _users.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final u = _users[index];
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

  // ======================== TAB 5: AUDIT LOGS ========================
  Widget _buildAuditLogsTab(Color cardBg, Color borderColor) {
    if (_isLoadingAuditLogs) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_auditLogs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history_toggle_off_rounded, size: 64, color: Colors.grey.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            const Text('Aucun événement d\'audit enregistré.', style: TextStyle(color: Colors.grey, fontSize: 16)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAuditLogs,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _auditLogs.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final log = _auditLogs[index];
          final action = log['action'] as String? ?? '';
          final source = log['source'] as String? ?? 'web';
          final username = log['user_username'] as String? ?? 'Système';
          final targetHash = log['target_hash'] as String? ?? '';
          final createdAt = log['created_at'] as String? ?? '';
          final details = log['details'];

          Color actionColor = AppTheme.primaryColor;
          IconData actionIcon = Icons.info_outline_rounded;
          String actionLabel = action;

          if (action.contains('BLOCK') && !action.contains('UNBLOCK')) {
            actionColor = AppTheme.accentRed;
            actionIcon = Icons.block_rounded;
            actionLabel = 'Blocage de numéro';
          } else if (action.contains('UNBLOCK') || action.contains('WHITELIST')) {
            actionColor = AppTheme.accentGreen;
            actionIcon = Icons.check_circle_outline_rounded;
            actionLabel = 'Déblocage / Blanchiment';
          } else if (action.contains('PURGE')) {
            actionColor = Colors.purple;
            actionIcon = Icons.auto_delete_rounded;
            actionLabel = 'Purge Maintenance BDD';
          } else if (action.contains('APPROVE')) {
            actionColor = AppTheme.accentOrange;
            actionIcon = Icons.verified_user_rounded;
            actionLabel = 'Signalement Validé';
          } else if (action.contains('REJECT')) {
            actionColor = Colors.grey;
            actionIcon = Icons.cancel_outlined;
            actionLabel = 'Signalement Rejeté';
          }

          final isWeb = source.toLowerCase() == 'web';

          return Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: actionColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(actionIcon, color: actionColor, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              actionLabel,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: actionColor,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Par $username • ${createdAt.length > 19 ? createdAt.substring(0, 19).replaceAll("T", " ") : createdAt}',
                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isWeb ? Colors.blue.withValues(alpha: 0.12) : AppTheme.accentOrange.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isWeb ? Icons.language_rounded : Icons.smartphone_rounded,
                              size: 13,
                              color: isWeb ? Colors.blue : AppTheme.accentOrange,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isWeb ? 'WEB ADMIN' : 'MOBILE APP',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isWeb ? Colors.blue : AppTheme.accentOrange,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (targetHash.isNotEmpty || (details != null && details.toString() != '{}')) ...[
                    const SizedBox(height: 8),
                    const Divider(height: 1),
                    const SizedBox(height: 8),
                    if (targetHash.isNotEmpty)
                      Text(
                        'Cible (Hash): ${targetHash.length > 16 ? "${targetHash.substring(0, 16)}..." : targetHash}',
                        style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Colors.grey),
                      ),
                    if (details != null && details.toString() != '{}')
                      Text(
                        'Détails: $details',
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
