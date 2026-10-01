import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/services/regional_compliance_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/google_logo.dart';
import '../../../../core/widgets/google_sign_in_button.dart';
import '../pages/admin_console_page.dart';

/// Boîte de dialogue et modale d'authentification conviviale et humaine
/// Adaptée pour les citoyens (inscription / connexion / Google) et l'équipe d'administration
class AuthBottomSheet extends ConsumerStatefulWidget {
  final bool initialAdmin;

  const AuthBottomSheet({
    super.key,
    this.initialAdmin = false,
  });

  /// Ouvre la modale de connexion
  static void show(BuildContext context, {bool initialAdmin = false}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AuthBottomSheet(initialAdmin: initialAdmin),
    );
  }

  @override
  ConsumerState<AuthBottomSheet> createState() => _AuthBottomSheetState();
}

class _AuthBottomSheetState extends ConsumerState<AuthBottomSheet> {
  late bool _isAdminMode;
  bool _isLogin = true;
  bool _obscurePassword = true;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();

  bool _loading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _isAdminMode = widget.initialAdmin;
    if (_isAdminMode) {
      _emailController.text = 'admin@shieldnet.app';
      _passwordController.text = 'AdminPass123!';
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final isEn = Localizations.localeOf(context).languageCode == 'en';

    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = isEn
          ? 'Please enter both email and password.'
          : "Veuillez renseigner votre email et votre mot de passe.");
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      if (_isAdminMode) {
        await ref.read(authNotifierProvider.notifier).login(email, password);
        final user = ref.read(authNotifierProvider);
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.white),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isEn
                          ? 'Welcome to the administration console!'
                          : 'Bienvenue dans la console d\'administration !',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              backgroundColor: AppTheme.accentGreen,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );

          if (user != null && user.canModerate) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AdminConsolePage()),
            );
          }
        }
      } else {
        if (_isLogin) {
          await ref.read(authNotifierProvider.notifier).login(email, password);
        } else {
          final currentRegion = ref.read(regionalComplianceProvider);
          await ref.read(authNotifierProvider.notifier).register(
            email,
            password,
            name: _nameController.text.trim().isNotEmpty ? _nameController.text.trim() : null,
            country: currentRegion.country,
            provinceOrState: currentRegion.provinceOrState,
          );
        }

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.white),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _isLogin
                          ? (isEn ? 'Welcome back! Signed in successfully.' : 'Ravi de vous revoir ! Connexion réussie.')
                          : (isEn ? 'Account created! Welcome to ShieldNet.' : 'Compte créé avec succès ! Bienvenue sur ShieldNet.'),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              backgroundColor: AppTheme.accentGreen,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  Future<void> _handleGoogleSignIn() async {
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    final customEmailController = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final cardBg = AppTheme.cardBg(isDark);
        final borderColor = AppTheme.borderColor(isDark);

        return Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
                  const GoogleLogo(size: 26),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isEn ? 'Sign in with Google' : 'Connexion avec Google',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                isEn
                    ? 'Choose an account to connect to ShieldNet and sync your protections:'
                    : 'Sélectionnez un compte pour vous connecter à ShieldNet et synchroniser vos protections :',
                style: const TextStyle(fontSize: 13, color: Colors.grey, height: 1.4),
              ),
              const SizedBox(height: 18),

              // Compte rapide 1-clic
              InkWell(
                onTap: () async {
                  Navigator.pop(ctx);
                  _performGoogleLogin('utilisateur.shieldnet@gmail.com', name: 'Alexandre');
                },
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: borderColor),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.15),
                        child: const Text('A', style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Alexandre', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            Text('utilisateur.shieldnet@gmail.com', style: TextStyle(color: Colors.grey, fontSize: 12)),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Saisie d'une autre adresse
              TextField(
                controller: customEmailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: isEn ? 'Or other Gmail address' : 'Ou une autre adresse Gmail',
                  hintText: 'votre.nom@gmail.com',
                  prefixIcon: const Icon(Icons.alternate_email_rounded),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.arrow_forward_rounded, color: AppTheme.primaryColor),
                    onPressed: () {
                      final email = customEmailController.text.trim();
                      if (email.contains('@')) {
                        Navigator.pop(ctx);
                        _performGoogleLogin(email);
                      }
                    },
                  ),
                ),
                onSubmitted: (email) {
                  if (email.trim().contains('@')) {
                    Navigator.pop(ctx);
                    _performGoogleLogin(email.trim());
                  }
                },
              ),
              const SizedBox(height: 10),
              Text(
                isEn
                    ? '100% private: ShieldNet never accesses your emails or private messages.'
                    : '100% confidentiel : ShieldNet n\'accède jamais à vos courriels ni à vos messages.',
                style: const TextStyle(fontSize: 11, color: Colors.grey, fontStyle: FontStyle.italic),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _performGoogleLogin(String email, {String? name}) async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      await ref.read(authNotifierProvider.notifier).googleLogin(email, name: name);
      if (mounted) {
        Navigator.pop(context);
        final isEn = Localizations.localeOf(context).languageCode == 'en';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isEn ? 'Welcome! Signed in with $email' : 'Bienvenue ! Connecté avec $email',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: AppTheme.accentGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = AppTheme.borderColor(isDark);
    final isEn = Localizations.localeOf(context).languageCode == 'en';

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Barre de préhension
            Center(
              child: Container(
                width: 44,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Sélecteur Espace Citoyen / Espace Équipe & Admin
            Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _isAdminMode = false;
                          _errorMessage = null;
                        });
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: !_isAdminMode
                              ? (isDark ? const Color(0xFF1E293B) : Colors.white)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: !_isAdminMode
                              ? [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                                    blurRadius: 4,
                                    offset: const Offset(0, 1),
                                  ),
                                ]
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.person_rounded,
                              size: 18,
                              color: !_isAdminMode ? AppTheme.primaryColor : Colors.grey,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isEn ? 'Citizen Space' : 'Espace Citoyen',
                              style: TextStyle(
                                fontWeight: !_isAdminMode ? FontWeight.bold : FontWeight.w500,
                                color: !_isAdminMode
                                    ? (isDark ? Colors.white : Colors.black87)
                                    : Colors.grey,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _isAdminMode = true;
                          _errorMessage = null;
                          _isLogin = true;
                          if (_emailController.text.isEmpty || _emailController.text.contains('gmail')) {
                            _emailController.text = 'admin@shieldnet.app';
                            _passwordController.text = 'AdminPass123!';
                          }
                        });
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _isAdminMode
                              ? (isDark ? const Color(0xFF1E293B) : Colors.white)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: _isAdminMode
                              ? [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                                    blurRadius: 4,
                                    offset: const Offset(0, 1),
                                  ),
                                ]
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.admin_panel_settings_rounded,
                              size: 18,
                              color: _isAdminMode ? AppTheme.accentOrange : Colors.grey,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isEn ? 'Admin & Team' : 'Équipe & Admin',
                              style: TextStyle(
                                fontWeight: _isAdminMode ? FontWeight.bold : FontWeight.w500,
                                color: _isAdminMode
                                    ? (isDark ? Colors.white : Colors.black87)
                                    : Colors.grey,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // En-tête personnalisé selon le mode
            if (_isAdminMode) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.accentOrange.withValues(alpha: 0.14),
                      AppTheme.primaryColor.withValues(alpha: 0.06),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.accentOrange.withValues(alpha: 0.25)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.accentOrange.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.security_rounded, color: AppTheme.accentOrange, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                isEn ? 'Supervisor Console' : 'Console de Supervision',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.accentOrange,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'PRO',
                                  style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            isEn
                                ? 'Dedicated portal for network moderation and blacklist supervision.'
                                : 'Accès sécurisé pour la modération de la liste noire et l\'audit réseau.',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ] else ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isLogin
                              ? (isEn ? 'Welcome Back!' : 'Ravi de vous revoir !')
                              : (isEn ? 'Join the Community' : 'Rejoindre la communauté'),
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _isLogin
                              ? (isEn
                                  ? 'Sign in to sync your protections and reports.'
                                  : 'Connectez-vous pour retrouver vos signalements et préférences.')
                              : (isEn
                                  ? 'Create your account to help protect your friends and family.'
                                  : 'Créez votre compte pour participer au bouclier citoyen.'),
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Bouton Google pour les citoyens
              GoogleSignInButton(
                isLoading: _loading,
                onPressed: _loading ? null : _handleGoogleSignIn,
              ),
              const SizedBox(height: 18),

              // Séparateur épuré
              Row(
                children: [
                  Expanded(child: Divider(color: borderColor)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      isEn ? 'OR WITH EMAIL' : 'OU AVEC VOTRE EMAIL',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade500,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  Expanded(child: Divider(color: borderColor)),
                ],
              ),
              const SizedBox(height: 18),
            ],

            // Message d'erreur
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.accentRed.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.accentRed.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: AppTheme.accentRed, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: AppTheme.accentRed, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Champ Nom (si inscription citoyen)
            if (!_isAdminMode && !_isLogin) ...[
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: isEn ? 'Your Name or Nickname' : 'Votre Nom ou Pseudo',
                  hintText: isEn ? 'e.g. Alex' : 'ex. Alexandre',
                  prefixIcon: const Icon(Icons.badge_outlined),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Champ Email
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: _isAdminMode
                    ? (isEn ? 'Team / Admin Email' : 'Email ou Identifiant d\'équipe')
                    : (isEn ? 'Email Address' : 'Adresse Email'),
                hintText: _isAdminMode ? 'admin@shieldnet.app' : 'alexandre@exemple.com',
                prefixIcon: Icon(_isAdminMode ? Icons.security_rounded : Icons.mail_outline_rounded),
              ),
            ),
            const SizedBox(height: 12),

            // Champ Mot de passe
            TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: _isAdminMode
                    ? (isEn ? 'Admin Security Password' : 'Mot de passe administrateur')
                    : (isEn ? 'Password' : 'Mot de passe'),
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    size: 20,
                  ),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
            ),

            // Raccourcis de profil démo pour l'équipe / admin
            if (_isAdminMode) ...[
              const SizedBox(height: 16),
              Text(
                isEn ? 'DEMO PROFILES' : 'PROFILS DE DÉMONSTRATION',
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.grey, letterSpacing: 0.8),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        side: BorderSide(
                          color: _emailController.text == 'admin@shieldnet.app'
                              ? AppTheme.accentOrange
                              : borderColor,
                        ),
                      ),
                      icon: const Icon(Icons.admin_panel_settings_rounded, size: 16, color: AppTheme.accentOrange),
                      label: Text(
                        isEn ? 'Super Admin' : 'Admin Général',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                      onPressed: () {
                        setState(() {
                          _emailController.text = 'admin@shieldnet.app';
                          _passwordController.text = 'AdminPass123!';
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        side: BorderSide(
                          color: _emailController.text == 'manager@shieldnet.app'
                              ? AppTheme.primaryColor
                              : borderColor,
                        ),
                      ),
                      icon: const Icon(Icons.verified_user_rounded, size: 16, color: AppTheme.primaryColor),
                      label: Text(
                        isEn ? 'Manager' : 'Gestionnaire',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                      onPressed: () {
                        setState(() {
                          _emailController.text = 'manager@shieldnet.app';
                          _passwordController.text = 'ManagerPass123!';
                        });
                      },
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 22),

            // Bouton Principal de Soumission
            ElevatedButton(
              onPressed: _loading ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isAdminMode ? AppTheme.accentOrange : AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: _loading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(_isAdminMode ? Icons.login_rounded : (_isLogin ? Icons.lock_open_rounded : Icons.person_add_rounded), size: 18),
                        const SizedBox(width: 8),
                        Text(
                          _isAdminMode
                              ? (isEn ? 'Open Administration Console' : 'Accéder à la Console d\'Administration')
                              : (_isLogin
                                  ? (isEn ? 'Sign In' : 'Se connecter')
                                  : (isEn ? 'Create My Account' : 'Créer mon compte citoyen')),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ],
                    ),
            ),

            // Bascule Inscription / Connexion citoyenne
            if (!_isAdminMode) ...[
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: () => setState(() {
                    _isLogin = !_isLogin;
                    _errorMessage = null;
                  }),
                  child: Text(
                    _isLogin
                        ? (isEn ? "Don't have an account? Sign Up" : "Nouveau sur ShieldNet ? Créer un compte")
                        : (isEn ? 'Already have an account? Sign In' : 'Déjà un compte ? Se connecter'),
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
