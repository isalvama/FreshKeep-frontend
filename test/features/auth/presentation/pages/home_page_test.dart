import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:fresh_keep_frontend/core/errors/failures.dart';
import 'package:fresh_keep_frontend/features/auth/domain/repositories/auth_repository.dart';
import 'package:fresh_keep_frontend/features/auth/domain/usecases/check_auth_status_usecase.dart';
import 'package:fresh_keep_frontend/features/auth/domain/usecases/current_user_usecase.dart';
import 'package:fresh_keep_frontend/features/auth/domain/usecases/logout_usecase.dart';
import 'package:fresh_keep_frontend/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:fresh_keep_frontend/features/auth/presentation/pages/home_page.dart';
import 'package:fresh_keep_frontend/features/spaces/domain/entities/space.dart';
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
}

const _space = Space(
  id: 'space-1',
  spaceName: 'Kitchen',
  emoji: '🏠',
  storageSpots: [],
  creatorId: 'user-1',
  participantIds: ['user-1'],
);

Future<void> _pumpHomePage(WidgetTester tester, SpacesBloc spacesBloc) async {
  final authRepository = _UnusedAuthRepository();
  final authBloc = AuthBloc(
    checkAuthStatusUseCase: CheckAuthStatusUseCase(authRepository),
    currentUserUseCase: CurrentUserUseCase(authRepository),
    logoutUseCase: LogoutUseCase(authRepository),
  );
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
        _SequencedSpaceRepository([const Right([_space])]),
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
}
