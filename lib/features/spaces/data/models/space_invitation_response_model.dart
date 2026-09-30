import '../../domain/entities/space_invitation.dart';

class SpaceInvitationResponseModel {
  final String id;
  final String token;
  final String spaceId;
  final DateTime expiresAt;

  const SpaceInvitationResponseModel({
    required this.id,
    required this.token,
    required this.spaceId,
    required this.expiresAt,
  });

  factory SpaceInvitationResponseModel.fromJson(Map<String, dynamic> json) {
    return SpaceInvitationResponseModel(
      id: json['id'] as String,
      token: json['token'] as String,
      spaceId: json['spaceId'] as String,
      expiresAt: _parseUtc(json['expiresAt'] as String),
    );
  }

  factory SpaceInvitationResponseModel.fromEntity(SpaceInvitation invitation) {
    return SpaceInvitationResponseModel(
      id: invitation.id,
      token: invitation.token,
      spaceId: invitation.spaceId,
      expiresAt: invitation.expiresAt,
    );
  }

  SpaceInvitation toEntity() {
    return SpaceInvitation(
      id: id,
      token: token,
      spaceId: spaceId,
      expiresAt: expiresAt,
    );
  }

  /// The backend sends a `LocalDateTime` computed from its UTC clock, without
  /// an offset (e.g. `2026-09-29T21:00:00`), so an offset-less value is read
  /// as UTC rather than as the phone's local time.
  static DateTime _parseUtc(String value) {
    final parsed = DateTime.parse(value);
    if (parsed.isUtc) return parsed;
    return DateTime.utc(
      parsed.year,
      parsed.month,
      parsed.day,
      parsed.hour,
      parsed.minute,
      parsed.second,
      parsed.millisecond,
      parsed.microsecond,
    );
  }
}
