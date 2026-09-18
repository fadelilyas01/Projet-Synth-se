import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:call_log/call_log.dart' as call_log;
import 'package:intl/intl.dart';

import '../../../../core/security/crypto_utils.dart';
import '../../../../core/utils/logger.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../core/services/citizen_impact_service.dart';
import '../controllers/blacklist_controller.dart';
import '../../domain/entities/blacklisted_entry.dart';

class ActivityPage extends ConsumerStatefulWidget {
  const ActivityPage({super.key});

  @override
  ConsumerState<ActivityPage> createState() => _ActivityPageState();
}

class _ActivityPageState extends ConsumerState<ActivityPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<call_log.CallLogEntry> _recentCalls = [];
  bool _isLoadingCalls = true;
  String _searchFilter = '';

  String _formatRelativeTime(int? timestampMs, AppLocalizations? l10n) {
    if (timestampMs == null || timestampMs <= 0) return '';
    final date = DateTime.fromMillisecondsSinceEpoch(timestampMs);
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) {
      return l10n?.timeJustNow ?? 'À l\'instant';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m';
    } else if (diff.inHours < 24 && date.day == now.day) {
      final prefix = l10n?.timeTodayAt ?? 'Aujourd\'hui à';
      return '$prefix ${DateFormat('HH:mm').format(date)}';
    } else if (diff.inDays < 2 && date.day == now.subtract(const Duration(days: 1)).day) {
      final prefix = l10n?.timeYesterdayAt ?? 'Hier à';
      return '$prefix ${DateFormat('HH:mm').format(date)}';
    } else {
      return DateFormat('dd/MM HH:mm').format(date);
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadCallHistory();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadCallHistory() async {
    setState(() => _isLoadingCalls = true);
    try {
      final entries = await call_log.CallLog.get();
      if (mounted) {
        setState(() {
          _recentCalls = entries.take(50).toList();
          _isLoadingCalls = false;
        });
      }
    } catch (e) {
      AppLogger.log('[ActivityPage] Erreur chargement journal d\'appels: $e');
      if (mounted) setState(() => _isLoadingCalls = false);
    }
  }

  void _showOneTapReportModal(BuildContext context, String rawNumber) {
    String selectedCategory = 'fraud';
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final l10n = AppLocalizations.of(context);
          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        l10n?.blockAndReport ?? 'Bloquer & Signaler',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  CryptoUtils.maskPhoneNumber(rawNumber),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.accentRed),
                ),
                const SizedBox(height: 16),
                Text(l10n?.reportReason ?? 'Motif du signalement :', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildChoiceChip(l10n?.categoryScam ?? 'Arnaque', 'fraud', selectedCategory, (cat) => setModalState(() => selectedCategory = cat)),
                    _buildChoiceChip(l10n?.categoryTelemarketing ?? 'Démarchage', 'telemarketing', selectedCategory, (cat) => setModalState(() => selectedCategory = cat)),
                    _buildChoiceChip(l10n?.categoryPhishing ?? 'Phishing', 'phishing', selectedCategory, (cat) => setModalState(() => selectedCategory = cat)),
                    _buildChoiceChip(l10n?.categoryRobocall ?? 'Automate / Silence', 'robocall', selectedCategory, (cat) => setModalState(() => selectedCategory = cat)),
                  ],
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          setModalState(() => isSubmitting = true);
                          final messenger = ScaffoldMessenger.of(context);
                          final navigator = Navigator.of(ctx);
                          final reportUseCase = ref.read(reportSpamUseCaseProvider);
                          final result = await reportUseCase(
                            rawPhoneNumber: rawNumber,
                            category: selectedCategory,
                          );

                          navigator.pop();
                          result.fold(
                            (failure) {
                              messenger.showSnackBar(
                                SnackBar(content: Text(failure.message), backgroundColor: AppTheme.accentRed),
                              );
                            },
                            (_) async {
                              await CitizenImpactService.incrementReportsCount();
                              ref.read(blacklistControllerProvider.notifier).loadBlacklist();
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(l10n?.reportSuccessMessage ?? 'Numéro bloqué et signalé avec succès.'),
                                  backgroundColor: AppTheme.accentGreen,
                                ),
                              );
                            },
                          );
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentRed,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: isSubmitting
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(l10n?.btnBlockThisNumber ?? 'Bloquer ce numéro', style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildChoiceChip(String label, String value, String current, ValueChanged<String> onSelected) {
    final selected = current == value;
    return ChoiceChip(
      label: Text(label, style: TextStyle(color: selected ? Colors.white : null, fontSize: 12)),
      selected: selected,
      selectedColor: AppTheme.accentRed,
      onSelected: (_) => onSelected(value),
    );
  }

  @override
  Widget build(BuildContext context) {
    final blacklistAsync = ref.watch(blacklistControllerProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = AppTheme.cardBg(isDark);
    final borderColor = AppTheme.borderColor(isDark);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n?.activityTitle ?? 'Activité Téléphonique', style: const TextStyle(fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Theme.of(context).primaryColor,
          tabs: [
            Tab(text: l10n?.tabRecentCalls ?? 'Appels Récents'),
            Tab(text: l10n?.tabBlockedNumbers ?? 'Numéros Bloqués'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // TAB 1: HISTORIQUE DES APPELS
          _buildCallsTab(blacklistAsync.value ?? [], cardBg, borderColor, l10n),

          // TAB 2: NUMÉROS BLOQUÉS
          _buildBlockedListTab(blacklistAsync, cardBg, borderColor, isDark, l10n),
        ],
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'fraud':
      case 'arnaque':
        return AppTheme.accentRed;
      case 'telemarketing':
      case 'démarchage':
        return AppTheme.accentOrange;
      case 'phishing':
        return const Color(0xFFDC2626);
      case 'robocall':
      case 'automate':
        return AppTheme.primaryDarkColor;
      default:
        return AppTheme.primaryColor;
    }
  }

  Widget _buildCallsTab(List<BlacklistedEntry> blockedList, Color cardBg, Color borderColor, AppLocalizations? l10n) {
    if (_isLoadingCalls) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_recentCalls.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.phone_paused_rounded, size: 48, color: AppTheme.primaryColor),
              ),
              const SizedBox(height: 18),
              Text(
                l10n?.noRecentCalls ?? 'Aucun appel récent',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                l10n?.noRecentCallsDesc ?? 'Les appels récents s\'afficheront ici avec leur état de sécurité.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey, fontSize: 13, height: 1.4),
              ),
            ],
          ),
        ),
      );
    }

    final blockedHashes = blockedList.map((b) => b.phoneHash).toSet();

    return RefreshIndicator(
      onRefresh: _loadCallHistory,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        itemCount: _recentCalls.length,
        separatorBuilder: (context, index) => const SizedBox(height: 10),
        itemBuilder: (ctx, index) {
          final call = _recentCalls[index];
          final rawNum = call.number ?? '';
          final hash = rawNum.isNotEmpty ? CryptoUtils.hashPhoneNumber(rawNum) : '';
          final isBlocked = blockedHashes.contains(hash);
          final dateStr = _formatRelativeTime(call.timestamp, l10n);

          final defaultUnknown = l10n?.unknownCaller ?? 'Inconnu';
          final titleText = call.name?.isNotEmpty == true ? call.name! : (rawNum.isNotEmpty ? CryptoUtils.maskPhoneNumber(rawNum) : defaultUnknown);
          final statusDesc = isBlocked ? (l10n?.spamBlocked ?? 'Spam bloqué') : (l10n?.incomingCall ?? 'Appel entrant');

          final itemWidget = Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isBlocked ? AppTheme.accentRed.withValues(alpha: 0.1) : AppTheme.accentGreen.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isBlocked ? Icons.call_end_rounded : Icons.call_received_rounded,
                  color: isBlocked ? AppTheme.accentRed : AppTheme.accentGreen,
                  size: 20,
                ),
              ),
              title: Text(
                titleText,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                '$dateStr • $statusDesc',
                style: TextStyle(fontSize: 12, color: isBlocked ? AppTheme.accentRed : Colors.grey),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: isBlocked
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.accentRed.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(l10n?.badgeBlocked ?? 'Bloqué', style: const TextStyle(color: AppTheme.accentRed, fontWeight: FontWeight.bold, fontSize: 11)),
                    )
                  : IconButton(
                      icon: const Icon(Icons.shield_outlined, color: AppTheme.accentRed, size: 20),
                      tooltip: l10n?.btnBlockThisNumber ?? 'Bloquer ce numéro',
                      onPressed: rawNum.isNotEmpty
                          ? () {
                              HapticFeedback.lightImpact();
                              _showOneTapReportModal(context, rawNum);
                            }
                          : null,
                    ),
            ),
          );

          if (isBlocked || rawNum.isEmpty) {
            return itemWidget;
          }

          return Dismissible(
            key: ValueKey('call_${call.timestamp}_$index'),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: AppTheme.accentRed,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.shield_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(l10n?.blockAndReport ?? 'Bloquer & Signaler', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                ],
              ),
            ),
            confirmDismiss: (direction) async {
              HapticFeedback.mediumImpact();
              _showOneTapReportModal(context, rawNum);
              return false;
            },
            child: itemWidget,
          );
        },
      ),
    );
  }

  Widget _buildBlockedListTab(AsyncValue<List<BlacklistedEntry>> blacklistAsync, Color cardBg, Color borderColor, bool isDark, AppLocalizations? l10n) {
    return blacklistAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Erreur: $err')),
      data: (entries) {
        final filtered = entries.where((e) {
          if (_searchFilter.isEmpty) return true;
          return e.maskedNumber.toLowerCase().contains(_searchFilter) ||
              e.category.toLowerCase().contains(_searchFilter);
        }).toList();

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
              child: TextField(
                onChanged: (val) => setState(() => _searchFilter = val.trim().toLowerCase()),
                decoration: InputDecoration(
                  hintText: l10n?.searchBlockedPlaceholder ?? 'Rechercher un numéro bloqué...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: AppTheme.accentGreen.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.verified_user_rounded, size: 48, color: AppTheme.accentGreen),
                            ),
                            const SizedBox(height: 18),
                            Text(
                              _searchFilter.isEmpty
                                  ? (l10n?.noBlockedNumbers ?? 'Aucun numéro bloqué')
                                  : (l10n?.noResultsFound ?? 'Aucun résultat trouvé'),
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _searchFilter.isEmpty
                                  ? (l10n?.noBlockedNumbersDesc ?? 'Tous les numéros signalés ou bloqués par le filtre automatique apparaîtront ici.')
                                  : (l10n?.tryAnotherSearch ?? 'Essayez avec un autre terme de recherche.'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.grey, fontSize: 13, height: 1.4),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: filtered.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 8),
                      itemBuilder: (ctx, index) {
                        final item = filtered[index];
                        final catColor = _getCategoryColor(item.category);
                        return Container(
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: borderColor),
                          ),
                          child: ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: catColor.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.block_rounded, color: catColor, size: 18),
                            ),
                            title: Text(
                              item.maskedNumber.isNotEmpty ? item.maskedNumber : (l10n?.maskedNumberDefault ?? 'Numéro masqué'),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Row(
                              children: [
                                Container(
                                  margin: const EdgeInsets.only(top: 4),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: catColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    item.category.toUpperCase(),
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: catColor),
                                  ),
                                ),
                              ],
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.accentRed.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${item.riskScore}% ${l10n?.riskWord ?? "risque"}',
                                style: const TextStyle(color: AppTheme.accentRed, fontWeight: FontWeight.bold, fontSize: 11),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}
