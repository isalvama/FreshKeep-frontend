import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fresh_keep_frontend/features/spaces/domain/entities/space_invitation.dart';
import 'package:fresh_keep_frontend/features/spaces/presentation/widgets/space_invitation_dialog.dart';

final _invitation = SpaceInvitation(
  id: 'invitation-1',
  token: 'a b&c',
  spaceId: 'space-1',
  expiresAt: DateTime.utc(2026, 9, 29, 21, 5),
);

const _link = 'freshkeep://join?token=a+b%26c';

/// Pumps a page with a button that opens the dialog for [_invitation] to
/// "Kitchen"; shared texts land in [shared].
Future<void> _pumpOpener(WidgetTester tester, List<String> shared) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showSpaceInvitationDialog(
              context,
              spaceName: 'Kitchen',
              invitation: _invitation,
              onShare: (text) async => shared.add(text),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

String _expectedLocalExpiry() {
  final local = _invitation.expiresAt.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return 'Expires ${local.year}-${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}';
}

void main() {
  testWidgets('shows the title, the selectable link and the local expiry', (
    tester,
  ) async {
    await _pumpOpener(tester, []);

    expect(find.text('Invite to Kitchen'), findsOneWidget);
    expect(
      find.byWidgetPredicate((w) => w is SelectableText && w.data == _link),
      findsOneWidget,
    );
    expect(find.text(_expectedLocalExpiry()), findsOneWidget);
    expect(find.text('Copy'), findsOneWidget);
    expect(find.text('Share'), findsOneWidget);
    expect(find.text('Close'), findsOneWidget);
  });

  testWidgets('Copy puts exactly the link on the clipboard and shows '
      '"Link copied"', (tester) async {
    final copied = <Object?>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied.add((call.arguments as Map)['text']);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await _pumpOpener(tester, []);

    await tester.tap(find.text('Copy'));
    await tester.pump();

    expect(copied, [_link]);
    expect(find.text('Link copied'), findsOneWidget);
    expect(find.text('Invite to Kitchen'), findsOneWidget);
  });

  testWidgets('Share passes exactly the invitation message to onShare', (
    tester,
  ) async {
    final shared = <String>[];
    await _pumpOpener(tester, shared);

    await tester.tap(find.text('Share'));
    await tester.pump();

    expect(shared, ['Join my space Kitchen on Fresh Keep: $_link']);
    expect(find.text('Invite to Kitchen'), findsOneWidget);
  });

  testWidgets('Close closes the dialog', (tester) async {
    await _pumpOpener(tester, []);

    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    expect(find.text('Invite to Kitchen'), findsNothing);
    expect(find.text('open'), findsOneWidget);
  });
}
