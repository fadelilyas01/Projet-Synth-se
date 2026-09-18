import 'package:fpdart/fpdart.dart';
import '../../../../core/error/failures.dart';
import '../entities/blacklisted_entry.dart';

/// Contrat de Repository selon les préceptes de la Clean Architecture
abstract class BlacklistRepository {
  /// Récupère l'ensemble des numéros bloqués en cache local SQLite
  Future<Either<Failure, List<BlacklistedEntry>>> getLocalBlacklist();

  /// Synchronise la liste noire globale depuis le serveur Django et met à jour le cache SQLite
  Future<Either<Failure, int>> syncBlacklistWithServer();

  /// Vérifie la présence d'un numéro dans la base SQLite locale
  Future<Either<Failure, BlacklistedEntry?>> checkNumberLocally(String rawPhoneNumber);

  /// Interroge le serveur Django pour obtenir l'analyse en direct d'un numéro
  Future<Either<Failure, Map<String, dynamic>>> checkNumberOnServer(String rawPhoneNumber);

  /// Soumet un nouveau signalement communautaire
  Future<Either<Failure, bool>> submitSpamReport({
    required String rawPhoneNumber,
    required String category,
    String? comment,
  });

  /// Vide le cache local SQLite
  Future<Either<Failure, int>> clearLocalCache();
}
