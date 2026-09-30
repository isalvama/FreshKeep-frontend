import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../entities/space_invitation.dart';
import '../repositories/space_repository.dart';

class CreateSpaceInvitationUseCase {
  final SpaceRepository repository;

  const CreateSpaceInvitationUseCase(this.repository);

  Future<Either<SpaceFailure, SpaceInvitation>> call({
    required String spaceId,
  }) => repository.createInvitation(spaceId: spaceId);
}
