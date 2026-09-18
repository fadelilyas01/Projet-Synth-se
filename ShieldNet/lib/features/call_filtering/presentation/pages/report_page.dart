import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/citizen_impact_service.dart';
import '../controllers/blacklist_controller.dart';

class ReportPage extends ConsumerStatefulWidget {
  const ReportPage({super.key});

  @override
  ConsumerState<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends ConsumerState<ReportPage> {
  final _phoneController = TextEditingController();
  final _commentController = TextEditingController();
  String _selectedCategory = 'fraud';
  bool _isSubmitting = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitReport() async {
    final rawPhone = _phoneController.text.trim();
    if (rawPhone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez saisir un numéro de téléphone valide.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final reportUseCase = ref.read(reportSpamUseCaseProvider);

    final result = await reportUseCase(
      rawPhoneNumber: rawPhone,
      category: _selectedCategory,
      comment: _commentController.text.trim(),
    );

    if (mounted) {
      setState(() => _isSubmitting = false);

      result.fold(
        (failure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(failure.message),
              backgroundColor: AppTheme.accentRed,
            ),
          );
        },
        (_) async {
          _phoneController.clear();
          _commentController.clear();
          await CitizenImpactService.incrementReportsCount();
          // Rafraîchir la liste noire locale
          ref.read(blacklistControllerProvider.notifier).loadBlacklist();

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Signalement anonymisé HMAC transmis et enregistré avec succès.'),
                backgroundColor: AppTheme.accentGreen,
              ),
            );
          }
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Signaler un Numéro', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Aidez la communauté',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            const Text(
              'Signalez un numéro suspect pour le bloquer et avertir les autres utilisateurs de ShieldNet.',
              style: TextStyle(color: Colors.grey, fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Numéro de téléphone suspect',
                hintText: '+1 819 123 4567',
                prefixIcon: Icon(Icons.phone_rounded),
              ),
            ),
            const SizedBox(height: 24),
            DropdownButtonFormField<String>(
              initialValue: _selectedCategory,
              decoration: const InputDecoration(
                labelText: 'Nature de la nuisance',
                prefixIcon: Icon(Icons.category_rounded),
              ),
              icon: const Icon(Icons.keyboard_arrow_down_rounded),
              items: const [
                DropdownMenuItem(value: 'fraud', child: Text('Fraude / Arnaque')),
                DropdownMenuItem(value: 'telemarketing', child: Text('Démarchage Commercial')),
                DropdownMenuItem(value: 'financial_scam', child: Text('Arnaque Financière')),
                DropdownMenuItem(value: 'phishing', child: Text('Hameçonnage / Phishing')),
                DropdownMenuItem(value: 'robocall', child: Text('Appel Automatisé / Robocall')),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _selectedCategory = val);
              },
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _commentController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Commentaire (Optionnel)',
                hintText: 'Précisez le contexte de l\'appel...',
                prefixIcon: Padding(
                  padding: EdgeInsets.only(bottom: 40.0),
                  child: Icon(Icons.chat_bubble_outline_rounded),
                ),
              ),
            ),
            const SizedBox(height: 40),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.accentRed.withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
                gradient: const LinearGradient(
                  colors: [AppTheme.accentRed, AppTheme.accentOrange],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
              ),
              child: ElevatedButton.icon(
                onPressed: _isSubmitting ? null : _submitReport,
                icon: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _isSubmitting
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send_rounded, size: 24),
                ),
                label: const Text('Transmettre le Signalement', style: TextStyle(fontSize: 16)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
