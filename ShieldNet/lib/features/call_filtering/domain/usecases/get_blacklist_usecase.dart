import 'package:fpdart/fpdart.dart';
import '../../../../core/error/failures.dart';
import '../entities/blacklisted_entry.dart';
import '../repositories/blacklist_repository.dart';

class GetBlacklistUseCase {
  final BlacklistRepository repository;

  GetBlacklistUseCase(this.repository);

  Future<Either<Failure, List<BlacklistedEntry>>> call() {
    return repository.getLocalBlacklist();
  }
}
