import 'package:fpdart/fpdart.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/security/automated_spam_verifier.dart';
import '../entities/blacklisted_entry.dart';
import '../repositories/blacklist_repository.dart';

class NumberAnalysisResult {
  final String rawNumber;
  final bool isSpam;
  final bool isWhitelisted;
  final int riskScore;
  final int reportsCount;
  final BlacklistedEntry? localMatch;
  final SpamVerificationResult algorithmicResult;
  final Map<String, dynamic>? serverDetails;

  NumberAnalysisResult({
    required this.rawNumber,
    required this.isSpam,
    required this.isWhitelisted,
    required this.riskScore,
    required this.reportsCount,
    this.localMatch,
    required this.algorithmicResult,
    this.serverDetails,
  });
}

class CheckNumberUseCase {
  final BlacklistRepository repository;

  CheckNumberUseCase(this.repository);

  Future<Either<Failure, NumberAnalysisResult>> call(String rawPhoneNumber) async {
    if (rawPhoneNumber.trim().isEmpty) {
      return const Left(ValidationFailure('Le numéro de téléphone ne peut pas être vide.'));
    }

    try {
      // 1. Analyse algorithmique heuristique locale
      final algoResult = AutomatedSpamVerifier.verifyNumber(rawPhoneNumber);

      // 2. Recherche dans le cache local SQLite (< 5 ms)
      final localResultEither = await repository.checkNumberLocally(rawPhoneNumber);
      final localMatch = localResultEither.getOrElse((_) => null);

      // 3. Interrogation du serveur backend Django (avec fallback si hors-ligne)
      final serverResultEither = await repository.checkNumberOnServer(rawPhoneNumber);
      final serverDetails = serverResultEither.getOrElse((_) => <String, dynamic>{});

      final bool isWhitelisted = serverDetails['is_whitelisted'] == true;
      final int backendReports = serverDetails['reports_count'] ?? (localMatch?.reportsCount ?? 0);
      final int riskScore = isWhitelisted 
          ? 0 
          : (serverDetails['risk_score'] ?? (localMatch?.riskScore ?? algoResult.calculatedRiskScore));
      final bool isSpam = !isWhitelisted && (serverDetails['is_spam'] == true || localMatch != null || algoResult.isVerifiedSpam);

      return Right(
        NumberAnalysisResult(
          rawNumber: rawPhoneNumber,
          isSpam: isSpam,
          isWhitelisted: isWhitelisted,
          riskScore: riskScore,
          reportsCount: backendReports,
          localMatch: localMatch,
          algorithmicResult: algoResult,
          serverDetails: serverDetails.isNotEmpty ? serverDetails : null,
        ),
      );
    } catch (e) {
      return Left(PlatformFailure('Erreur lors de l\'analyse du numéro: $e'));
    }
  }
}
