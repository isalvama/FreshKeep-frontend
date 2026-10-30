import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:fresh_keep_frontend/shared/presentation/theme/dimens.dart';
import 'package:fresh_keep_frontend/util/extensions/context_extension.dart';
import 'package:fresh_keep_frontend/util/extensions/string_extension.dart';

class DSAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool backEnabled;
  final Color? backgroundColor;
  final VoidCallback? onBack;
  final bool titleInTitleCase;

  const DSAppBar({
    super.key,
    required this.title,
    this.backEnabled = false,
    this.backgroundColor,
    this.onBack,
    this.titleInTitleCase = true,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(
        titleInTitleCase ? title.toTitleCase() : title,
        style: Theme.of(context).textTheme.headlineMedium,
      ),
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
                color: context.colorScheme.onSurface,
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
