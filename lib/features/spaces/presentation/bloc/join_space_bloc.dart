import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/failures.dart';
import '../../domain/usecases/join_space_invitation_usecase.dart';

part 'join_space_event.dart';
part 'join_space_state.dart';

class JoinSpaceBloc extends Bloc<JoinSpaceEvent, JoinSpaceState> {
  final JoinSpaceInvitationUseCase joinSpaceInvitationUseCase;

  JoinSpaceBloc({required this.joinSpaceInvitationUseCase})
    : super(const JoinSpaceState.initial()) {
    on<JoinSpaceSubmitted>(_onSubmitted);
  }

  Future<void> _onSubmitted(
    JoinSpaceSubmitted event,
    Emitter<JoinSpaceState> emit,
  ) async {
    if (state.status == JoinSpaceStatus.inProgress) return;

    // Always passing through `inProgress` makes every result a new state, so
    // two identical failures in a row both reach the page's listener.
    emit(const JoinSpaceState.inProgress());

    final result = await joinSpaceInvitationUseCase(token: event.token);
    if (isClosed) return;

    result.match(
      (failure) => emit(
        failure is SpaceConflictFailure
            ? JoinSpaceState.alreadyParticipant(failure.message)
            : JoinSpaceState.failure(failure.message),
      ),
      (spaceId) => emit(JoinSpaceState.success(spaceId)),
    );
  }
}
