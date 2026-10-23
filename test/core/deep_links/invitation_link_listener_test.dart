import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fresh_keep_frontend/core/deep_links/invitation_link_listener.dart';

void main() {
  late StreamController<Uri> links;
  late List<String> pushed;
  late InvitationLinkListener listener;

  setUp(() {
    links = StreamController<Uri>();
    pushed = [];
    listener = InvitationLinkListener(links: links.stream, push: pushed.add)
      ..start();
  });

  tearDown(() async {
    await listener.dispose();
    await links.close();
  });

  Future<void> send(String link) async {
    links.add(Uri.parse(link));
    await Future<void>.delayed(Duration.zero);
  }

  test('pushes the join page with the encoded token', () async {
    await send('freshkeep://join?token=a+b%26c');

    expect(pushed, ['/join?token=a+b%26c']);
  });

  test('pushes once per link, including two links in a row', () async {
    await send('freshkeep://join?token=abc');
    await send('freshkeep://join?token=def');

    expect(pushed, ['/join?token=abc', '/join?token=def']);
  });

  test(
    'pushes the join page with an empty token for a link without one',
    () async {
      await send('freshkeep://join');

      expect(pushed, ['/join?token=']);
    },
  );

  test('ignores links that are not invitations', () async {
    await send('freshkeep://other?token=abc');
    await send('https://join?token=abc');

    expect(pushed, isEmpty);
  });

  test('stops after dispose', () async {
    await listener.dispose();
    await send('freshkeep://join?token=abc');

    expect(pushed, isEmpty);
  });
}
