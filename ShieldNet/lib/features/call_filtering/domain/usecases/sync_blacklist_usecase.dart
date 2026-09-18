import 'package:fpdart/fpdart.dart';
import '../../../../core/error/failures.dart';
import '../repositories/blacklist_repository.dart';

class SyncBlacklistUseCase {
  final BlacklistRepository repository;

  SyncBlacklistUseCase(this.repository);

  Future<Either<Failure, int>> call() {
    return repository.syncBlacklistWithServer();
  }
}
