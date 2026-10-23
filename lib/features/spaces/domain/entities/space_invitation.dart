import 'package:equatable/equatable.dart';

/// The result of `POST /api/v1/spaces/{spaceId}/invitations`.
class SpaceInvitation extends Equatable {
  final String id;
  final String token;
  final String spaceId;

  /// In UTC; valid for 24 hours from creation.
  final DateTime expiresAt;

  const SpaceInvitation({
    required this.id,
    required this.token,
    required this.spaceId,
    required this.expiresAt,
  });

  @override
  List<Object?> get props => [id, token, spaceId, expiresAt];
}
