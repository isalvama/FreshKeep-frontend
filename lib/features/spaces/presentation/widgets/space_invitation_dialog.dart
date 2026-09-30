import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/constants/invitation_constants.dart';
import '../../domain/entities/space_invitation.dart';

/// Shows the link of a freshly created [invitation] to [spaceName], with
/// Copy, Share and Close.
///
/// [onShare] replaces the platform share sheet (used by tests); by default
/// the text goes to `share_plus`.
Future<void> showSpaceInvitationDialog(
  BuildContext context, {
  required String spaceName,
  required SpaceInvitation invitation,
  Future<void> Function(String text)? onShare,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _SpaceInvitationDialog(
      spaceName: spaceName,
      invitation: invitation,
      onShare: onShare,
    ),
  );
}

class _SpaceInvitationDialog extends StatelessWidget {
  const _SpaceInvitationDialog({
    required this.spaceName,
    required this.invitation,
    required this.onShare,
  });

  final String spaceName;
  final SpaceInvitation invitation;
  final Future<void> Function(String text)? onShare;

  String get _link => invitationLink(invitation.token);

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: _link));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Link copied')));
  }

  Future<void> _share(BuildContext context) async {
    final text = 'Join my space $spaceName on Fresh Keep: $_link';
    if (onShare != null) return onShare!(text);

    // iPad needs an anchor for the share popover.
    final box = context.findRenderObject() as RenderBox?;
    await SharePlus.instance.share(
      ShareParams(
        text: text,
        sharePositionOrigin: box == null
            ? null
            : box.localToGlobal(Offset.zero) & box.size,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Invite to $spaceName'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectableText(_link),
          const SizedBox(height: 12),
          Text(
            'Expires ${_formatDateTime(invitation.expiresAt.toLocal())}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        TextButton(onPressed: () => _copy(context), child: const Text('Copy')),
        Builder(
          builder: (buttonContext) => FilledButton(
            onPressed: () => _share(buttonContext),
            child: const Text('Share'),
          ),
        ),
      ],
    );
  }
}

/// `yyyy-MM-dd HH:mm`.
String _formatDateTime(DateTime date) {
  String two(int value) => value.toString().padLeft(2, '0');
  return '${date.year}-${two(date.month)}-${two(date.day)} '
      '${two(date.hour)}:${two(date.minute)}';
}
