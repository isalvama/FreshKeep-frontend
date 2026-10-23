import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fresh_keep_frontend/core/theme/app_theme.dart';
import 'package:fpdart/fpdart.dart';
import 'package:fresh_keep_frontend/core/errors/failures.dart';
import 'package:fresh_keep_frontend/features/space_overview/domain/entities/move_destination.dart';
import 'package:fresh_keep_frontend/features/space_overview/presentation/widgets/move_destination_sheet.dart';
import 'package:fresh_keep_frontend/features/spaces/domain/entities/space.dart';
import 'package:fresh_keep_frontend/features/spaces/domain/entities/space_invitation.dart';
import 'package:fresh_keep_frontend/features/spaces/domain/entities/storage_spot.dart';
import 'package:fresh_keep_frontend/features/spaces/domain/entities/storage_spot_input.dart';
import 'package:fresh_keep_frontend/features/spaces/domain/entities/storage_spot_type.dart';
import 'package:fresh_keep_frontend/features/spaces/domain/repositories/space_repository.dart';
import 'package:fresh_keep_frontend/features/spaces/domain/usecases/get_user_spaces_usecase.dart';
import 'package:fresh_keep_frontend/features/spaces/presentation/bloc/spaces_bloc.dart';

/// Answers each `getUserSpaces` call with the next entry of [results]; a
/// `null` entry waits on [pending].
class _SpaceRepository implements SpaceRepository {
  _SpaceRepository(this.results);

  final List<Either<SpaceFailure, List<Space>>?> results;
  final Completer<Either<SpaceFailure, List<Space>>> pending = Completer();
  int calls = 0;

  @override
  Future<Either<SpaceFailure, List<Space>>> getUserSpaces() async {
    final result = results[calls++];
    return result ?? pending.future;
  }

  @override
  Future<Either<SpaceFailure, Space>> createSpace({
    required String spaceName,
    required String emoji,
    required List<StorageSpotInput> storageSpots,
  }) => throw UnimplementedError();

  @override
  Future<Either<SpaceFailure, String>> joinInvitation({
    required String token,
  }) => throw UnimplementedError();

  @override
  Future<Either<SpaceFailure, SpaceInvitation>> createInvitation({
    required String spaceId,
  }) => throw UnimplementedError();
}

Space _space(String id, String name, String emoji, List<StorageSpot> spots) =>
    Space(
      id: id,
      spaceName: name,
      emoji: emoji,
      storageSpots: spots,
      creatorId: 'user-1',
      participantIds: const ['user-1'],
    );

final _garage = _space('space-2', 'Garage', '🚗', const [
  StorageSpot(id: 'spot-x', name: 'Chest', type: StorageSpotType.freezer),
]);
final _empty = _space('space-3', 'Attic', '📦', const []);
final _kitchen = _space('space-1', 'Kitchen', '🏠', const [
  StorageSpot(id: 'spot-a', name: 'Main fridge', type: StorageSpotType.fridge),
  StorageSpot(
    id: 'spot-b',
    name: 'Top shelf',
    type: StorageSpotType.wineCellar,
  ),
]);

/// Pumps a page with a button that opens the sheet for a product in
/// `spot-a` of `space-1`; the sheet's result lands in [results].
Future<void> _pumpOpener(
  WidgetTester tester,
  SpacesBloc bloc,
  List<MoveDestination?> results,
) async {
  await tester.pumpWidget(
    BlocProvider<SpacesBloc>.value(
      value: bloc,
      child: MaterialApp(
        // The app's theme: its list tile title style differs from the 18px
        // one the space rows use, which once broke switching levels.
        theme: AppTheme.light,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async => results.add(
                await showMoveDestinationSheet(
                  context,
                  currentSpaceId: 'space-1',
                  currentStorageSpotId: 'spot-a',
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
}

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

/// A bloc that will hold [_garage], [_empty] and [_kitchen] once its
/// request resolves during the next pump.
(SpacesBloc, _SpaceRepository) _loadingBloc() {
  final repository = _SpaceRepository([
    Right([_garage, _empty, _kitchen]),
  ]);
  final bloc = SpacesBloc(
    getUserSpacesUseCase: GetUserSpacesUseCase(repository),
  );
  bloc.add(const SpacesRequested());
  return (bloc, repository);
}

void main() {
  testWidgets('lists spaces with spots, the current one first and labelled, '
      'without reloading an already loaded bloc', (tester) async {
    final (bloc, repository) = _loadingBloc();
    await _pumpOpener(tester, bloc, []);
    await _open(tester);

    expect(find.text('Move to'), findsOneWidget);
    expect(find.text('Kitchen (current)'), findsOneWidget);
    expect(find.text('Garage'), findsOneWidget);
    expect(find.text('🏠'), findsOneWidget);
    expect(find.text('🚗'), findsOneWidget);
    expect(find.text('Attic'), findsNothing);
    expect(
      tester.getTopLeft(find.text('Kitchen (current)')).dy,
      lessThan(tester.getTopLeft(find.text('Garage')).dy),
    );
    expect(repository.calls, 1);
  });

  testWidgets('tapping a space shows its spots with type labels; the current '
      'spot is disabled and tagged', (tester) async {
    final (bloc, _) = _loadingBloc();
    final results = <MoveDestination?>[];
    await _pumpOpener(tester, bloc, results);
    await _open(tester);

    await tester.tap(find.text('Kitchen (current)'));
    await tester.pumpAndSettle();

    expect(find.text('Kitchen'), findsOneWidget);
    expect(find.text('Main fridge'), findsOneWidget);
    expect(find.text('Fridge'), findsOneWidget);
    expect(find.text('Top shelf'), findsOneWidget);
    expect(find.text('Wine Cellar'), findsOneWidget);
    expect(find.text('Current'), findsOneWidget);
    final current = tester.widget<ListTile>(
      find.ancestor(
        of: find.text('Main fridge'),
        matching: find.byType(ListTile),
      ),
    );
    expect(current.enabled, isFalse);

    await tester.tap(find.text('Main fridge'));
    await tester.pumpAndSettle();
    expect(results, isEmpty);
    expect(find.text('Main fridge'), findsOneWidget);
  });

  testWidgets('back returns to the space list', (tester) async {
    final (bloc, _) = _loadingBloc();
    await _pumpOpener(tester, bloc, []);
    await _open(tester);

    await tester.tap(find.text('Garage'));
    await tester.pumpAndSettle();
    expect(find.text('Chest'), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    expect(find.text('Chest'), findsNothing);
    expect(find.text('Move to'), findsOneWidget);
    expect(find.text('Garage'), findsOneWidget);
  });

  testWidgets('tapping a spot closes the sheet with the destination', (
    tester,
  ) async {
    final (bloc, _) = _loadingBloc();
    final results = <MoveDestination?>[];
    await _pumpOpener(tester, bloc, results);
    await _open(tester);

    await tester.tap(find.text('Garage'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chest'));
    await tester.pumpAndSettle();

    expect(results, const [
      MoveDestination(
        spaceId: 'space-2',
        spaceName: 'Garage',
        storageSpotId: 'spot-x',
        storageSpotName: 'Chest',
      ),
    ]);
    expect(find.text('Move to'), findsNothing);
  });

  testWidgets('dismissing the sheet returns null', (tester) async {
    final (bloc, _) = _loadingBloc();
    final results = <MoveDestination?>[];
    await _pumpOpener(tester, bloc, results);
    await _open(tester);

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(results, [null]);
    expect(find.text('Move to'), findsNothing);
  });

  testWidgets('with spaces not loaded yet, requests them and shows a spinner '
      'until they arrive', (tester) async {
    final repository = _SpaceRepository([null]);
    final bloc = SpacesBloc(
      getUserSpacesUseCase: GetUserSpacesUseCase(repository),
    );
    await _pumpOpener(tester, bloc, []);

    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(repository.calls, 1);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    repository.pending.complete(Right([_kitchen]));
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Kitchen (current)'), findsOneWidget);
  });

  testWidgets('after a load failure, requests again on open, shows the '
      'message and retries', (tester) async {
    const failure = Left<SpaceFailure, List<Space>>(
      SpaceServerFailure('Could not load spaces.'),
    );
    final repository = _SpaceRepository([
      failure,
      failure,
      Right([_kitchen]),
    ]);
    final bloc = SpacesBloc(
      getUserSpacesUseCase: GetUserSpacesUseCase(repository),
    );
    bloc.add(const SpacesRequested());
    await _pumpOpener(tester, bloc, []);
    expect(bloc.state.status, SpacesStatus.loadFailure);
    await _open(tester);

    expect(repository.calls, 2);
    expect(find.text('Could not load spaces.'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(repository.calls, 3);
    expect(find.text('Kitchen (current)'), findsOneWidget);
  });
}
