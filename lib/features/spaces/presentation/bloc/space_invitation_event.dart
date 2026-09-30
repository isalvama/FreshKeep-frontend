part of 'space_invitation_bloc.dart';

sealed class SpaceInvitationEvent {
  const SpaceInvitationEvent();
}

/// Creates a new invitation for [spaceId]; ignored while one is in progress.
final class SpaceInvitationRequested extends SpaceInvitationEvent {
  final String spaceId;

  const SpaceInvitationRequested(this.spaceId);
}
