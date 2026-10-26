import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:fresh_keep_frontend/shared/presentation/theme/dimens.dart';
import 'package:fresh_keep_frontend/util/extensions/context_extension.dart';

class DSAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool backEnabled;
  final Color? backgroundColor;
  final VoidCallback? onBack;

  const DSAppBar({
    super.key,
    required this.title,
    required this.backEnabled,
    this.backgroundColor,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(title, style: Theme.of(context).textTheme.headlineMedium),
      backgroundColor: backgroundColor ?? Theme.of(context).colorScheme.surface,
      leading: backEnabled
          ? IconButton(
              style: ButtonStyle(
                minimumSize: WidgetStatePropertyAll(Size.zero),
                padding: WidgetStateProperty.all(
                  EdgeInsets.all(Dimens.marginXxSmall),
                ),
              ),
              icon: Icon(
                CupertinoIcons.back,
                color: context.colorScheme.onPrimary,
              ),
              tooltip: 'Close search',
              onPressed: onBack ?? () => Navigator.of(context).pop(),
            )
          : null,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(Dimens.appBarHeight);
}
