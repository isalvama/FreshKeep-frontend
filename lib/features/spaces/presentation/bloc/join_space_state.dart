part of 'join_space_bloc.dart';

enum JoinSpaceStatus {
  initial,
  inProgress,
  success,
  alreadyParticipant,
  failure,
}

class JoinSpaceState extends Equatable {
  final JoinSpaceStatus status;

  /// Set on success.
  final String? spaceId;

  /// Set on failure and alreadyParticipant.
  final String? errorMessage;

  const JoinSpaceState._({
    required this.status,
    this.spaceId,
    this.errorMessage,
  });

  const JoinSpaceState.initial() : this._(status: JoinSpaceStatus.initial);

  const JoinSpaceState.inProgress()
    : this._(status: JoinSpaceStatus.inProgress);

  const JoinSpaceState.success(String spaceId)
    : this._(status: JoinSpaceStatus.success, spaceId: spaceId);

  const JoinSpaceState.alreadyParticipant(String message)
    : this._(status: JoinSpaceStatus.alreadyParticipant, errorMessage: message);

  const JoinSpaceState.failure(String message)
    : this._(status: JoinSpaceStatus.failure, errorMessage: message);

  @override
  List<Object?> get props => [status, spaceId, errorMessage];
}
