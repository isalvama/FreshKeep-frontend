import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../entities/user.dart';

abstract class AuthRepository {
  Future<Either<AuthFailure, User>> register(String email, String password);

  Future<Either<AuthFailure, User>> login(String email, String password);

  Future<void> logout();

  Future<bool> hasValidSession();

  Future<User?> currentUser();
}
