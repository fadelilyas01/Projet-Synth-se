import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/sms_phishing_detector.dart';
import '../../domain/usecases/analyze_sms_usecase.dart';

/// Provider pour le use case d'analyse de phishing SMS
final analyzeSmsUseCaseProvider = Provider<AnalyzeSmsUseCase>((ref) {
  return AnalyzeSmsUseCase();
});

/// État réactif de l'inspecteur de SMS
class SmsInspectorState {
  final String text;
  final bool isAnalyzing;
  final PhishingAnalysisResult? result;

  const SmsInspectorState({
    this.text = '',
    this.isAnalyzing = false,
    this.result,
  });

  SmsInspectorState copyWith({
    String? text,
    bool? isAnalyzing,
    PhishingAnalysisResult? Function()? result,
  }) {
    return SmsInspectorState(
      text: text ?? this.text,
      isAnalyzing: isAnalyzing ?? this.isAnalyzing,
      result: result != null ? result() : this.result,
    );
  }
}

/// Contrôleur Riverpod pour l'analyse heuristique des SMS et liens malveillants
class SmsInspectorNotifier extends StateNotifier<SmsInspectorState> {
  final AnalyzeSmsUseCase _analyzeUseCase;

  SmsInspectorNotifier(this._analyzeUseCase) : super(const SmsInspectorState());

  void setText(String text) {
    state = state.copyWith(text: text);
  }

  void clear() {
    state = const SmsInspectorState();
  }

  Future<void> analyze(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    state = state.copyWith(text: text, isAnalyzing: true);
    await Future.delayed(const Duration(milliseconds: 300));
    final analysis = _analyzeUseCase(trimmed);
    state = state.copyWith(
      isAnalyzing: false,
      result: () => analysis,
    );
  }
}

/// Provider d'état pour l'écran de détection de phishing SMS
final smsInspectorProvider =
    StateNotifierProvider<SmsInspectorNotifier, SmsInspectorState>((ref) {
  final useCase = ref.watch(analyzeSmsUseCaseProvider);
  return SmsInspectorNotifier(useCase);
});
