part of 'space_invitation_bloc.dart';

enum SpaceInvitationStatus { initial, inProgress, success, failure }

class SpaceInvitationState extends Equatable {
  final SpaceInvitationStatus status;

  /// Set on success.
  final SpaceInvitation? invitation;

  /// Set on failure.
  final String? errorMessage;

  const SpaceInvitationState._({
    required this.status,
    this.invitation,
    this.errorMessage,
  });

  const SpaceInvitationState.initial()
    : this._(status: SpaceInvitationStatus.initial);

  const SpaceInvitationState.inProgress()
    : this._(status: SpaceInvitationStatus.inProgress);

  const SpaceInvitationState.success(SpaceInvitation invitation)
    : this._(status: SpaceInvitationStatus.success, invitation: invitation);

  const SpaceInvitationState.failure(String message)
    : this._(status: SpaceInvitationStatus.failure, errorMessage: message);

  @override
  List<Object?> get props => [status, invitation, errorMessage];
}
