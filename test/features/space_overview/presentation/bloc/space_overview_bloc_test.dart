import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:fresh_keep_frontend/core/errors/failures.dart';
import 'package:fresh_keep_frontend/features/space_overview/domain/entities/space_overview.dart';
import 'package:fresh_keep_frontend/features/space_overview/domain/repositories/space_overview_repository.dart';
import 'package:fresh_keep_frontend/features/space_overview/domain/usecases/get_space_overview_usecase.dart';
import 'package:fresh_keep_frontend/features/space_overview/presentation/bloc/space_overview_bloc.dart';

class _StubSpaceOverviewRepository implements SpaceOverviewRepository {
  _StubSpaceOverviewRepository(this.result);

  final Either<SpaceOverviewFailure, SpaceOverview> result;

  @override
  Future<Either<SpaceOverviewFailure, SpaceOverview>> getSpaceOverview({
    required String spaceId,
  }) async => result;
}

const _overview = SpaceOverview(
  id: 'space-1',
  name: 'Kitchen',
  emoji: '🏠',
  storageSpots: [],
  productResults: [],
);

SpaceOverviewBloc _buildBloc(
  Either<SpaceOverviewFailure, SpaceOverview> result,
) {
  return SpaceOverviewBloc(
    getSpaceOverviewUseCase: GetSpaceOverviewUseCase(
      _StubSpaceOverviewRepository(result),
    ),
  );
}

void main() {
  test('initial status is SpaceOverviewInitial', () {
    final bloc = _buildBloc(const Right(_overview));

    expect(bloc.state.status, isA<SpaceOverviewInitial>());

    bloc.close();
  });

  test(
    'SpaceOverviewRequested emits Loading then LoadSuccess on success',
    () async {
      final bloc = _buildBloc(const Right(_overview));
      final emittedStatuses = <Object>[];
      final subscription = bloc.stream.listen(
        (state) => emittedStatuses.add(state.status),
      );

      bloc.add(const SpaceOverviewRequested('space-1'));

      await bloc.stream.firstWhere(
        (state) => state.status is SpaceOverviewLoadSuccess,
      );

      expect(emittedStatuses.whereType<SpaceOverviewLoading>(), hasLength(1));
      final successStatus =
          emittedStatuses.last as SpaceOverviewLoadSuccess;
      expect(successStatus.overview, _overview);

      await subscription.cancel();
      await bloc.close();
    },
  );

  test(
    'SpaceOverviewRequested emits Loading then LoadFailure on failure',
    () async {
      const failure = SpaceOverviewConflictFailure(
        'You are not a participant of this space.',
      );
      final bloc = _buildBloc(const Left(failure));
      final emittedStatuses = <Object>[];
      final subscription = bloc.stream.listen(
        (state) => emittedStatuses.add(state.status),
      );

      bloc.add(const SpaceOverviewRequested('space-1'));

      await bloc.stream.firstWhere(
        (state) => state.status is SpaceOverviewLoadFailure,
      );

      expect(emittedStatuses.whereType<SpaceOverviewLoading>(), hasLength(1));
      final failureStatus =
          emittedStatuses.last as SpaceOverviewLoadFailure;
      expect(failureStatus.message, failure.message);

      await subscription.cancel();
      await bloc.close();
    },
  );
}
