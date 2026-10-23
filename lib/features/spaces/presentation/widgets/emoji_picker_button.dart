import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';

import '../../../../core/constants/ui_constants.dart';

class EmojiPickerButton extends StatelessWidget {
  final String emoji;
  final ValueChanged<String> onChanged;

  const EmojiPickerButton({
    super.key,
    required this.emoji,
    required this.onChanged,
  });

  Future<void> _openPicker(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(kCornerRadius)),
      ),
      builder: (context) {
        return SizedBox(
          height: 320,
          child: EmojiPicker(
            onEmojiSelected: (category, selected) {
              onChanged(selected.emoji);
              Navigator.of(context).pop();
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: kCornerBorderRadius,
      onTap: () => _openPicker(context),
      child: Container(
        width: 56,
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).colorScheme.outline),
          borderRadius: kCornerBorderRadius,
        ),
        child: Text(emoji, style: const TextStyle(fontSize: 28)),
      ),
    );
  }
}
