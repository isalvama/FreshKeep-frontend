import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:fresh_keep_frontend/core/errors/failures.dart';
import 'package:fresh_keep_frontend/features/spaces/domain/entities/space.dart';
import 'package:fresh_keep_frontend/features/spaces/domain/entities/space_invitation.dart';
import 'package:fresh_keep_frontend/features/spaces/domain/entities/storage_spot_input.dart';
import 'package:fresh_keep_frontend/features/spaces/domain/repositories/space_repository.dart';
import 'package:fresh_keep_frontend/features/spaces/domain/usecases/get_user_spaces_usecase.dart';
import 'package:fresh_keep_frontend/features/spaces/domain/usecases/join_space_invitation_usecase.dart';
import 'package:fresh_keep_frontend/features/spaces/presentation/bloc/join_space_bloc.dart';
import 'package:fresh_keep_frontend/features/spaces/presentation/bloc/spaces_bloc.dart';
import 'package:fresh_keep_frontend/features/spaces/presentation/pages/join_space_page.dart';
import 'package:go_router/go_router.dart';

/// Answers `joinInvitation` with [result], or waits on [pending] when it is
/// `null`; counts `getUserSpaces` calls to observe `SpacesRefreshed`.
class _JoinRepository implements SpaceRepository {
  _JoinRepository([this.result]);

  final Either<SpaceFailure, String>? result;
  Completer<Either<SpaceFailure, String>>? pending;
  final List<String> joinCalls = [];
  int spacesCalls = 0;

  @override
  Future<Either<SpaceFailure, String>> joinInvitation({required String token}) {
    joinCalls.add(token);
    // Created on the call so it completes inside the test's fake-async zone.
    return result != null
        ? Future.value(result)
        : (pending = Completer()).future;
  }

  @override
  Future<Either<SpaceFailure, List<Space>>> getUserSpaces() async {
    spacesCalls++;
    return const Right([]);
  }

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

Widget _placeholder(String text) =>
    Scaffold(appBar: AppBar(), body: Text(text));

/// Pumps an app whose `/join` route mirrors the real one, starting at
/// [initialLocation], and returns its router.
Future<GoRouter> _pumpApp(
  WidgetTester tester,
  _JoinRepository repository, {
  String initialLocation = '/join?token=abc',
}) async {
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(path: '/home', builder: (_, _) => _placeholder('Home')),
      GoRoute(path: '/other', builder: (_, _) => _placeholder('Other')),
      GoRoute(
        path: '/join',
        builder: (_, state) => BlocProvider(
          create: (_) => JoinSpaceBloc(
            joinSpaceInvitationUseCase: JoinSpaceInvitationUseCase(repository),
          ),
          child: JoinSpacePage(token: state.uri.queryParameters['token'] ?? ''),
        ),
      ),
      GoRoute(
        path: '/space-overview/:spaceId',
        builder: (_, state) =>
            _placeholder('Overview ${state.pathParameters['spaceId']}'),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    BlocProvider(
      create: (_) =>
          SpacesBloc(getUserSpacesUseCase: GetUserSpacesUseCase(repository)),
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

void main() {
  testWidgets('shows the invitation with Join and Cancel, and does not call '
      'the backend until Join is tapped', (tester) async {
    final repository = _JoinRepository(const Right('space-9'));
    await _pumpApp(tester, repository);

    expect(find.byIcon(Icons.group_add), findsOneWidget);
    expect(find.text("You've been invited to join a space"), findsOneWidget);
    expect(find.text('Join'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(repository.joinCalls, isEmpty);
  });

  testWidgets('while joining, a spinner replaces the buttons', (tester) async {
    final repository = _JoinRepository();
    await _pumpApp(tester, repository);

    await tester.tap(find.text('Join'));
    await tester.pump();

    expect(repository.joinCalls, ['abc']);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Join'), findsNothing);
    expect(find.text('Cancel'), findsNothing);

    repository.pending!.complete(const Right('space-9'));
    await tester.pumpAndSettle();
  });

  testWidgets('success refreshes the spaces and lands on the overview, with '
      'Home underneath', (tester) async {
    final repository = _JoinRepository(const Right('space-9'));
    final router = await _pumpApp(tester, repository);

    await tester.tap(find.text('Join'));
    await tester.pumpAndSettle();

    expect(find.text('Overview space-9'), findsOneWidget);
    expect(repository.spacesCalls, 1);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsOneWidget);
    expect(router.canPop(), isFalse);
  });

  testWidgets('already a participant lands on Home with the SnackBar', (
    tester,
  ) async {
    final repository = _JoinRepository(
      const Left(SpaceConflictFailure("You're already in this space.")),
    );
    final router = await _pumpApp(tester, repository);

    await tester.tap(find.text('Join'));
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsOneWidget);
    expect(find.text("You're already in this space."), findsOneWidget);
    expect(router.canPop(), isFalse);
    expect(repository.spacesCalls, 0);
  });

  testWidgets('any other failure shows the message and Go to Home', (
    tester,
  ) async {
    final repository = _JoinRepository(
      const Left(
        SpaceValidationFailure('This invitation is invalid or has expired.'),
      ),
    );
    await _pumpApp(tester, repository);

    await tester.tap(find.text('Join'));
    await tester.pumpAndSettle();

    expect(
      find.text('This invitation is invalid or has expired.'),
      findsOneWidget,
    );
    expect(find.text('Join'), findsNothing);

    await tester.tap(find.text('Go to Home'));
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsOneWidget);
  });

  for (final location in ['/join', '/join?token=']) {
    testWidgets('an empty token ($location) shows the invalid link and never '
        'calls the backend', (tester) async {
      final repository = _JoinRepository(const Right('space-9'));
      await _pumpApp(tester, repository, initialLocation: location);

      expect(find.text('This invitation link is invalid.'), findsOneWidget);
      expect(find.text('Join'), findsNothing);

      await tester.tap(find.text('Go to Home'));
      await tester.pumpAndSettle();

      expect(find.text('Home'), findsOneWidget);
      expect(repository.joinCalls, isEmpty);
    });
  }

  testWidgets('Cancel returns to the previous page when there is one', (
    tester,
  ) async {
    final repository = _JoinRepository(const Right('space-9'));
    final router = await _pumpApp(
      tester,
      repository,
      initialLocation: '/other',
    );

    router.push('/join?token=abc');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Other'), findsOneWidget);
    expect(repository.joinCalls, isEmpty);
  });

  testWidgets('Cancel goes to Home when there is nothing to go back to', (
    tester,
  ) async {
    final repository = _JoinRepository(const Right('space-9'));
    await _pumpApp(tester, repository);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsOneWidget);
    expect(repository.joinCalls, isEmpty);
  });
}
