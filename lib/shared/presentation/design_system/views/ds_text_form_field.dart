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
    this.keyboardType,
    required this.labelText,
  });

  @override
  State<DSTextFormField> createState() => _DSTextFormFieldState();
}

class _DSTextFormFieldState extends State<DSTextFormField> {
  final double borderRadius = Dimens.buttonHeightLarge;
  final int unfocusedAlphaChannel = 150;
  final int disabledAlphaChannel = 100;
  FocusNode focusNode = FocusNode();

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      obscureText: widget.obscureText,
      focusNode: focusNode,
      decoration: InputDecoration(
        filled: true,
        fillColor: Theme.of(context).colorScheme.onPrimary,
        labelText: widget.labelText,
        labelStyle: Theme.of(context).textTheme.bodyLarge!.copyWith(
          color: context.colorScheme.primary.withAlpha(unfocusedAlphaChannel),
        ),
        floatingLabelStyle: TextStyle(
          color: context.colorScheme.primary.withAlpha(unfocusedAlphaChannel),
        ),
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
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(borderRadius)),
          borderSide: BorderSide(color: context.colorScheme.primary),
        ),
      ),
      validator: widget.validator,
    );
  }
}
