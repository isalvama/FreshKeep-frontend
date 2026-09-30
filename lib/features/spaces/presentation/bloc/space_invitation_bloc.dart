import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/space_invitation.dart';
import '../../domain/usecases/create_space_invitation_usecase.dart';

part 'space_invitation_event.dart';
part 'space_invitation_state.dart';

class SpaceInvitationBloc
    extends Bloc<SpaceInvitationEvent, SpaceInvitationState> {
  final CreateSpaceInvitationUseCase createSpaceInvitationUseCase;

  SpaceInvitationBloc({required this.createSpaceInvitationUseCase})
    : super(const SpaceInvitationState.initial()) {
    on<SpaceInvitationRequested>(_onRequested);
  }

  Future<void> _onRequested(
    SpaceInvitationRequested event,
    Emitter<SpaceInvitationState> emit,
  ) async {
    if (state.status == SpaceInvitationStatus.inProgress) return;

    // Always passing through `inProgress` makes every result a new state, so
    // two identical failures in a row both reach the page's listener.
    emit(const SpaceInvitationState.inProgress());

    final result = await createSpaceInvitationUseCase(spaceId: event.spaceId);
    if (isClosed) return;

    result.match(
      (failure) => emit(SpaceInvitationState.failure(failure.message)),
      (invitation) => emit(SpaceInvitationState.success(invitation)),
    );
  }
}
