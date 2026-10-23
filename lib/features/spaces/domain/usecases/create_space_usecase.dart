import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../entities/space.dart';
import '../entities/storage_spot_input.dart';
import '../repositories/space_repository.dart';

class CreateSpaceUseCase {
  final SpaceRepository repository;

  const CreateSpaceUseCase(this.repository);

  Future<Either<SpaceFailure, Space>> call({
    required String spaceName,
    required String emoji,
    required List<StorageSpotInput> storageSpots,
  }) {
    return repository.createSpace(
      spaceName: spaceName,
      emoji: emoji,
      storageSpots: storageSpots,
    );
  }
}
