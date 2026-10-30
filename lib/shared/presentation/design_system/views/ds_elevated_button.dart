import 'package:flutter/material.dart';
import 'package:fresh_keep_frontend/shared/presentation/theme/dimens.dart';
import 'package:fresh_keep_frontend/util/extensions/context_extension.dart';
import 'package:fresh_keep_frontend/util/extensions/string_extension.dart';

class DSElevatedButton extends StatelessWidget {
  final bool isSubmitting;
  final Function(BuildContext context) submit;
  final String text;
  final bool textInTitleCase;

  const DSElevatedButton({
    super.key,
    required this.isSubmitting,
    required this.submit,
    required this.text,
    this.textInTitleCase = true,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: Dimens.buttonHeightMedium,
      child: ElevatedButton(
        style: ButtonStyle(
          backgroundColor: WidgetStatePropertyAll<Color>(
            context.colorScheme.primary,
          ),
        ),
        onPressed: isSubmitting ? null : () => submit(context),
        child: isSubmitting
            ? const SizedBox(
                height: Dimens.iconSizeSmall,
                width: Dimens.iconSizeSmall,
                child: CircularProgressIndicator(
                  strokeWidth: Dimens.borderMedium,
                ),
              )
            : Text(
                textInTitleCase ? text.toTitleCase() : text,
                style: Theme.of(context).textTheme.headlineMedium!.copyWith(
                  color: context.colorScheme.onPrimary,
                ),
              ),
      ),
    );
  }
}
