import 'package:flutter_test/flutter_test.dart';
import 'package:fresh_keep_frontend/core/constants/invitation_constants.dart';

void main() {
  test('invitationLink builds a freshkeep://join link with the token', () {
    expect(invitationLink('abc'), 'freshkeep://join?token=abc');
  });

  test('invitationLink URL-encodes reserved characters in the token', () {
    expect(invitationLink('a b&c'), 'freshkeep://join?token=a+b%26c');
  });

  test('the link parses back to the original token', () {
    const token = 'a b&c=d/e?f';

    expect(Uri.parse(invitationLink(token)).queryParameters['token'], token);
  });

  group('parseInvitationToken', () {
    test('returns the token of an invitation link', () {
      expect(
        parseInvitationToken(Uri.parse('freshkeep://join?token=abc')),
        'abc',
      );
    });

    test('round-trips a token built by invitationLink', () {
      expect(parseInvitationToken(Uri.parse(invitationLink('a b&c'))), 'a b&c');
    });

    test('compares the scheme and host ignoring case', () {
      expect(
        parseInvitationToken(Uri.parse('FRESHKEEP://JOIN?token=abc')),
        'abc',
      );
    });

    for (final link in ['freshkeep://join', 'freshkeep://join?token=']) {
      test('returns an empty token for $link', () {
        expect(parseInvitationToken(Uri.parse(link)), '');
      });
    }

    for (final link in [
      'freshkeep://other?token=abc',
      'https://join?token=abc',
      'mailto:x',
    ]) {
      test('returns null for $link', () {
        expect(parseInvitationToken(Uri.parse(link)), isNull);
      });
    }
  });
}
