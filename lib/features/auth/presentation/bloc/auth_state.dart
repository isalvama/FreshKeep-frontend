part of 'auth_bloc.dart';

sealed class AuthState {
  const AuthState();
}

final class AuthInitial extends AuthState {
  const AuthInitial();
}

final class Authenticated extends AuthState {
  final User user;

  const Authenticated(this.user);
}

final class Unauthenticated extends AuthState {
  const Unauthenticated();
}
