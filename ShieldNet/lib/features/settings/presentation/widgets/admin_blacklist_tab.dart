import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

/// Onglet de gestion de la liste noire avec recherche, filtres et pagination infinie
class AdminBlacklistTab extends StatelessWidget {
  final List<Map<String, dynamic>> blacklist;
  final bool isLoading;
  final bool hasMore;
  final String currentFilter;
  final TextEditingController searchController;
  final ScrollController scrollController;
  final ValueChanged<String> onFilterChanged;
  final VoidCallback onSearch;
  final VoidCallback onClearSearch;
  final void Function(String phoneHash, String action) onModerate;
  final void Function(String phoneHash) onDelete;

  const AdminBlacklistTab({
    super.key,
    required this.blacklist,
    required this.isLoading,
    required this.hasMore,
    required this.currentFilter,
    required this.searchController,
    required this.scrollController,
    required this.onFilterChanged,
    required this.onSearch,
    required this.onClearSearch,
    required this.onModerate,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = AppTheme.cardBg(isDark);
    final borderColor = AppTheme.borderColor(isDark);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            controller: searchController,
            decoration: InputDecoration(
              hintText: 'Rechercher un numéro ou empreinte...',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: IconButton(
                icon: const Icon(Icons.clear_rounded),
                onPressed: onClearSearch,
              ),
            ),
            onSubmitted: (_) => onSearch(),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              _buildFilterChip('Tous', 'all'),
              const SizedBox(width: 8),
              _buildFilterChip('Bloqués', 'blocked'),
              const SizedBox(width: 8),
              _buildFilterChip('Blanchis', 'whitelisted'),
              const SizedBox(width: 8),
              _buildFilterChip('Auto-Consensus', 'auto_consensus'),
            ],
          ),
        ),
        const Divider(height: 16),
        Expanded(
          child: isLoading
              ? const Center(child: CircularProgressIndicator())
              : blacklist.isEmpty
                  ? const Center(child: Text('Aucun numéro trouvé.', style: TextStyle(color: Colors.grey)))
                  : ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: blacklist.length + (hasMore ? 1 : 0),
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        if (index == blacklist.length) {
                          return const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        return _buildBlacklistItem(blacklist[index], cardBg, borderColor);
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, String value) {
    return FilterChip(
      label: Text(label),
      selected: currentFilter == value,
      onSelected: (_) => onFilterChanged(value),
    );
  }

  Widget _buildBlacklistItem(Map<String, dynamic> item, Color cardBg, Color borderColor) {
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
                ? (isAutoConsensus ? Icons.how_to_reg_rounded : Icons.verified_user_rounded)
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
              onDelete(phoneHash);
            } else {
              onModerate(phoneHash, action);
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
  }
}
