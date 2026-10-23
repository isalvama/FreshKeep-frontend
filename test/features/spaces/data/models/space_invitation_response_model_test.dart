import 'package:flutter_test/flutter_test.dart';
import 'package:fresh_keep_frontend/features/spaces/data/models/space_invitation_response_model.dart';
import 'package:fresh_keep_frontend/features/spaces/domain/entities/space_invitation.dart';

Map<String, dynamic> _json({String expiresAt = '2026-09-29T21:00:00'}) => {
  'id': 'invitation-1',
  'token': 'the-invitation-token',
  'spaceId': 'space-1',
  'userCreatorId': 'user-1',
  'expiresAt': expiresAt,
  'isActive': true,
};

void main() {
  test('fromJson maps the response to a SpaceInvitation', () {
    final invitation = SpaceInvitationResponseModel.fromJson(
      _json(),
    ).toEntity();

    expect(
      invitation,
      SpaceInvitation(
        id: 'invitation-1',
        token: 'the-invitation-token',
        spaceId: 'space-1',
        expiresAt: DateTime.utc(2026, 9, 29, 21),
      ),
    );
  });

  test('an expiresAt without offset is read as UTC, not local time', () {
    final expiresAt = SpaceInvitationResponseModel.fromJson(_json()).expiresAt;

    expect(expiresAt.isUtc, isTrue);
    expect(expiresAt, DateTime.utc(2026, 9, 29, 21));
  });

  test('an expiresAt with fractional seconds keeps them', () {
    final expiresAt = SpaceInvitationResponseModel.fromJson(
      _json(expiresAt: '2026-09-29T21:00:00.123456'),
    ).expiresAt;

    expect(expiresAt, DateTime.utc(2026, 9, 29, 21, 0, 0, 123, 456));
  });

  test('an expiresAt that already carries an offset is honoured', () {
    final expiresAt = SpaceInvitationResponseModel.fromJson(
      _json(expiresAt: '2026-09-29T23:00:00+02:00'),
    ).expiresAt;

    expect(expiresAt, DateTime.utc(2026, 9, 29, 21));
  });

  test('fromEntity round-trips through toEntity', () {
    final invitation = SpaceInvitation(
      id: 'invitation-1',
      token: 'the-invitation-token',
      spaceId: 'space-1',
      expiresAt: DateTime.utc(2026, 9, 29, 21),
    );

    expect(
      SpaceInvitationResponseModel.fromEntity(invitation).toEntity(),
      invitation,
    );
  });
}
