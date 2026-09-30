import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:fresh_keep_frontend/core/errors/failures.dart';
import 'package:fresh_keep_frontend/features/spaces/domain/entities/space.dart';
import 'package:fresh_keep_frontend/features/spaces/domain/entities/space_invitation.dart';
import 'package:fresh_keep_frontend/features/spaces/domain/entities/storage_spot_input.dart';
import 'package:fresh_keep_frontend/features/spaces/domain/repositories/space_repository.dart';
import 'package:fresh_keep_frontend/features/spaces/domain/usecases/get_user_spaces_usecase.dart';
import 'package:fresh_keep_frontend/features/spaces/presentation/bloc/spaces_bloc.dart';

/// Returns [results] in order, one per `getUserSpaces` call.
class _SequencedSpaceRepository implements SpaceRepository {
  _SequencedSpaceRepository(this.results);

  final List<Either<SpaceFailure, List<Space>>> results;
  int _calls = 0;

  @override
  Future<Either<SpaceFailure, List<Space>>> getUserSpaces() async =>
      results[_calls++];

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

const _kitchen = Space(
  id: 'space-1',
  spaceName: 'Kitchen',
  emoji: '🏠',
  storageSpots: [],
  creatorId: 'user-1',
  participantIds: ['user-1'],
);

const _cabin = Space(
  id: 'space-2',
  spaceName: 'Cabin',
  emoji: '🏕️',
  storageSpots: [],
  creatorId: 'user-2',
  participantIds: ['user-1', 'user-2'],
);

const _failure = SpaceServerFailure('Something went wrong.');

SpacesBloc _buildBloc(List<Either<SpaceFailure, List<Space>>> results) {
  return SpacesBloc(
    getUserSpacesUseCase: GetUserSpacesUseCase(
      _SequencedSpaceRepository(results),
    ),
  );
}

/// Lets the stubbed use case resolve and the handler emit.
Future<void> _settle() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  group('SpacesRequested', () {
    test('emits loading then loaded on success', () async {
      final bloc = _buildBloc([
        const Right([_kitchen]),
      ]);
      final emitted = <SpacesState>[];
      final subscription = bloc.stream.listen(emitted.add);

      bloc.add(const SpacesRequested());
      await _settle();

      expect(emitted.map((s) => s.status), [
        SpacesStatus.loading,
        SpacesStatus.loaded,
      ]);
      expect(emitted.last.spaces, [_kitchen]);

      await subscription.cancel();
      await bloc.close();
    });

    test('emits loading then loadFailure on failure', () async {
      final bloc = _buildBloc([const Left(_failure)]);
      final emitted = <SpacesState>[];
      final subscription = bloc.stream.listen(emitted.add);

      bloc.add(const SpacesRequested());
      await _settle();

      expect(emitted.map((s) => s.status), [
        SpacesStatus.loading,
        SpacesStatus.loadFailure,
      ]);
      expect(emitted.last.errorMessage, _failure.message);

      await subscription.cancel();
      await bloc.close();
    });
  });

  group('SpacesRefreshed', () {
    test(
      'from loaded, a successful refresh emits only the new loaded state',
      () async {
        final bloc = _buildBloc([
          const Right([_kitchen]),
          const Right([_kitchen, _cabin]),
        ]);
        bloc.add(const SpacesRequested());
        await _settle();
        expect(bloc.state.status, SpacesStatus.loaded);

        final emitted = <SpacesState>[];
        final subscription = bloc.stream.listen(emitted.add);

        bloc.add(const SpacesRefreshed());
        await _settle();

        expect(emitted, hasLength(1));
        expect(emitted.single.status, SpacesStatus.loaded);
        expect(emitted.single.spaces, [_kitchen, _cabin]);
        expect(emitted.single.errorMessage, isNull);

        await subscription.cancel();
        await bloc.close();
      },
    );

    test(
      'from loaded, a failed refresh emits nothing and keeps the list',
      () async {
        final bloc = _buildBloc([
          const Right([_kitchen]),
          const Left(_failure),
        ]);
        bloc.add(const SpacesRequested());
        await _settle();
        final before = bloc.state;

        final emitted = <SpacesState>[];
        final subscription = bloc.stream.listen(emitted.add);

        bloc.add(const SpacesRefreshed());
        await _settle();

        expect(emitted, isEmpty);
        expect(bloc.state, before);

        await subscription.cancel();
        await bloc.close();
      },
    );

    test('from loadFailure, a successful refresh emits loaded and clears the '
        'error message', () async {
      final bloc = _buildBloc([
        const Left(_failure),
        const Right([_kitchen]),
      ]);
      bloc.add(const SpacesRequested());
      await _settle();
      expect(bloc.state.status, SpacesStatus.loadFailure);

      final emitted = <SpacesState>[];
      final subscription = bloc.stream.listen(emitted.add);

      bloc.add(const SpacesRefreshed());
      await _settle();

      expect(emitted.map((s) => s.status), [SpacesStatus.loaded]);
      expect(bloc.state.spaces, [_kitchen]);
      expect(bloc.state.errorMessage, isNull);

      await subscription.cancel();
      await bloc.close();
    });
  });
}
