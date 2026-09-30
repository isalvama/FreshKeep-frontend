import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:go_router/go_router.dart';
import 'package:fresh_keep_frontend/core/errors/failures.dart';
import 'package:fresh_keep_frontend/features/auth/domain/repositories/auth_repository.dart';
import 'package:fresh_keep_frontend/features/auth/domain/usecases/check_auth_status_usecase.dart';
import 'package:fresh_keep_frontend/features/auth/domain/usecases/current_user_usecase.dart';
import 'package:fresh_keep_frontend/features/auth/domain/usecases/logout_usecase.dart';
import 'package:fresh_keep_frontend/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:fresh_keep_frontend/features/auth/presentation/pages/home_page.dart';
import 'package:fresh_keep_frontend/features/spaces/domain/entities/space.dart';
import 'package:fresh_keep_frontend/features/spaces/domain/entities/space_invitation.dart';
import 'package:fresh_keep_frontend/features/spaces/domain/entities/storage_spot_input.dart';
import 'package:fresh_keep_frontend/features/spaces/domain/repositories/space_repository.dart';
import 'package:fresh_keep_frontend/features/spaces/domain/usecases/get_user_spaces_usecase.dart';
import 'package:fresh_keep_frontend/features/spaces/presentation/bloc/spaces_bloc.dart';

class _UnusedAuthRepository implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _PendingSpaceRepository implements SpaceRepository {
  final Completer<Either<SpaceFailure, List<Space>>> completer = Completer();

  @override
  Future<Either<SpaceFailure, Space>> createSpace({
    required String spaceName,
    required String emoji,
    required List<StorageSpotInput> storageSpots,
  }) => throw UnimplementedError();

  @override
  Future<Either<SpaceFailure, List<Space>>> getUserSpaces() => completer.future;

  @override
  Future<Either<SpaceFailure, SpaceInvitation>> createInvitation({
    required String spaceId,
  }) => throw UnimplementedError();
}

/// Returns [results] in order, one per call, holding on the last entry once exhausted.
class _SequencedSpaceRepository implements SpaceRepository {
  _SequencedSpaceRepository(this.results);

  final List<Either<SpaceFailure, List<Space>>> results;
  int _callCount = 0;

  @override
  Future<Either<SpaceFailure, Space>> createSpace({
    required String spaceName,
    required String emoji,
    required List<StorageSpotInput> storageSpots,
  }) => throw UnimplementedError();

  @override
  Future<Either<SpaceFailure, List<Space>>> getUserSpaces() async {
    final result = results[_callCount];
    if (_callCount < results.length - 1) _callCount++;
    return result;
  }

  @override
  Future<Either<SpaceFailure, SpaceInvitation>> createInvitation({
    required String spaceId,
  }) => throw UnimplementedError();
}

/// One [Completer] per `getUserSpaces` call, so a test can hold the refresh
/// in flight and check what Home shows meanwhile.
class _ScriptedSpaceRepository implements SpaceRepository {
  final List<Completer<Either<SpaceFailure, List<Space>>>> calls = [];

  @override
  Future<Either<SpaceFailure, Space>> createSpace({
    required String spaceName,
    required String emoji,
    required List<StorageSpotInput> storageSpots,
  }) => throw UnimplementedError();

  @override
  Future<Either<SpaceFailure, List<Space>>> getUserSpaces() {
    final completer = Completer<Either<SpaceFailure, List<Space>>>();
    calls.add(completer);
    return completer.future;
  }

  @override
  Future<Either<SpaceFailure, SpaceInvitation>> createInvitation({
    required String spaceId,
  }) => throw UnimplementedError();
}

const _cabin = Space(
  id: 'space-2',
  spaceName: 'Cabin',
  emoji: '🏕️',
  storageSpots: [],
  creatorId: 'user-2',
  participantIds: ['user-1', 'user-2'],
);

const _space = Space(
  id: 'space-1',
  spaceName: 'Kitchen',
  emoji: '🏠',
  storageSpots: [],
  creatorId: 'user-1',
  participantIds: ['user-1'],
);

AuthBloc _buildAuthBloc() {
  final authRepository = _UnusedAuthRepository();
  return AuthBloc(
    checkAuthStatusUseCase: CheckAuthStatusUseCase(authRepository),
    currentUserUseCase: CurrentUserUseCase(authRepository),
    logoutUseCase: LogoutUseCase(authRepository),
  );
}

Future<void> _pumpHomePage(WidgetTester tester, SpacesBloc spacesBloc) async {
  final authBloc = _buildAuthBloc();
  await tester.pumpWidget(
    // Providers sit above MaterialApp, mirroring app.dart's actual structure —
    // showModalBottomSheet pushes its content as a sibling overlay route on the
    // Navigator, not a descendant of whatever's inside `home:`, so any provider
    // a modal sheet needs must be an ancestor of the Navigator itself.
    MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>.value(value: authBloc),
        BlocProvider<SpacesBloc>.value(value: spacesBloc),
      ],
      child: const MaterialApp(home: HomePage()),
    ),
  );
}

/// Home under GoRouter, with a stand-in overview page that shows the path
/// parameter and the `Space` it received as `extra`.
Future<GoRouter> _pumpHomeWithRouter(
  WidgetTester tester,
  SpacesBloc spacesBloc,
) async {
  final router = GoRouter(
    initialLocation: '/home',
    routes: [
      GoRoute(path: '/home', builder: (context, state) => const HomePage()),
      GoRoute(
        path: '/space-overview/:spaceId',
        builder: (context, state) {
          final space = state.extra as Space?;
          return Scaffold(
            appBar: AppBar(title: const Text('Overview stub')),
            body: Column(
              children: [
                Text('id: ${state.pathParameters['spaceId']}'),
                Text('extra: ${space?.spaceName}'),
              ],
            ),
          );
        },
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>.value(value: _buildAuthBloc()),
        BlocProvider<SpacesBloc>.value(value: spacesBloc),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  return router;
}

void main() {
  testWidgets('shows a loading indicator while the fetch is in flight', (
    tester,
  ) async {
    final spacesBloc = SpacesBloc(
      getUserSpacesUseCase: GetUserSpacesUseCase(_PendingSpaceRepository()),
    );
    spacesBloc.add(const SpacesRequested());

    await _pumpHomePage(tester, spacesBloc);
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('shows the fetched spaces once loaded', (tester) async {
    final spacesBloc = SpacesBloc(
      getUserSpacesUseCase: GetUserSpacesUseCase(
        _SequencedSpaceRepository([
          const Right([_space]),
        ]),
      ),
    );
    spacesBloc.add(const SpacesRequested());

    await _pumpHomePage(tester, spacesBloc);
    await tester.pumpAndSettle();

    expect(find.text('Kitchen'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });

  testWidgets('shows "No spaces yet." when loaded with an empty list', (
    tester,
  ) async {
    final spacesBloc = SpacesBloc(
      getUserSpacesUseCase: GetUserSpacesUseCase(
        _SequencedSpaceRepository([const Right([])]),
      ),
    );
    spacesBloc.add(const SpacesRequested());

    await _pumpHomePage(tester, spacesBloc);
    await tester.pumpAndSettle();

    expect(find.text('No spaces yet.'), findsOneWidget);
  });

  testWidgets(
    'shows an error and a Retry button on failure, which re-fetches successfully',
    (tester) async {
      final spacesBloc = SpacesBloc(
        getUserSpacesUseCase: GetUserSpacesUseCase(
          _SequencedSpaceRepository([
            const Left(SpaceNetworkFailure('Network error.')),
            const Right([_space]),
          ]),
        ),
      );
      spacesBloc.add(const SpacesRequested());

      await _pumpHomePage(tester, spacesBloc);
      await tester.pumpAndSettle();

      expect(find.text('Network error.'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Retry'), findsOneWidget);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Retry'));
      await tester.pumpAndSettle();

      expect(find.text('Kitchen'), findsOneWidget);
      expect(find.text('Network error.'), findsNothing);
    },
  );

  testWidgets(
    'tapping the FAB opens the creation bottom sheet; "Process a New Receipt" '
    'is hidden when the user has no spaces',
    (tester) async {
      final spacesBloc = SpacesBloc(
        getUserSpacesUseCase: GetUserSpacesUseCase(
          _SequencedSpaceRepository([const Right([])]),
        ),
      );
      spacesBloc.add(const SpacesRequested());

      await _pumpHomePage(tester, spacesBloc);
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      expect(find.text('Create a New Space'), findsOneWidget);
      expect(find.text('Process a New Receipt'), findsNothing);
    },
  );

  group('opening a space', () {
    testWidgets('every space tile shows a trailing chevron', (tester) async {
      final spacesBloc = SpacesBloc(
        getUserSpacesUseCase: GetUserSpacesUseCase(
          _SequencedSpaceRepository([
            const Right([_space, _cabin]),
          ]),
        ),
      );
      spacesBloc.add(const SpacesRequested());

      await _pumpHomePage(tester, spacesBloc);
      await tester.pumpAndSettle();

      for (final name in ['Kitchen', 'Cabin']) {
        expect(
          find.descendant(
            of: find.widgetWithText(ListTile, name),
            matching: find.byIcon(Icons.chevron_right),
          ),
          findsOneWidget,
        );
      }
    });

    testWidgets(
      'tapping a tile pushes /space-overview/<id> with the Space as extra',
      (tester) async {
        final spacesBloc = SpacesBloc(
          getUserSpacesUseCase: GetUserSpacesUseCase(
            _SequencedSpaceRepository([
              const Right([_space, _cabin]),
            ]),
          ),
        );
        spacesBloc.add(const SpacesRequested());

        final router = await _pumpHomeWithRouter(tester, spacesBloc);
        await tester.pumpAndSettle();

        await tester.tap(find.text('Cabin'));
        await tester.pumpAndSettle();

        expect(find.text('id: space-2'), findsOneWidget);
        expect(find.text('extra: Cabin'), findsOneWidget);
        // A pushed route is the configuration's last match; `uri` stays at
        // the base location (/home).
        expect(
          router.routerDelegate.currentConfiguration.last.matchedLocation,
          '/space-overview/space-2',
        );
        // Pushed, not replaced: Home is still underneath.
        expect(router.canPop(), isTrue);
      },
    );

    testWidgets(
      'coming back refreshes the list once, without ever showing a spinner',
      (tester) async {
        final repository = _ScriptedSpaceRepository();
        final spacesBloc = SpacesBloc(
          getUserSpacesUseCase: GetUserSpacesUseCase(repository),
        );
        spacesBloc.add(const SpacesRequested());

        await _pumpHomeWithRouter(tester, spacesBloc);
        await tester.pump();
        repository.calls.single.complete(const Right([_space]));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Kitchen'));
        await tester.pumpAndSettle();
        expect(repository.calls, hasLength(1));

        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();

        // The refresh is in flight: the old list stays, no spinner.
        expect(repository.calls, hasLength(2));
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.text('Kitchen'), findsOneWidget);

        repository.calls.last.complete(const Right([_space, _cabin]));
        await tester.pumpAndSettle();

        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.text('Kitchen'), findsOneWidget);
        expect(find.text('Cabin'), findsOneWidget);
        expect(repository.calls, hasLength(2));
      },
    );

    testWidgets(
      'a failed refresh on return keeps the list, with no error or Retry',
      (tester) async {
        final repository = _ScriptedSpaceRepository();
        final spacesBloc = SpacesBloc(
          getUserSpacesUseCase: GetUserSpacesUseCase(repository),
        );
        spacesBloc.add(const SpacesRequested());

        await _pumpHomeWithRouter(tester, spacesBloc);
        await tester.pump();
        repository.calls.single.complete(const Right([_space]));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Kitchen'));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();

        repository.calls.last.complete(
          const Left(SpaceNetworkFailure('Network error.')),
        );
        await tester.pumpAndSettle();

        expect(repository.calls, hasLength(2));
        expect(find.text('Kitchen'), findsOneWidget);
        expect(find.text('Network error.'), findsNothing);
        expect(find.widgetWithText(ElevatedButton, 'Retry'), findsNothing);
      },
    );
  });
}
