import 'package:fpdart/fpdart.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/network/api_service.dart';
import '../../domain/entities/blacklisted_entry.dart';
import '../../domain/repositories/blacklist_repository.dart';

class BlacklistRepositoryImpl implements BlacklistRepository {
  final DatabaseHelper localDatabase;
  final ApiService remoteApi;

  BlacklistRepositoryImpl({
    DatabaseHelper? localDatabase,
    ApiService? remoteApi,
  })  : localDatabase = localDatabase ?? DatabaseHelper.instance,
        remoteApi = remoteApi ?? ApiService();

  @override
  Future<Either<Failure, List<BlacklistedEntry>>> getLocalBlacklist() async {
    try {
      final rows = await localDatabase.getAllBlacklistedNumbers();
      final domainList = rows.map(_toDomain).toList();
      return Right(domainList);
    } catch (e) {
      return Left(CacheFailure('Impossible de lire les numéros en cache SQLite: $e'));
    }
  }

  @override
  Future<Either<Failure, int>> syncBlacklistWithServer() async {
    try {
      final count = await remoteApi.syncBlacklistWithBackend();
      await localDatabase.checkpointWAL();
      return Right(count);
    } catch (e) {
      return Left(ServerFailure('Erreur lors de la synchronisation avec le serveur: $e'));
    }
  }

  @override
  Future<Either<Failure, BlacklistedEntry?>> checkNumberLocally(String rawPhoneNumber) async {
    try {
      final match = await localDatabase.checkNumber(rawPhoneNumber);
      return Right(match != null ? _toDomain(match) : null);
    } catch (e) {
      return Left(CacheFailure('Erreur vérification locale: $e'));
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> checkNumberOnServer(String rawPhoneNumber) async {
    try {
      final res = await remoteApi.checkNumberOnBackend(rawPhoneNumber);
      if (res != null) {
        return Right(res);
      }
      return const Right(<String, dynamic>{});
    } catch (e) {
      return Left(NetworkFailure('Serveur injoignable ou erreur réseau: $e'));
    }
  }

  @override
  Future<Either<Failure, bool>> submitSpamReport({
    required String rawPhoneNumber,
    required String category,
    String? comment,
  }) async {
    try {
      final success = await remoteApi.submitSpamReport(
        rawPhoneNumber: rawPhoneNumber,
        category: category,
        comment: comment,
      );
      if (success) {
        await localDatabase.checkpointWAL();
        return const Right(true);
      }
      return const Left(ServerFailure('Échec de validation du signalement par le serveur.'));
    } catch (e) {
      return Left(ServerFailure('Erreur d\'envoi du signalement: $e'));
    }
  }

  @override
  Future<Either<Failure, int>> clearLocalCache() async {
    try {
      final count = await localDatabase.clearCache();
      await localDatabase.checkpointWAL();
      return Right(count);
    } catch (e) {
      return Left(CacheFailure('Impossible d\'effacer le cache: $e'));
    }
  }

  BlacklistedEntry _toDomain(BlacklistedNumber model) {
    DateTime updatedDate;
    try {
      updatedDate = DateTime.parse(model.updatedAt);
    } catch (_) {
      updatedDate = DateTime.now();
    }

    return BlacklistedEntry(
      phoneHash: model.phoneHash,
      maskedNumber: model.maskedNumber ?? '',
      category: model.category,
      riskScore: model.riskScore,
      reportsCount: model.reportsCount,
      updatedAt: updatedDate,
    );
  }
}
