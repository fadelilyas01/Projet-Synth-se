import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/auth_provider.dart';
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

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                GoogleLogo(size: 26),
                SizedBox(width: 12),
                Expanded(
                  child: Text('Compte Google', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                const Text(
                  'Saisissez votre adresse Google / Gmail pour vous connecter instantanément sans mot de passe :',
                  style: TextStyle(fontSize: 13, color: Colors.grey, height: 1.4),
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
                    labelText: 'Adresse Google / Gmail',
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
                child: const Text('Annuler'),
              ),
              ElevatedButton(
                onPressed: isSubmitting
                    ? null
                    : () async {
                        final email = googleController.text.trim();
                        if (email.isEmpty || !email.contains('@')) {
                          setDialogState(() => localError = "Veuillez saisir une adresse email valide.");
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
                                content: Text('Bienvenue ! Connecté avec $email'),
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
                    : const Text('Se connecter'),
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

    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = "Veuillez renseigner l'email et le mot de passe.");
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
        await ref.read(authNotifierProvider.notifier).register(
          email,
          password,
          name: _nameController.text.trim(),
        );
      }
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isLogin ? 'Bienvenue ! Connexion réussie.' : 'Compte créé avec succès !'),
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
              content: Text('Bienvenue ! Connecté avec $rawEmail'),
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
                    _isLogin ? 'Connexion' : 'Créer un compte',
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
                    'OU PAR EMAIL',
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
                decoration: const InputDecoration(
                  labelText: 'Votre Nom ou Pseudo',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: _isLogin ? 'Email ou Identifiant (Admin)' : 'Adresse Email',
                hintText: _isLogin ? 'exemple@domaine.com ou admin' : 'exemple@domaine.com',
                prefixIcon: const Icon(Icons.mail_outline_rounded),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Mot de passe',
                prefixIcon: Icon(Icons.lock_outline_rounded),
              ),
            ),
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
                  : Text(_isLogin ? 'Se connecter' : 'Créer mon compte', style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => setState(() {
                _isLogin = !_isLogin;
                _errorMessage = null;
              }),
              child: Text(
                _isLogin ? "Pas encore de compte ? S'inscrire" : 'Déjà un compte ? Se connecter',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
