import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../../domain/entities/space_overview.dart';
import '../../domain/repositories/space_overview_repository.dart';
import '../datasources/space_overview_remote_datasource.dart';

class SpaceOverviewRepositoryImpl implements SpaceOverviewRepository {
  final SpaceOverviewRemoteDataSource remoteDataSource;

  const SpaceOverviewRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<SpaceOverviewFailure, SpaceOverview>> getSpaceOverview({
    required String spaceId,
  }) async {
    try {
      final response = await remoteDataSource.getSpaceOverview(
        spaceId: spaceId,
      );
      return Right(response.toEntity());
    } on DioException catch (e) {
      return Left(_mapDioException(e));
    }
  }

  SpaceOverviewFailure _mapDioException(DioException e) {
    final status = e.response?.statusCode;
    final data = e.response?.data;
    final detail = data is Map ? data['detail'] as String? : null;

    switch (status) {
      case 400:
        return SpaceOverviewValidationFailure(
          detail ?? 'This space could not be found.',
        );
      case 401:
        return SpaceOverviewUnauthorizedFailure(
          detail ?? 'Your session has expired. Please log in again.',
        );
      case 403:
        return SpaceOverviewForbiddenFailure(
          detail ?? 'You are not allowed to perform this action.',
        );
      case 409:
        return SpaceOverviewConflictFailure(
          detail ?? 'You are not a participant of this space.',
        );
      default:
        return SpaceOverviewNetworkFailure(
          e.message ?? 'Network error. Please check your connection.',
        );
    }
  }
}
