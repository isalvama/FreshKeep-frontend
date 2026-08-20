sealed class AuthFailure {
  final String message;

  const AuthFailure(this.message);
}

class ValidationFailure extends AuthFailure {
  const ValidationFailure(super.message); // 400
}

class ConflictFailure extends AuthFailure {
  const ConflictFailure(super.message); // 409 — register only
}

class InvalidCredentialsFailure extends AuthFailure {
  const InvalidCredentialsFailure(super.message); // 401 — login only
}

class AccountDisabledFailure extends AuthFailure {
  const AccountDisabledFailure(super.message); // 403 — login only
}

class ServerFailure extends AuthFailure {
  const ServerFailure(super.message); // 500
}

class NetworkFailure extends AuthFailure {
  const NetworkFailure(super.message); // no connectivity / timeout
}
