import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../entities/space_overview.dart';
import '../repositories/space_overview_repository.dart';

class GetSpaceOverviewUseCase {
  final SpaceOverviewRepository repository;

  const GetSpaceOverviewUseCase(this.repository);

  Future<Either<SpaceOverviewFailure, SpaceOverview>> call({
    required String spaceId,
  }) => repository.getSpaceOverview(spaceId: spaceId);
}
