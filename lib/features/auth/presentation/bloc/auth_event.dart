part of 'auth_bloc.dart';

sealed class AuthEvent {
  const AuthEvent();
}

final class AppStarted extends AuthEvent {
  const AppStarted();
}

final class LoggedIn extends AuthEvent {
  final User user;

  const LoggedIn(this.user);
}

final class LoggedOut extends AuthEvent {
  const LoggedOut();
}
