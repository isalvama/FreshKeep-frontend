part of 'join_space_bloc.dart';

sealed class JoinSpaceEvent {
  const JoinSpaceEvent();
}

/// Joins the space behind [token]; ignored while a join is in progress.
final class JoinSpaceSubmitted extends JoinSpaceEvent {
  final String token;

  const JoinSpaceSubmitted(this.token);
}
