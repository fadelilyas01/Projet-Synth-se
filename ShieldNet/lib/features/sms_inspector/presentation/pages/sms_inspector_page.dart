import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/services/sms_phishing_detector.dart';
import '../../../../core/theme/app_theme.dart';

class SmsInspectorPage extends StatefulWidget {
  final String? initialText;

  const SmsInspectorPage({super.key, this.initialText});

  @override
  State<SmsInspectorPage> createState() => _SmsInspectorPageState();
}

class _SmsInspectorPageState extends State<SmsInspectorPage> {
  late TextEditingController _textController;
  PhishingAnalysisResult? _analysis;
  bool _isAnalyzing = false;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.initialText ?? '');
    if (widget.initialText != null && widget.initialText!.trim().isNotEmpty) {
      _runAnalysis();
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    HapticFeedback.selectionClick();
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.trim().isNotEmpty) {
      setState(() {
        _textController.text = data.text!;
      });
      _runAnalysis();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Le presse-papier est vide.'), backgroundColor: AppTheme.accentOrange),
        );
      }
    }
  }

  void _runAnalysis() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    HapticFeedback.mediumImpact();
    setState(() => _isAnalyzing = true);

    Future.delayed(const Duration(milliseconds: 350), () {
      final result = SmsPhishingDetector.analyze(text);
      if (mounted) {
        setState(() {
          _analysis = result;
          _isAnalyzing = false;
        });
      }
    });
  }

  void _clearAll() {
    HapticFeedback.selectionClick();
    setState(() {
      _textController.clear();
      _analysis = null;
    });
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
            Icon(Icons.mark_email_read_rounded, color: AppTheme.accentCyan),
            SizedBox(width: 8),
            Text('Inspecteur de SMS & Liens', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        actions: [
          if (_textController.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Réinitialiser',
              onPressed: _clearAll,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Carte d'introduction
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                    : [const Color(0xFFE0F2FE), const Color(0xFFBAE6FD)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.security_rounded, color: AppTheme.accentCyan, size: 30),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Analyse 100% Hors-Ligne & Confidentielle',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: isDark ? Colors.white : const Color(0xFF0369A1),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Le texte de vos SMS n\'est jamais transmis à un serveur distant.',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.grey.shade400 : const Color(0xFF0284C7),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Zone de saisie
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              children: [
                TextField(
                  controller: _textController,
                  maxLines: 5,
                  minLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Collez ici le texte du SMS suspect ou le message reçu...',
                    contentPadding: EdgeInsets.all(16),
                    border: InputBorder.none,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.content_paste_rounded, size: 16),
                        label: const Text('Coller le SMS', style: TextStyle(fontSize: 12)),
                        onPressed: _pasteFromClipboard,
                      ),
                      ElevatedButton.icon(
                        icon: _isAnalyzing
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.shield_outlined, size: 16),
                        label: const Text('Inspecter', style: TextStyle(fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accentCyan,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: _isAnalyzing ? null : _runAnalysis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Résultats de l'analyse
          if (_analysis != null) ...[
            _buildResultCard(_analysis!, cardBg, borderColor),
          ],
        ],
      ),
    );
  }

  Widget _buildResultCard(PhishingAnalysisResult res, Color cardBg, Color borderColor) {
    Color verdictColor;
    IconData verdictIcon;

    switch (res.level) {
      case PhishingRiskLevel.dangerous:
        verdictColor = AppTheme.accentRed;
        verdictIcon = Icons.dangerous_rounded;
        break;
      case PhishingRiskLevel.suspicious:
        verdictColor = AppTheme.accentOrange;
        verdictIcon = Icons.warning_amber_rounded;
        break;
      case PhishingRiskLevel.safe:
        verdictColor = AppTheme.accentGreen;
        verdictIcon = Icons.check_circle_outline_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: verdictColor.withValues(alpha: 0.5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: verdictColor.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête du diagnostic
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: verdictColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(verdictIcon, color: verdictColor, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      res.verdictTitle,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: verdictColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Score de risque : ${res.riskScore}/100',
                      style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(res.verdictDescription, style: const TextStyle(fontSize: 13, height: 1.4)),

          // Liens extraits
          if (res.extractedUrls.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('LIENS DÉTECTÉS DANS LE MESSAGE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.grey, letterSpacing: 1.0)),
            const SizedBox(height: 6),
            ...res.extractedUrls.map((u) => Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.link_off_rounded, size: 16, color: Colors.red),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      u,
                      style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: Colors.red, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            )),
          ],

          // Signaux d'alerte détectés
          if (res.detectedRedFlags.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Text('INDICATEURS DE SUSPICION', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.grey, letterSpacing: 1.0)),
            const SizedBox(height: 6),
            ...res.detectedRedFlags.map((flag) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.arrow_right_rounded, size: 18, color: Colors.orange),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(flag, style: const TextStyle(fontSize: 12, height: 1.3)),
                  ),
                ],
              ),
            )),
          ],

          // Recommandations
          if (res.recommendations.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Text('CONSEILS DE SÉCURITÉ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.grey, letterSpacing: 1.0)),
            const SizedBox(height: 6),
            ...res.recommendations.map((rec) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check_rounded, size: 16, color: AppTheme.accentGreen),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(rec, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            )),
          ],
        ],
      ),
    );
  }
}
