import 'package:flutter/material.dart';
import 'package:fresh_keep_frontend/shared/presentation/theme/dimens.dart';
import 'package:fresh_keep_frontend/util/extensions/context_extension.dart';

class DSElevatedButton extends StatefulWidget {
  bool isSubmitting;
  final Function(BuildContext context) submit;
  final String text;

  DSElevatedButton({
    super.key,
    required this.isSubmitting,
    required this.submit,
    required this.text,
  });

  @override
  State<DSElevatedButton> createState() => _DSElevatedButtonState();
}

class _DSElevatedButtonState extends State<DSElevatedButton> {
  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ButtonStyle(
        backgroundColor: WidgetStatePropertyAll<Color>(
          context.colorScheme.primary,
        ),
      ),
      onPressed: widget.isSubmitting ? null : () => widget.submit(context),
      child: widget.isSubmitting
          ? const SizedBox(
              height: Dimens.iconSizeSmall,
              width: Dimens.iconSizeSmall,
              child: CircularProgressIndicator(
                strokeWidth: Dimens.borderMedium,
              ),
            )
          : Text(
              widget.text,
              style: Theme.of(context).textTheme.headlineMedium!.copyWith(
                color: context.colorScheme.onPrimary,
              ),
            ),
    );
  }
}
