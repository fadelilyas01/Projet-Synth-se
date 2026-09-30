import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/regional_compliance_service.dart';

/// Onglet de gestion et de localisation des utilisateurs inscrits (Web & Mobile)
class AdminUsersTab extends StatefulWidget {
  final List<Map<String, dynamic>> users;
  final bool isLoading;

  const AdminUsersTab({
    super.key,
    required this.users,
    required this.isLoading,
  });

  @override
  State<AdminUsersTab> createState() => _AdminUsersTabState();
}

class _AdminUsersTabState extends State<AdminUsersTab> {
  String _searchQuery = '';
  String _countryFilter = 'ALL'; // 'ALL', 'CA', 'US'
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = AppTheme.cardBg(isDark);
    final borderColor = AppTheme.borderColor(isDark);

    if (widget.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (widget.users.isEmpty) {
      return const Center(
        child: Text('Aucun utilisateur enregistré.', style: TextStyle(color: Colors.grey)),
      );
    }

    // Statistiques par pays
    final caCount = widget.users.where((u) => (u['country'] as String? ?? 'CA').toUpperCase() == 'CA').length;
    final usCount = widget.users.where((u) => (u['country'] as String? ?? 'CA').toUpperCase() == 'US').length;

    // Filtrage dynamique
    final filteredUsers = widget.users.where((u) {
      final country = (u['country'] as String? ?? 'CA').toUpperCase();
      if (_countryFilter != 'ALL' && country != _countryFilter) {
        return false;
      }

      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final email = (u['email'] as String? ?? '').toLowerCase();
        final name = (u['name'] as String? ?? '').toLowerCase();
        final prov = (u['province_or_state'] as String? ?? '').toLowerCase();
        final provName = (u['province_name'] as String? ?? '').toLowerCase();
        final norm = ((u['compliance_norm'] as Map<String, dynamic>?)?['norm_name'] as String? ?? '').toLowerCase();

        return email.contains(q) || name.contains(q) || prov.contains(q) || provName.contains(q) || norm.contains(q);
      }
      return true;
    }).toList();

    return Column(
      children: [
        // Barre de recherche et de filtres géographiques
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          decoration: BoxDecoration(
            color: cardBg,
            border: Border(bottom: BorderSide(color: borderColor)),
          ),
          child: Column(
            children: [
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Rechercher par nom, email, province (QC, ON, NY...)...',
                  hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: borderColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: borderColor),
                  ),
                ),
                onChanged: (val) => setState(() => _searchQuery = val.trim()),
              ),
              const SizedBox(height: 10),
              // Puces de filtres par pays
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip(
                      label: 'Tous (${widget.users.length})',
                      isSelected: _countryFilter == 'ALL',
                      onTap: () => setState(() => _countryFilter = 'ALL'),
                      isDark: isDark,
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      label: '🇨🇦 Canada ($caCount)',
                      isSelected: _countryFilter == 'CA',
                      onTap: () => setState(() => _countryFilter = 'CA'),
                      isDark: isDark,
                      activeColor: const Color(0xFF0284C7),
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      label: '🇺🇸 États-Unis ($usCount)',
                      isSelected: _countryFilter == 'US',
                      onTap: () => setState(() => _countryFilter = 'US'),
                      isDark: isDark,
                      activeColor: const Color(0xFF10B981),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Liste des utilisateurs
        Expanded(
          child: filteredUsers.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.person_search_rounded, size: 48, color: Colors.grey),
                        const SizedBox(height: 12),
                        const Text('Aucun utilisateur ne correspond à ces critères.', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(
                          'Filtre actif : $_countryFilter${_searchQuery.isNotEmpty ? " • '$_searchQuery'" : ""}',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredUsers.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final u = filteredUsers[index];
                    final email = u['email'] as String? ?? 'Sans email';
                    final name = u['name'] as String? ?? '';
                    final isStaff = u['is_staff'] as bool? ?? false;
                    final isSuperuser = u['is_superuser'] as bool? ?? false;
                    final reportsCount = u['reports_count'] as int? ?? 0;

                    final country = (u['country'] as String? ?? 'CA').toUpperCase();
                    final prov = (u['province_or_state'] as String? ?? 'QC').toUpperCase();
                    final flag = country == 'CA' ? '🇨🇦' : '🇺🇸';
                    final countryName = u['country_name'] as String? ?? (country == 'CA' ? 'Canada' : 'États-Unis');
                    final provName = u['province_name'] as String? ??
                        (country == 'CA'
                            ? (RegionalComplianceManager.canadianProvinces[prov] ?? prov)
                            : (RegionalComplianceManager.usStates[prov] ?? prov));

                    final normMap = u['compliance_norm'] as Map<String, dynamic>? ??
                        RegionalComplianceManager.getLocalNorm(country, prov);
                    final normKey = normMap['norm_key'] as String? ?? (prov == 'QC' ? 'LOI_25_QC' : 'PIPEDA');
                    final normName = normMap['norm_name'] as String? ?? 'Norme régionale';

                    return Container(
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: borderColor),
                      ),
                      child: InkWell(
                        onTap: () => _showUserDetailsModal(context, u, countryName, provName, flag, normMap),
                        borderRadius: BorderRadius.circular(14),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: isSuperuser
                                        ? AppTheme.accentOrange.withValues(alpha: 0.15)
                                        : (isStaff
                                            ? AppTheme.primaryColor.withValues(alpha: 0.15)
                                            : Colors.grey.withValues(alpha: 0.15)),
                                    child: Icon(
                                      isSuperuser
                                          ? Icons.security_rounded
                                          : (isStaff ? Icons.admin_panel_settings_rounded : Icons.person_rounded),
                                      size: 18,
                                      color: isSuperuser
                                          ? AppTheme.accentOrange
                                          : (isStaff ? AppTheme.primaryColor : Colors.grey),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name.isNotEmpty ? name : email.split('@')[0],
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                        ),
                                        Text(
                                          email,
                                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Badge de rôle
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: isSuperuser
                                          ? AppTheme.accentOrange.withValues(alpha: 0.15)
                                          : (isStaff
                                              ? AppTheme.primaryColor.withValues(alpha: 0.15)
                                              : AppTheme.accentGreen.withValues(alpha: 0.15)),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      isSuperuser ? 'ADMIN' : (isStaff ? 'GESTIONNAIRE' : 'CITOYEN'),
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: isSuperuser
                                            ? AppTheme.accentOrange
                                            : (isStaff ? AppTheme.primaryColor : AppTheme.accentGreen),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              const Divider(height: 1),
                              const SizedBox(height: 10),
                              // Ligne régionale : Pays, Province et Norme Juridique
                              Row(
                                children: [
                                  // Drapeau & Région
                                  Flexible(
                                    flex: 3,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: country == 'CA'
                                            ? const Color(0xFF0284C7).withValues(alpha: 0.1)
                                            : const Color(0xFF10B981).withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: country == 'CA'
                                              ? const Color(0xFF0284C7).withValues(alpha: 0.3)
                                              : const Color(0xFF10B981).withValues(alpha: 0.3),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(flag, style: const TextStyle(fontSize: 14)),
                                          const SizedBox(width: 5),
                                          Flexible(
                                            child: Text(
                                              '$provName ($prov)',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: country == 'CA' ? const Color(0xFF0284C7) : const Color(0xFF10B981),
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Norme juridique
                                  Flexible(
                                    flex: 2,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.deepPurple.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: Colors.deepPurple.withValues(alpha: 0.3)),
                                      ),
                                      child: Text(
                                        normKey == 'LOI_25_QC' ? 'Loi 25 (QC)' : normName,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.deepPurpleAccent,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '$reportsCount sig.',
                                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
    Color? activeColor,
  }) {
    final col = activeColor ?? AppTheme.primaryColor;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? col : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? col : Colors.grey.withValues(alpha: 0.3)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
          ),
        ),
      ),
    );
  }

  void _showUserDetailsModal(
    BuildContext context,
    Map<String, dynamic> user,
    String countryName,
    String provName,
    String flag,
    Map<String, dynamic> norm,
  ) {
    final email = user['email'] as String? ?? '';
    final name = user['name'] as String? ?? '';
    final role = user['role'] as String? ?? 'CITIZEN';
    final provCode = (user['province_or_state'] as String? ?? 'QC').toUpperCase();
    final normName = norm['norm_name'] as String? ?? 'Norme régionale';
    final legalFramework = norm['legal_framework'] as String? ?? '';
    final regulator = norm['regulator'] as String? ?? '';
    final retentionDays = norm['data_retention_days'] as int? ?? 30;

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
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.15),
                    child: Text(flag, style: const TextStyle(fontSize: 22)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name.isNotEmpty ? name : email.split('@')[0], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text(email, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.accentOrange.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(role, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.accentOrange)),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const Divider(height: 1),
              const SizedBox(height: 14),
              const Text('LOCALISATION & JURIDICTION RÉGIONALE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 8),
              Text('$flag $countryName — $provName ($provCode)', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              const SizedBox(height: 14),
              const Text('CADRE LÉGAL & PROTECTION APPLIQUÉE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 6),
              Text(normName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.accentGreen)),
              if (legalFramework.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(legalFramework, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
              if (regulator.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('Organisme de contrôle : $regulator', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              ],
              const SizedBox(height: 8),
              Text('Durée de conservation maximale : $retentionDays jours (purge automatisée)', style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Fermer'),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
}
