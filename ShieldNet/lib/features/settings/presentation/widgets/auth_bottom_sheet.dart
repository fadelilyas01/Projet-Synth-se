import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/services/regional_compliance_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/google_logo.dart';
import '../../../../core/widgets/google_sign_in_button.dart';

/// Boîte de dialogue et modale d'authentification (Google, Email, Admin)
class AuthBottomSheet extends ConsumerStatefulWidget {
  const AuthBottomSheet({super.key});

  /// Ouvre la modale de connexion / inscription
  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => const AuthBottomSheet(),
    );
  }

  /// Ouvre l'invite directe de connexion Google (sans mot de passe)
  static void showGooglePrompt(BuildContext context, WidgetRef ref, {VoidCallback? onSuccess}) {
    final googleController = TextEditingController();
    String? localError;
    bool isSubmitting = false;
    final isEn = Localizations.localeOf(context).languageCode == 'en';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                const GoogleLogo(size: 26),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    isEn ? 'Google Account' : 'Compte Google',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                Text(
                  isEn
                      ? 'Enter your Google / Gmail address to sign in instantly without a password:'
                      : 'Saisissez votre adresse Google / Gmail pour vous connecter instantanément sans mot de passe :',
                  style: const TextStyle(fontSize: 13, color: Colors.grey, height: 1.4),
                ),
                const SizedBox(height: 14),
                if (localError != null) ...[
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.accentRed.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      localError!,
                      style: const TextStyle(color: AppTheme.accentRed, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                TextField(
                  controller: googleController,
                  keyboardType: TextInputType.emailAddress,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: isEn ? 'Google / Gmail Address' : 'Adresse Google / Gmail',
                    hintText: 'votre.compte@gmail.com',
                    prefixIcon: const Icon(Icons.alternate_email_rounded, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                child: Text(isEn ? 'Cancel' : 'Annuler'),
              ),
              ElevatedButton(
                onPressed: isSubmitting
                    ? null
                    : () async {
                        final email = googleController.text.trim();
                        if (email.isEmpty || !email.contains('@')) {
                          setDialogState(() => localError = isEn
                              ? 'Please enter a valid email address.'
                              : "Veuillez saisir une adresse email valide.");
                          return;
                        }
                        setDialogState(() {
                          isSubmitting = true;
                          localError = null;
                        });
                        try {
                          await ref.read(authNotifierProvider.notifier).googleLogin(email);
                          if (ctx.mounted) Navigator.pop(ctx);
                          onSuccess?.call();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  isEn ? 'Welcome! Signed in with $email' : 'Bienvenue ! Connecté avec $email',
                                ),
                                backgroundColor: AppTheme.accentGreen,
                              ),
                            );
                          }
                        } catch (e) {
                          setDialogState(() {
                            isSubmitting = false;
                            localError = e.toString().replaceAll('Exception: ', '');
                          });
                        }
                      },
                child: isSubmitting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(isEn ? 'Sign in' : 'Se connecter'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  ConsumerState<AuthBottomSheet> createState() => _AuthBottomSheetState();
}

class _AuthBottomSheetState extends ConsumerState<AuthBottomSheet> {
  bool _isLogin = true;
  bool _obscurePassword = true;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  bool _loading = false;
  String? _errorMessage;

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
          : "Veuillez renseigner l'email et le mot de passe.");
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      if (_isLogin) {
        await ref.read(authNotifierProvider.notifier).login(email, password);
      } else {
        final currentRegion = ref.read(regionalComplianceProvider);
        await ref.read(authNotifierProvider.notifier).register(
          email,
          password,
          name: _nameController.text.trim(),
          country: currentRegion.country,
          provinceOrState: currentRegion.provinceOrState,
        );
      }
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isLogin
                  ? (isEn ? 'Welcome back! Signed in successfully.' : 'Bienvenue ! Connexion réussie.')
                  : (isEn ? 'Account created successfully!' : 'Compte créé avec succès !'),
            ),
            backgroundColor: AppTheme.accentGreen,
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

  Future<void> _handleGoogleSignIn() async {
    final rawEmail = _emailController.text.trim();
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    if (rawEmail.isNotEmpty && rawEmail.contains('@')) {
      setState(() {
        _loading = true;
        _errorMessage = null;
      });
      try {
        await ref.read(authNotifierProvider.notifier).googleLogin(rawEmail);
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isEn ? 'Welcome! Signed in with $rawEmail' : 'Bienvenue ! Connecté avec $rawEmail',
              ),
              backgroundColor: AppTheme.accentGreen,
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
    } else {
      AuthBottomSheet.showGooglePrompt(context, ref, onSuccess: () {
        if (mounted) Navigator.pop(context);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = AppTheme.borderColor(isDark);
    final isEn = Localizations.localeOf(context).languageCode == 'en';

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    _isLogin
                        ? (isEn ? 'Sign In' : 'Connexion')
                        : (isEn ? 'Create Account' : 'Créer un compte'),
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.accentRed.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.accentRed),
                ),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: AppTheme.accentRed, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Bouton Google Premium
            GoogleSignInButton(
              isLoading: _loading,
              onPressed: _loading ? null : _handleGoogleSignIn,
            ),
            const SizedBox(height: 16),

            // Séparateur
            Row(
              children: [
                Expanded(child: Divider(color: borderColor)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    isEn ? 'OR WITH EMAIL' : 'OU PAR EMAIL',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.grey.shade500, letterSpacing: 0.5),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Expanded(child: Divider(color: borderColor)),
              ],
            ),
            const SizedBox(height: 16),

            if (!_isLogin) ...[
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: isEn ? 'Your Name or Nickname' : 'Votre Nom ou Pseudo',
                  prefixIcon: const Icon(Icons.badge_outlined),
                ),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: _isLogin
                    ? (isEn ? 'Email or Username (Admin)' : 'Email ou Identifiant (Admin)')
                    : (isEn ? 'Email Address' : 'Adresse Email'),
                hintText: _isLogin
                    ? (isEn ? 'example@domain.com or admin' : 'exemple@domaine.com ou admin')
                    : (isEn ? 'example@domain.com' : 'exemple@domaine.com'),
                prefixIcon: const Icon(Icons.mail_outline_rounded),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: isEn ? 'Password' : 'Mot de passe',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 20,
                  ),
                  tooltip: _obscurePassword
                      ? (isEn ? 'Show password' : 'Afficher le mot de passe')
                      : (isEn ? 'Hide password' : 'Masquer le mot de passe'),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                ),
              ),
            ),
            if (_isLogin) ...[
              if (kDebugMode) ...[
                const SizedBox(height: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: () {
                        setState(() {
                          _emailController.text = 'admin@shieldnet.app';
                        });
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 4),
                        child: Row(
                          children: [
                            const Icon(Icons.vpn_key_rounded, size: 14, color: AppTheme.accentOrange),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                isEn
                                    ? 'Pre-fill Admin (admin@shieldnet.app)'
                                    : 'Pré-remplir Admin (admin@shieldnet.app)',
                                style: const TextStyle(fontSize: 11, color: AppTheme.accentOrange, fontWeight: FontWeight.w600),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    InkWell(
                      onTap: () {
                        setState(() {
                          _emailController.text = 'manager@shieldnet.app';
                        });
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 4),
                        child: Row(
                          children: [
                            const Icon(Icons.verified_user_rounded, size: 14, color: AppTheme.primaryColor),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                isEn
                                    ? 'Pre-fill Manager (manager@shieldnet.app)'
                                    : 'Pré-remplir Gestionnaire (manager@shieldnet.app)',
                                style: const TextStyle(fontSize: 11, color: AppTheme.primaryColor, fontWeight: FontWeight.w600),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loading ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _loading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(
                      _isLogin
                          ? (isEn ? 'Sign In' : 'Se connecter')
                          : (isEn ? 'Create My Account' : 'Créer mon compte'),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => setState(() {
                _isLogin = !_isLogin;
                _errorMessage = null;
              }),
              child: Text(
                _isLogin
                    ? (isEn ? "Don't have an account? Sign Up" : "Pas encore de compte ? S'inscrire")
                    : (isEn ? 'Already have an account? Sign In' : 'Déjà un compte ? Se connecter'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
