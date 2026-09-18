import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/emergency_whitelist_service.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/widgets/empty_state_widget.dart';

class EmergencyWhitelistPage extends ConsumerStatefulWidget {
  const EmergencyWhitelistPage({super.key});

  @override
  ConsumerState<EmergencyWhitelistPage> createState() => _EmergencyWhitelistPageState();
}

class _EmergencyWhitelistPageState extends ConsumerState<EmergencyWhitelistPage> {
  final _formKey = GlobalKey<FormState>();
  final _numberController = TextEditingController();
  final _labelController = TextEditingController();

  @override
  void dispose() {
    _numberController.dispose();
    _labelController.dispose();
    super.dispose();
  }

  void _showAddContactDialog() {
    _numberController.clear();
    _labelController.clear();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? AppTheme.surfaceDark : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border.all(
                color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
              ),
            ),
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.accentGreen.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.add_moderator_rounded, color: AppTheme.accentGreen, size: 24),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Ajouter à la Liste Blanche',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Ce numéro bénéficiera d\'une immunité totale. Il ne sera jamais bloqué ni filtré par ShieldNet.',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _labelController,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      labelText: 'Nom ou Organisation',
                      hintText: 'Ex: Hôpital de Gatineau, Dr. Tremblay, École...',
                      prefixIcon: const Icon(Icons.badge_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Veuillez renseigner un libellé';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _numberController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'Numéro de téléphone',
                      hintText: 'Ex: +1 819 555 0199 ou 8195550199',
                      prefixIcon: const Icon(Icons.phone_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Veuillez saisir un numéro';
                      }
                      final digits = val.replaceAll(RegExp(r'\D'), '');
                      if (digits.length < 3) {
                        return 'Numéro trop court';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () async {
                      if (_formKey.currentState?.validate() ?? false) {
                        HapticFeedback.mediumImpact();
                        final messenger = ScaffoldMessenger.of(context);
                        final navigator = Navigator.of(ctx);
                        final success = await ref
                            .read(emergencyWhitelistProvider.notifier)
                            .addContact(
                              rawNumber: _numberController.text.trim(),
                              label: _labelController.text.trim(),
                            );
                        navigator.pop();
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              success
                                  ? 'Contact d\'urgence protégé avec succès.'
                                  : 'Erreur lors de l\'enregistrement.',
                            ),
                            backgroundColor: success ? AppTheme.accentGreen : AppTheme.accentRed,
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.shield_rounded),
                    label: const Text('Enregistrer avec Immunité', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _confirmDelete(EmergencyContact contact) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Retirer de la Liste Blanche ?'),
        content: Text(
          'Voulez-vous retirer "${contact.label}" (${contact.rawNumber}) de la liste blanche d\'urgence ? Il sera à nouveau soumis aux filtres standards.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final ok = await ref
                  .read(emergencyWhitelistProvider.notifier)
                  .removeContact(contact.phoneHash);
              if (mounted && ok) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Contact retiré de la liste blanche.'),
                    backgroundColor: AppTheme.accentOrange,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentRed,
              foregroundColor: Colors.white,
            ),
            child: const Text('Retirer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(emergencyWhitelistProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final systemContacts = state.contacts.where((c) => c.isSystemCritical).toList();
    final customContacts = state.contacts.where((c) => !c.isSystemCritical).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Numéros d\'Urgence & Immunité',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddContactDialog,
        backgroundColor: AppTheme.accentGreen,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Ajouter un Contact', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
              children: [
                // 1. CARTE INFORMATIVE SUR L'IMMUNITÉ
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.accentGreen.withValues(alpha: isDark ? 0.12 : 0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppTheme.accentGreen.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.health_and_safety_rounded, color: AppTheme.accentGreen, size: 28),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Garantie Zéro Faux-Positif',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: AppTheme.accentGreen,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Ces numéros prioritaires ne sont jamais bloqués ni filtrés, même si le mode Bouclier Strict (Contacts uniquement) ou Nocturne est actif.',
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.35,
                                color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // 2. CONTACTS PERSONNALISÉS
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'CONTACTS PRIORITAIRES UTILISATEUR',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.5),
                    ),
                    Text(
                      '${customContacts.length}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.accentGreen),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                if (customContacts.isEmpty)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.surfaceDark : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isDark ? AppTheme.borderDark : AppTheme.borderLight),
                    ),
                    child: const EmptyStateWidget(
                      icon: Icons.contact_emergency_rounded,
                      iconColor: AppTheme.accentGreen,
                      title: 'Aucun contact prioritaire ajouté',
                      message: 'Ajoutez votre médecin, l\'hôpital ou une clinique pour garantir que leurs appels passent toujours.',
                    ),
                  )
                else
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.surfaceDark : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isDark ? AppTheme.borderDark : AppTheme.borderLight),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: customContacts.length,
                      separatorBuilder: (_, index) => const Divider(height: 1, indent: 56),
                      itemBuilder: (ctx, index) {
                        final contact = customContacts[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppTheme.accentGreen.withValues(alpha: 0.15),
                            child: const Icon(Icons.person_pin_rounded, color: AppTheme.accentGreen, size: 20),
                          ),
                          title: Text(contact.label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          subtitle: Text(contact.rawNumber, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.accentRed, size: 20),
                            onPressed: () => _confirmDelete(contact),
                          ),
                        );
                      },
                    ),
                  ),

                const SizedBox(height: 24),

                // 3. SERVICES OFFICIELS NORD-AMÉRICAINS (Verrouillés Système)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'SERVICES D\'URGENCE NATIONAUX (CANADA/QC)',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.5),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('Inviolable', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryLightColor)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                Container(
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.surfaceDark : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isDark ? AppTheme.borderDark : AppTheme.borderLight),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: systemContacts.length,
                    separatorBuilder: (_, index) => const Divider(height: 1, indent: 56),
                    itemBuilder: (ctx, index) {
                      final item = systemContacts[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppTheme.accentRed.withValues(alpha: 0.12),
                          child: Text(
                            item.rawNumber,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.accentRed),
                          ),
                        ),
                        title: Text(item.label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        subtitle: Text('Raccourci officiel (${item.rawNumber})', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                        trailing: const Tooltip(
                          message: 'Protection système non supprimable',
                          child: Icon(Icons.lock_outline_rounded, size: 16, color: Colors.grey),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
