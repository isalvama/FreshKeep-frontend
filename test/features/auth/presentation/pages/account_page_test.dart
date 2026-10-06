import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:fresh_keep_frontend/core/errors/failures.dart';
import 'package:fresh_keep_frontend/features/auth/domain/entities/user.dart';
import 'package:fresh_keep_frontend/features/auth/domain/repositories/auth_repository.dart';
import 'package:fresh_keep_frontend/features/auth/domain/usecases/check_auth_status_usecase.dart';
import 'package:fresh_keep_frontend/features/auth/domain/usecases/current_user_usecase.dart';
import 'package:fresh_keep_frontend/features/auth/domain/usecases/logout_usecase.dart';
import 'package:fresh_keep_frontend/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:fresh_keep_frontend/features/auth/presentation/pages/account_page.dart';

const _user = User(id: 'user-1', email: 'ana@example.com');

class _AuthRepository implements AuthRepository {
  int logoutCalls = 0;

  @override
  Future<void> logout() async => logoutCalls++;

  @override
  Future<bool> hasValidSession() => throw UnimplementedError();

  @override
  Future<User?> currentUser() => throw UnimplementedError();

  @override
  Future<Either<AuthFailure, User>> login(String email, String password) =>
      throw UnimplementedError();

  @override
  Future<Either<AuthFailure, User>> register(String email, String password) =>
      throw UnimplementedError();
}

Future<AuthBloc> _pumpAccountPage(
  WidgetTester tester,
  _AuthRepository repository,
) async {
  final authBloc = AuthBloc(
    checkAuthStatusUseCase: CheckAuthStatusUseCase(repository),
    currentUserUseCase: CurrentUserUseCase(repository),
    logoutUseCase: LogoutUseCase(repository),
  )..add(const LoggedIn(_user));
  addTearDown(authBloc.close);

  await tester.pumpWidget(
    BlocProvider<AuthBloc>.value(
      value: authBloc,
      child: const MaterialApp(home: AccountPage()),
    ),
  );
  await tester.pumpAndSettle();
  return authBloc;
}

void main() {
  testWidgets('shows the signed-in email', (tester) async {
    await _pumpAccountPage(tester, _AuthRepository());

    expect(find.text('Account'), findsOneWidget);
    expect(find.text('ana@example.com'), findsOneWidget);
  });

  testWidgets('Log out ends the session', (tester) async {
    final repository = _AuthRepository();
    final authBloc = await _pumpAccountPage(tester, repository);

    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();

    expect(repository.logoutCalls, 1);
    expect(authBloc.state, isA<Unauthenticated>());
  });
}
