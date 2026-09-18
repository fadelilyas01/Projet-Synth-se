import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/services/background_sync_service.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../l10n/app_localizations.dart';
import '../widgets/auth_bottom_sheet.dart';
import 'admin_console_page.dart';
import '../../../../core/services/night_shield_service.dart';
import '../../../sms_inspector/presentation/pages/sms_inspector_page.dart';
import 'emergency_whitelist_page.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  bool _autoBlockEnabled = true;
  bool _smsAnalysisEnabled = true;
  bool _contactsOnlyEnabled = false;
  bool _autoSyncEnabled = true;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final autoBlock = prefs.getBool('settings_auto_block') ?? true;
    final sms = prefs.getBool('settings_sms_analysis') ?? true;
    final contactsOnly = prefs.getBool('settings_contacts_only') ?? false;
    final autoSync = await BackgroundSyncService.instance.isAutoSyncEnabled();

    if (mounted) {
      setState(() {
        _autoBlockEnabled = autoBlock;
        _smsAnalysisEnabled = sms;
        _contactsOnlyEnabled = contactsOnly;
        _autoSyncEnabled = autoSync;
      });
    }
  }

  Future<void> _toggleAutoBlock(bool val) async {
    if (val) {
      final status = await Permission.phone.request();
      if (status.isGranted) {
        setState(() => _autoBlockEnabled = true);
        await ref.read(protectionStatusProvider.notifier).updateAutoBlock(true);
      }
    } else {
      setState(() => _autoBlockEnabled = false);
      await ref.read(protectionStatusProvider.notifier).updateAutoBlock(false);
    }
  }

  Future<void> _toggleSms(bool val) async {
    setState(() => _smsAnalysisEnabled = val);
    await ref.read(protectionStatusProvider.notifier).updateSmsAnalysis(val);
  }

  Future<void> _toggleContactsOnly(bool val) async {
    if (val) {
      final status = await Permission.contacts.request();
      if (status.isGranted) {
        setState(() => _contactsOnlyEnabled = true);
        await ref.read(contactsOnlyProvider.notifier).toggle(true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Mode Bouclier Strict activé : seuls vos contacts feront sonner le téléphone.'),
              backgroundColor: AppTheme.accentGreen,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Permission d\'accès aux contacts requise pour ce mode.'),
              backgroundColor: AppTheme.accentOrange,
            ),
          );
        }
      }
    } else {
      setState(() => _contactsOnlyEnabled = false);
      await ref.read(contactsOnlyProvider.notifier).toggle(false);
    }
  }

  Future<void> _toggleAutoSync(bool val) async {
    setState(() => _autoSyncEnabled = val);
    await BackgroundSyncService.instance.setAutoSyncEnabled(val);
  }

  Future<void> _syncNow([AppLocalizations? l10n]) async {
    setState(() => _isSyncing = true);
    try {
      final count = await BackgroundSyncService.instance.syncNow();
      if (mounted) {
        setState(() => _isSyncing = false);
        final defaultMsg = 'Protection à jour : $count numéros synchronisés.';
        final detailMsg = l10n?.syncSuccessDetail;
        final msg = detailMsg != null ? detailMsg.replaceAll('numéros', '$count numéros') : defaultMsg;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: AppTheme.accentGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSyncing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur réseau: $e'), backgroundColor: AppTheme.accentRed),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<bool>>(protectionStatusProvider, (_, next) {
      next.whenData((_) async {
        if (mounted) {
          final prefs = await SharedPreferences.getInstance();
          final autoBlock = prefs.getBool('settings_auto_block') ?? true;
          final sms = prefs.getBool('settings_sms_analysis') ?? true;
          if (_autoBlockEnabled != autoBlock || _smsAnalysisEnabled != sms) {
            setState(() {
              _autoBlockEnabled = autoBlock;
              _smsAnalysisEnabled = sms;
            });
          }
        }
      });
    });

    final l10n = AppLocalizations.of(context);
    final user = ref.watch(authNotifierProvider);
    final themeMode = ref.watch(themeModeProvider);
    final currentLocale = ref.watch(localeProvider);
    final nightShield = ref.watch(nightShieldProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = AppTheme.cardBg(isDark);
    final borderColor = AppTheme.borderColor(isDark);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n?.settingsTitle ?? 'Paramètres', style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // 1. COMPTE UTILISATEUR
          _buildUserAccountCard(user, cardBg, borderColor, isDark, l10n),
          const SizedBox(height: 16),

          // 2. SÉCURITÉ
          _buildSectionHeader(l10n?.sectionSecurity ?? 'SÉCURITÉ'),
          _buildCard(
            cardBg: cardBg,
            borderColor: borderColor,
            children: [
              SwitchListTile(
                value: _autoBlockEnabled,
                onChanged: _toggleAutoBlock,
                title: Text(l10n?.settingCallFiltering ?? 'Filtrage d\'appels', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                secondary: const Icon(Icons.shield, color: AppTheme.accentGreen, size: 24),
              ),
              const Divider(height: 1, indent: 56),
              SwitchListTile(
                value: _smsAnalysisEnabled,
                onChanged: _toggleSms,
                title: Text(l10n?.settingSmsFiltering ?? 'Filtrage des SMS', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                secondary: const Icon(Icons.sms, color: AppTheme.primaryColor, size: 24),
              ),
              const Divider(height: 1, indent: 56),
              SwitchListTile(
                value: _contactsOnlyEnabled,
                onChanged: _toggleContactsOnly,
                title: Text(l10n?.settingContactsOnly ?? 'Mode Contacts Uniquement', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: Text(l10n?.settingContactsOnlyDesc ?? 'Ne laisser sonner que vos contacts enregistrés', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                secondary: const Icon(Icons.contact_phone_rounded, color: AppTheme.accentOrange, size: 24),
              ),
              const Divider(height: 1, indent: 56),
              SwitchListTile(
                value: nightShield.isEnabled,
                onChanged: (val) {
                  ref.read(nightShieldProvider.notifier).setEnabled(val);
                },
                title: const Text('Mode Bouclier Nocturne', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: Text(
                  'Filtrage silencieux de ${nightShield.startHour.toString().padLeft(2, '0')}h${nightShield.startMinute.toString().padLeft(2, '0')} à ${nightShield.endHour.toString().padLeft(2, '0')}h${nightShield.endMinute.toString().padLeft(2, '0')}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                secondary: const Icon(Icons.bedtime_rounded, color: Colors.indigoAccent, size: 24),
              ),
              const Divider(height: 1, indent: 56),
              ListTile(
                leading: const Icon(Icons.mark_email_read_rounded, color: AppTheme.accentCyan, size: 24),
                title: const Text('Inspecteur de SMS & Liens', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: const Text('Analyser un message suspect ou un lien de livraison', style: TextStyle(fontSize: 12, color: Colors.grey)),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SmsInspectorPage()),
                  );
                },
              ),
              const Divider(height: 1, indent: 56),
              ListTile(
                leading: const Icon(Icons.health_and_safety_rounded, color: AppTheme.accentGreen, size: 24),
                title: const Text('Numéros d\'Urgence & Liste Blanche', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: const Text('911, 811 et contacts autorisés prioritaires', style: TextStyle(fontSize: 12, color: Colors.grey)),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const EmergencyWhitelistPage()),
                  );
                },
              ),
              const Divider(height: 1, indent: 56),
              SwitchListTile(
                value: _autoSyncEnabled,
                onChanged: _toggleAutoSync,
                title: Text(l10n?.settingBgSync ?? 'Sync en arrière-plan', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                secondary: const Icon(Icons.sync, color: AppTheme.primaryColor, size: 24),
              ),
              const Divider(height: 1, indent: 56),
              ListTile(
                leading: const Icon(Icons.cloud_download, color: AppTheme.primaryColor, size: 24),
                title: Text(l10n?.settingUpdateDb ?? 'Mettre à jour la base', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                trailing: _isSyncing
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(
                        l10n?.btnSync ?? 'Synchroniser',
                        style: const TextStyle(color: AppTheme.primaryColor, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                onTap: _isSyncing ? null : () => _syncNow(l10n),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 3. PRÉFÉRENCES
          _buildSectionHeader(l10n?.sectionPreferences ?? 'PRÉFÉRENCES'),
          _buildCard(
            cardBg: cardBg,
            borderColor: borderColor,
            children: [
              ListTile(
                leading: const Icon(Icons.palette, color: AppTheme.accentOrange, size: 24),
                title: Text(l10n?.settingTheme ?? 'Thème', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                trailing: DropdownButtonHideUnderline(
                  child: DropdownButton<ThemeMode>(
                    value: themeMode,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
                    items: [
                      DropdownMenuItem(value: ThemeMode.system, child: Text(l10n?.themeSystem ?? 'Système')),
                      DropdownMenuItem(value: ThemeMode.light, child: Text(l10n?.themeLight ?? 'Clair')),
                      DropdownMenuItem(value: ThemeMode.dark, child: Text(l10n?.themeDark ?? 'Sombre')),
                    ],
                    onChanged: (mode) {
                      if (mode != null) ref.read(themeModeProvider.notifier).state = mode;
                    },
                  ),
                ),
              ),
              const Divider(height: 1, indent: 56),
              ListTile(
                leading: const Icon(Icons.language, color: AppTheme.primaryColor, size: 24),
                title: Text(l10n?.settingLanguage ?? 'Langue', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                trailing: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: currentLocale.languageCode,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
                    items: [
                      DropdownMenuItem(value: 'fr', child: Text(l10n?.langFrench ?? 'Français')),
                      DropdownMenuItem(value: 'en', child: Text(l10n?.langEnglish ?? 'English')),
                    ],
                    onChanged: (langCode) {
                      if (langCode != null) {
                        ref.read(localeProvider.notifier).setLocale(langCode);
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 4. ADMINISTRATION (Si l'utilisateur est admin)
          if (user != null && user.isAdmin) ...[
            _buildSectionHeader(l10n?.sectionAdmin ?? 'ADMINISTRATION'),
            _buildCard(
              cardBg: cardBg,
              borderColor: borderColor,
              children: [
                ListTile(
                  leading: const Icon(Icons.admin_panel_settings, color: AppTheme.accentOrange, size: 24),
                  title: Text(l10n?.adminConsoleTitle ?? 'Console d\'Administration', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AdminConsolePage()),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],

          // 5. FOOTER
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 12.0),
              child: Text(
                'ShieldNet v1.0.0 • UQO',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserAccountCard(UserModel? user, Color cardBg, Color borderColor, bool isDark, AppLocalizations? l10n) {
    if (user != null) {
      return _buildCard(
        cardBg: cardBg,
        borderColor: borderColor,
        children: [
          ListTile(
            leading: CircleAvatar(
              radius: 20,
              backgroundColor: Theme.of(context).primaryColor,
              child: Text(
                user.email.isNotEmpty ? user.email[0].toUpperCase() : 'U',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            title: Row(
              children: [
                Flexible(
                  child: Text(
                    user.name.isNotEmpty ? user.name : user.email.split('@')[0],
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (user.isAdmin) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.accentOrange.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('ADMIN', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.accentOrange)),
                  ),
                ],
              ],
            ),
            subtitle: Text(
              user.email,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
              overflow: TextOverflow.ellipsis,
            ),
            trailing: TextButton(
              onPressed: () async {
                await ref.read(authNotifierProvider.notifier).logout();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n?.logoutSuccess ?? 'Déconnexion réussie.')),
                  );
                }
              },
              child: Text(l10n?.btnLogout ?? 'Déconnexion', style: const TextStyle(color: AppTheme.accentRed, fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      );
    }

    return _buildCard(
      cardBg: cardBg,
      borderColor: borderColor,
      children: [
        ListTile(
          leading: const Icon(Icons.account_circle, color: AppTheme.primaryColor, size: 28),
          title: Text(l10n?.userAccountTitle ?? 'Compte Utilisateur', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          subtitle: Text(l10n?.userAccountSubtitle ?? 'Se connecter ou s\'inscrire', style: const TextStyle(fontSize: 12, color: Colors.grey)),
          trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
          onTap: () => AuthBottomSheet.show(context),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 6),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: Colors.grey,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildCard({
    required Color cardBg,
    required Color borderColor,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(children: children),
      ),
    );
  }
}
