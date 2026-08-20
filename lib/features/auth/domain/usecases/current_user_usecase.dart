import '../entities/user.dart';
import '../repositories/auth_repository.dart';

class CurrentUserUseCase {
  final AuthRepository repository;

  const CurrentUserUseCase(this.repository);

  Future<User?> call() {
    return repository.currentUser();
  }
}
