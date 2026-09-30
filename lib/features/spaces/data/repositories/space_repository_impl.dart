import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../../domain/entities/space.dart';
import '../../domain/entities/space_invitation.dart';
import '../../domain/entities/storage_spot_input.dart';
import '../../domain/repositories/space_repository.dart';
import '../datasources/space_remote_datasource.dart';
import '../models/create_space_request_model.dart';
import '../models/storage_spot_request_model.dart';

class SpaceRepositoryImpl implements SpaceRepository {
  final SpaceRemoteDataSource remoteDataSource;

  const SpaceRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<SpaceFailure, Space>> createSpace({
    required String spaceName,
    required String emoji,
    required List<StorageSpotInput> storageSpots,
  }) async {
    try {
      final response = await remoteDataSource.createSpace(
        CreateSpaceRequestModel(
          spaceName: spaceName,
          emoji: emoji,
          storageSpots: storageSpots
              .map((spot) => StorageSpotRequestModel(name: spot.name, type: spot.type))
              .toList(),
        ),
      );
      return Right(response.toEntity());
    } on DioException catch (e) {
      return Left(_mapDioException(e));
    }
  }

  @override
  Future<Either<SpaceFailure, List<Space>>> getUserSpaces() async {
    try {
      final responses = await remoteDataSource.getSpaces();
      return Right(responses.map((response) => response.toEntity()).toList());
    } on DioException catch (e) {
      return Left(_mapDioException(e));
    }
  }

  @override
  Future<Either<SpaceFailure, SpaceInvitation>> createInvitation({
    required String spaceId,
  }) async {
    try {
      final response = await remoteDataSource.createInvitation(spaceId);
      return Right(response.toEntity());
    } on DioException catch (e) {
      return Left(_mapDioException(e));
    }
  }

  SpaceFailure _mapDioException(DioException e) {
    final status = e.response?.statusCode;
    final data = e.response?.data;
    final detail = data is Map ? data['detail'] as String? : null;

    switch (status) {
      case 400:
        return SpaceValidationFailure(detail ?? 'Please check the entered data.');
      case 401:
        return SpaceUnauthorizedFailure(
          detail ?? 'Your session has expired. Please log in again.',
        );
      case 403:
        return SpaceForbiddenFailure(
          detail ?? 'You are not allowed to perform this action.',
        );
      case 409:
        return SpaceConflictFailure(
          detail ?? "You're not a participant of this space.",
        );
      case 500:
        return SpaceServerFailure(
          detail ?? 'Something went wrong. Please try again.',
        );
      default:
        return SpaceNetworkFailure(
          e.message ?? 'Network error. Please check your connection.',
        );
    }
  }
}
