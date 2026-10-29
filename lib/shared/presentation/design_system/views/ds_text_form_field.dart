import 'package:flutter/material.dart';
import 'package:fresh_keep_frontend/shared/presentation/theme/dimens.dart';
import 'package:fresh_keep_frontend/util/extensions/context_extension.dart';

class DSTextFormField extends StatefulWidget {
  final TextEditingController controller;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final bool obscureText;
  final String labelText;

  const DSTextFormField({
    super.key,
    required this.controller,
    required this.validator,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    required this.labelText,
  });

  @override
  State<DSTextFormField> createState() => _DSTextFormFieldState();
}

class _DSTextFormFieldState extends State<DSTextFormField> {
  final double borderRadius = Dimens.buttonRadiusXxLarge;
  final int unfocusedAlphaChannel = 150;
  final int disabledAlphaChannel = 100;
  final String emptyString = " ";

  FocusNode focusNode = FocusNode();

  @override
  Widget build(BuildContext context) {
    final double fontSize = context.textTheme.bodyLarge?.fontSize ?? 16;
    final double vericalContentPadding =
        (Dimens.buttonHeightMedium - fontSize) / 2;

    return TextFormField(
      controller: widget.controller,
      obscureText: widget.obscureText,
      focusNode: focusNode,
      keyboardType: widget.keyboardType,
      style: context.textTheme.bodyLarge,
      decoration: InputDecoration(
        helperText: emptyString,
        helperStyle: Theme.of(context).textTheme.labelSmall,
        errorStyle: Theme.of(
          context,
        ).textTheme.labelSmall!.copyWith(color: context.colorScheme.error),
        errorMaxLines: 1,
        contentPadding: EdgeInsets.symmetric(
          horizontal: Dimens.marginSmall,
          vertical: vericalContentPadding,
        ),
        filled: true,
        fillColor: Theme.of(context).colorScheme.onPrimary,
        labelText: widget.labelText,
        labelStyle: WidgetStateTextStyle.resolveWith((Set<WidgetState> states) {
          final Color color = states.contains(WidgetState.error)
              ? context.colorScheme.error.withAlpha(unfocusedAlphaChannel)
              : context.colorScheme.primary.withAlpha(unfocusedAlphaChannel);
          return Theme.of(context).textTheme.bodyLarge!.copyWith(color: color);
        }),
        floatingLabelStyle: WidgetStateTextStyle.resolveWith((
          Set<WidgetState> states,
        ) {
          final Color color = states.contains(WidgetState.error)
              ? context.colorScheme.error.withAlpha(unfocusedAlphaChannel)
              : context.colorScheme.primary.withAlpha(unfocusedAlphaChannel);
          return TextStyle(color: color);
        }),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(borderRadius)),
          borderSide: BorderSide(
            color: context.colorScheme.primary.withAlpha(disabledAlphaChannel),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(borderRadius)),
          borderSide: BorderSide(
            color: context.colorScheme.primary.withAlpha(unfocusedAlphaChannel),
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(borderRadius)),
          borderSide: BorderSide(
            color: context.colorScheme.error.withAlpha(unfocusedAlphaChannel),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(borderRadius)),
          borderSide: BorderSide(color: context.colorScheme.primary),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(borderRadius)),
          borderSide: BorderSide(color: context.colorScheme.error),
        ),
      ),
      validator: widget.validator,
    );
  }
}
