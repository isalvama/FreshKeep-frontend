import 'package:flutter/material.dart';
import 'package:fresh_keep_frontend/util/extensions/string_extension.dart';

class DSTextButton extends StatelessWidget {
  final void Function()? onPressed;
  final String text;
  final bool textInTitleCase;

  const DSTextButton({
    super.key,
    required this.onPressed,
    required this.text,
    this.textInTitleCase = true,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton(
      style: TextButton.styleFrom(
        padding: EdgeInsets.zero,
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      onPressed: onPressed,
      child: Text(
        textInTitleCase ? text.toTitleCase() : text,
        style: Theme.of(context).textTheme.labelLarge!.copyWith(
          color: Theme.of(context).colorScheme.primary,
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }
}
