import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:fresh_keep_frontend/app.dart';
import 'package:fresh_keep_frontend/core/deep_links/pending_invitation_store.dart';
import 'package:fresh_keep_frontend/core/di/service_locator.dart';
import 'package:fresh_keep_frontend/core/errors/failures.dart';
import 'package:fresh_keep_frontend/features/auth/domain/entities/user.dart';
import 'package:fresh_keep_frontend/features/auth/domain/repositories/auth_repository.dart';
import 'package:fresh_keep_frontend/features/auth/domain/usecases/check_auth_status_usecase.dart';
import 'package:fresh_keep_frontend/features/auth/domain/usecases/current_user_usecase.dart';
import 'package:fresh_keep_frontend/features/auth/domain/usecases/login_usecase.dart';
import 'package:fresh_keep_frontend/features/auth/domain/usecases/logout_usecase.dart';
import 'package:fresh_keep_frontend/features/auth/domain/usecases/register_usecase.dart';
import 'package:fresh_keep_frontend/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:fresh_keep_frontend/features/auth/presentation/bloc/login_bloc.dart';
import 'package:fresh_keep_frontend/features/auth/presentation/bloc/register_bloc.dart';
import 'package:fresh_keep_frontend/features/spaces/domain/entities/space.dart';
import 'package:fresh_keep_frontend/features/spaces/domain/entities/space_invitation.dart';
import 'package:fresh_keep_frontend/features/spaces/domain/entities/storage_spot_input.dart';
import 'package:fresh_keep_frontend/features/spaces/domain/repositories/space_repository.dart';
import 'package:fresh_keep_frontend/features/spaces/domain/usecases/get_user_spaces_usecase.dart';
import 'package:fresh_keep_frontend/features/spaces/domain/usecases/join_space_invitation_usecase.dart';
import 'package:fresh_keep_frontend/features/spaces/presentation/bloc/join_space_bloc.dart';
import 'package:fresh_keep_frontend/features/spaces/presentation/bloc/spaces_bloc.dart';
import 'package:fresh_keep_frontend/routes/app_router.dart';
import 'package:go_router/go_router.dart';

const _user = User(id: 'user-1', email: 'ana@example.com');

/// A session is valid only when [hasSession] is true.
class _AuthRepository implements AuthRepository {
  _AuthRepository({this.hasSession = false});

  final bool hasSession;

  @override
  Future<bool> hasValidSession() async => hasSession;

  @override
  Future<User?> currentUser() async => hasSession ? _user : null;

  @override
  Future<void> logout() async {}

  @override
  Future<Either<AuthFailure, User>> login(String email, String password) =>
      throw UnimplementedError();

  @override
  Future<Either<AuthFailure, User>> register(String email, String password) =>
      throw UnimplementedError();
}

/// Home loads an empty list; nothing else is expected to be called.
class _SpaceRepository implements SpaceRepository {
  @override
  Future<Either<SpaceFailure, List<Space>>> getUserSpaces() async =>
      const Right([]);

  @override
  Future<Either<SpaceFailure, String>> joinInvitation({
    required String token,
  }) => throw UnimplementedError();

  @override
  Future<Either<SpaceFailure, SpaceInvitation>> createInvitation({
    required String spaceId,
  }) => throw UnimplementedError();

  @override
  Future<Either<SpaceFailure, Space>> createSpace({
    required String spaceName,
    required String emoji,
    required List<StorageSpotInput> storageSpots,
  }) => throw UnimplementedError();
}

const _invited = "You've been invited to join a space";

/// The real router over the real pages, with fake repositories.
class _Harness {
  _Harness({bool hasSession = false})
    : authRepository = _AuthRepository(hasSession: hasSession);

  final _AuthRepository authRepository;
  final store = PendingInvitationStore();
  late final AuthBloc authBloc;
  late final GoRouter router;

  /// The top-most page's location, pushed pages included.
  String get location => router.state.uri.toString();

  Future<void> pump(WidgetTester tester) async {
    final spaceRepository = _SpaceRepository();
    getIt.registerFactory(
      () => JoinSpaceBloc(
        joinSpaceInvitationUseCase: JoinSpaceInvitationUseCase(spaceRepository),
      ),
    );
    authBloc = AuthBloc(
      checkAuthStatusUseCase: CheckAuthStatusUseCase(authRepository),
      currentUserUseCase: CurrentUserUseCase(authRepository),
      logoutUseCase: LogoutUseCase(authRepository),
    );
    router = buildAppRouter(authBloc, pendingInvitations: store);
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider.value(value: authBloc),
          BlocProvider(
            create: (_) => LoginBloc(
              loginUseCase: LoginUseCase(authRepository),
              authBloc: authBloc,
            ),
          ),
          BlocProvider(
            create: (_) =>
                RegisterBloc(registerUseCase: RegisterUseCase(authRepository)),
          ),
          BlocProvider(
            create: (_) => SpacesBloc(
              getUserSpacesUseCase: GetUserSpacesUseCase(spaceRepository),
            ),
          ),
        ],
        child: AuthSessionListener(
          pendingInvitations: store,
          child: MaterialApp.router(routerConfig: router),
        ),
      ),
    );
    await _settle(tester);
  }

  /// Starts the app: resolves [AuthInitial] from the stored session.
  Future<void> start(WidgetTester tester) async {
    authBloc.add(const AppStarted());
    await _settle(tester);
  }

  Future<void> openLink(WidgetTester tester, String token) async {
    router.push('/join?token=${Uri.encodeQueryComponent(token)}');
    await _settle(tester);
  }

  Future<void> logIn(WidgetTester tester) async {
    authBloc.add(const LoggedIn(_user));
    await _settle(tester);
  }
}

/// The splash spinner never settles, so pump a few frames instead.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  tearDown(() => getIt.reset());

  testWidgets('logged out, a link lands on Login; after logging in it lands '
      'on the join page and the store is empty', (tester) async {
    final harness = _Harness();
    await harness.pump(tester);
    await harness.start(tester);

    await harness.openLink(tester, 'abc');
    expect(harness.location, '/login');

    await harness.logIn(tester);
    expect(harness.location, '/join?token=abc');
    expect(find.text(_invited), findsOneWidget);
    expect(harness.store.take(), isNull);
  });

  testWidgets('cold start: a link opened while the session is being checked '
      'lands on the join page once authenticated', (tester) async {
    final harness = _Harness(hasSession: true);
    await harness.pump(tester);

    await harness.openLink(tester, 'abc');
    expect(harness.location, '/splash');

    await harness.start(tester);
    expect(harness.location, '/join?token=abc');
    expect(find.text(_invited), findsOneWidget);
  });

  testWidgets('going through Register and back to Login keeps the token', (
    tester,
  ) async {
    final harness = _Harness();
    await harness.pump(tester);
    await harness.start(tester);
    await harness.openLink(tester, 'a b&c');

    harness.router.go('/register');
    await _settle(tester);
    expect(harness.location, '/register');
    harness.router.go('/login');
    await _settle(tester);

    await harness.logIn(tester);
    expect(
      harness
          .router
          .routerDelegate
          .currentConfiguration
          .uri
          .queryParameters['token'],
      'a b&c',
    );
  });

  testWidgets('a link without a token still waits for the login, then shows '
      'the invalid page', (tester) async {
    final harness = _Harness();
    await harness.pump(tester);
    await harness.start(tester);

    harness.router.push('/join');
    await _settle(tester);
    await harness.logIn(tester);

    expect(harness.location, '/join?token=');
    expect(find.text('This invitation link is invalid.'), findsOneWidget);
  });

  testWidgets('after the token has been used, a later login goes to Home', (
    tester,
  ) async {
    final harness = _Harness();
    await harness.pump(tester);
    await harness.start(tester);
    await harness.openLink(tester, 'abc');
    await harness.logIn(tester);
    expect(harness.location, '/join?token=abc');
    await tester.tap(find.text('Cancel'));
    await _settle(tester);
    expect(harness.location, '/home');

    harness.authBloc.add(const LoggedOut());
    await _settle(tester);
    expect(harness.location, '/login');
    await harness.logIn(tester);

    expect(harness.location, '/home');
  });

  testWidgets('with no pending token, the redirects are unchanged', (
    tester,
  ) async {
    final withSession = _Harness(hasSession: true);
    await withSession.pump(tester);
    expect(withSession.location, '/splash');
    await withSession.start(tester);
    expect(withSession.location, '/home');

    await tester.pumpWidget(const SizedBox());
    await getIt.reset();

    final withoutSession = _Harness();
    await withoutSession.pump(tester);
    await withoutSession.start(tester);
    expect(withoutSession.location, '/login');
    await withoutSession.logIn(tester);
    expect(withoutSession.location, '/home');
  });

  testWidgets('the Account button on Home opens Account, and logging out '
      'there lands on Login', (tester) async {
    final harness = _Harness(hasSession: true);
    await harness.pump(tester);
    await harness.start(tester);
    expect(harness.location, '/home');

    await tester.tap(find.byTooltip('Account'));
    await _settle(tester);
    expect(harness.location, '/account');
    expect(find.text('ana@example.com'), findsOneWidget);

    await tester.tap(find.text('Log out'));
    await _settle(tester);

    expect(harness.location, '/login');
    expect(harness.router.canPop(), isFalse);
  });

  testWidgets('while logged in, a link opens the join page directly', (
    tester,
  ) async {
    final harness = _Harness(hasSession: true);
    await harness.pump(tester);
    await harness.start(tester);

    await harness.openLink(tester, 'abc');

    expect(harness.location, '/join?token=abc');
    expect(harness.router.canPop(), isTrue);
    expect(harness.store.take(), isNull);
  });

  group('AuthSessionListener', () {
    Future<(AuthBloc, PendingInvitationStore)> pumpListener(
      WidgetTester tester,
    ) async {
      final authRepository = _AuthRepository();
      final authBloc = AuthBloc(
        checkAuthStatusUseCase: CheckAuthStatusUseCase(authRepository),
        currentUserUseCase: CurrentUserUseCase(authRepository),
        logoutUseCase: LogoutUseCase(authRepository),
      );
      final store = PendingInvitationStore();
      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider.value(value: authBloc),
            BlocProvider(
              create: (_) => SpacesBloc(
                getUserSpacesUseCase: GetUserSpacesUseCase(_SpaceRepository()),
              ),
            ),
          ],
          child: AuthSessionListener(
            pendingInvitations: store,
            child: const SizedBox(),
          ),
        ),
      );
      return (authBloc, store);
    }

    testWidgets('logging out clears a pending token', (tester) async {
      final (authBloc, store) = await pumpListener(tester);
      authBloc.add(const LoggedIn(_user));
      await tester.pump();

      store.save('abc');
      authBloc.add(const LoggedOut());
      await tester.pump();
      await tester.pump();

      expect(store.take(), isNull);
    });

    testWidgets('logging in keeps a pending token and loads the spaces', (
      tester,
    ) async {
      final (authBloc, store) = await pumpListener(tester);
      store.save('abc');

      authBloc.add(const LoggedIn(_user));
      await tester.pump();
      await tester.pump();

      expect(store.take(), 'abc');
      final spacesBloc = BlocProvider.of<SpacesBloc>(
        tester.element(find.byType(SizedBox)),
      );
      expect(spacesBloc.state.status, isNot(SpacesStatus.initial));
    });
  });
}
