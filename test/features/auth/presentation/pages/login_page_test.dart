import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:fresh_keep_frontend/core/errors/failures.dart';
import 'package:fresh_keep_frontend/features/auth/domain/entities/user.dart';
import 'package:fresh_keep_frontend/features/auth/domain/repositories/auth_repository.dart';
import 'package:fresh_keep_frontend/features/auth/domain/usecases/check_auth_status_usecase.dart';
import 'package:fresh_keep_frontend/features/auth/domain/usecases/current_user_usecase.dart';
import 'package:fresh_keep_frontend/features/auth/domain/usecases/login_usecase.dart';
import 'package:fresh_keep_frontend/features/auth/domain/usecases/logout_usecase.dart';
import 'package:fresh_keep_frontend/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:fresh_keep_frontend/features/auth/presentation/bloc/login_bloc.dart';
import 'package:fresh_keep_frontend/features/auth/presentation/pages/login_page.dart';
import 'package:fresh_keep_frontend/routes/app_router.dart';
import 'package:go_router/go_router.dart';

const _user = User(id: 'user-1', email: 'ana@example.com');

/// Logging in succeeds as [_user] unless [failure] is set.
class _AuthRepository implements AuthRepository {
  _AuthRepository({this.failure});

  final AuthFailure? failure;

  @override
  Future<Either<AuthFailure, User>> login(
    String email,
    String password,
  ) async => failure != null ? Left(failure!) : const Right(_user);

  @override
  Future<void> logout() async {}

  @override
  Future<bool> hasValidSession() => throw UnimplementedError();

  @override
  Future<User?> currentUser() => throw UnimplementedError();

  @override
  Future<Either<AuthFailure, User>> register(String email, String password) =>
      throw UnimplementedError();
}

/// The login page under a router that, like the app's, leaves /login for
/// /home once the user is authenticated. Home is a stand-in.
Future<void> _pumpLoginPage(
  WidgetTester tester,
  _AuthRepository repository,
) async {
  final authBloc = AuthBloc(
    checkAuthStatusUseCase: CheckAuthStatusUseCase(repository),
    currentUserUseCase: CurrentUserUseCase(repository),
    logoutUseCase: LogoutUseCase(repository),
  );
  final loginBloc = LoginBloc(
    loginUseCase: LoginUseCase(repository),
    authBloc: authBloc,
  );
  addTearDown(loginBloc.close);
  addTearDown(authBloc.close);

  final router = GoRouter(
    initialLocation: '/login',
    refreshListenable: GoRouterRefreshStream(authBloc.stream),
    redirect: (context, state) =>
        authBloc.state is Authenticated && state.matchedLocation == '/login'
        ? '/home'
        : null,
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
      GoRoute(
        path: '/home',
        builder: (context, state) => const Scaffold(body: Text('Home stub')),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>.value(value: authBloc),
        BlocProvider<LoginBloc>.value(value: loginBloc),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
}

Future<void> _submit(WidgetTester tester) async {
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Email'),
    _user.email,
  );
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Password'),
    'password123',
  );
  await tester.tap(find.widgetWithText(ElevatedButton, 'Log in'));
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('after logging in, Home briefly shows "Logged in as <email>"', (
    tester,
  ) async {
    await _pumpLoginPage(tester, _AuthRepository());

    await _submit(tester);
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Home stub'), findsOneWidget);
    expect(find.text('Logged in as ana@example.com'), findsOneWidget);

    // A SnackBar's default display time is four seconds.
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    expect(find.text('Home stub'), findsOneWidget);
    expect(find.text('Logged in as ana@example.com'), findsNothing);
  });

  testWidgets('a failed login shows the error, not "Logged in as"', (
    tester,
  ) async {
    await _pumpLoginPage(
      tester,
      _AuthRepository(
        failure: const InvalidCredentialsFailure('Invalid credentials.'),
      ),
    );

    await _submit(tester);
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Invalid credentials.'), findsOneWidget);
    expect(find.textContaining('Logged in as'), findsNothing);
    expect(find.text('Home stub'), findsNothing);
  });
}
