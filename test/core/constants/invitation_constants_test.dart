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
}
