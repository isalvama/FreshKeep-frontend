import 'package:flutter_test/flutter_test.dart';
import 'package:fresh_keep_frontend/core/deep_links/pending_invitation_store.dart';

void main() {
  test('starts empty', () {
    expect(PendingInvitationStore().take(), isNull);
  });

  test('take returns the saved token once', () {
    final store = PendingInvitationStore()..save('abc');

    expect(store.take(), 'abc');
    expect(store.take(), isNull);
  });

  test('the latest saved token wins', () {
    final store = PendingInvitationStore()
      ..save('abc')
      ..save('def');

    expect(store.take(), 'def');
  });

  test('clear drops the token', () {
    final store = PendingInvitationStore()
      ..save('abc')
      ..clear();

    expect(store.take(), isNull);
  });
}
