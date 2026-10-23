import 'dart:async';

import '../constants/invitation_constants.dart';

/// Opens the join page for every invitation link the app receives, whether
/// it started the app or arrived while it was running.
class InvitationLinkListener {
  final Stream<Uri> links;
  final void Function(String location) push;

  StreamSubscription<Uri>? _subscription;

  InvitationLinkListener({required this.links, required this.push});

  void start() {
    _subscription ??= links.listen((uri) {
      final token = parseInvitationToken(uri);
      if (token == null) return;
      push('/join?token=${Uri.encodeQueryComponent(token)}');
    });
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
  }
}
