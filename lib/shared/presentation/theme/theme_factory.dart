import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fresh_keep_frontend/core/theme/app_colors.dart';
import 'package:fresh_keep_frontend/core/theme/app_theme.dart';
import 'package:fresh_keep_frontend/shared/presentation/theme/app_text_styles.dart';
import 'package:fresh_keep_frontend/shared/presentation/theme/dimens.dart';

abstract class ThemeFactory {
  const ThemeFactory._();

  static SystemUiOverlayStyle darkSystemUIOverlayStyle = SystemUiOverlayStyle
      .dark
      .copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarContrastEnforced: false,
        systemStatusBarContrastEnforced: false,
      );

  static SystemUiOverlayStyle lightSystemUIOverlayStyle = SystemUiOverlayStyle
      .light
      .copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarContrastEnforced: false,
        systemStatusBarContrastEnforced: false,
      );

  static ThemeData lightTheme() {
    const defaultTextColor = AppColors.brownMuted;

    final base = ThemeData.light().copyWith(
      disabledColor: AppColors.disabled,
      colorScheme: const ColorScheme(
        primary: AppColors.brown,
        secondary: AppColors.sage,
        tertiary: AppColors.brownMuted,
        surface: AppColors.cream,
        error: AppColors.error,
        onPrimary: AppColors.white,
        onSecondary: AppColors.white,
        onSurface: AppColors.brownMuted,
        onError: AppColors.white,
        brightness: Brightness.light,
      ),
      textTheme: TextTheme(
        displayLarge: AppTextStyles.displayLarge(textColor: defaultTextColor),
        displayMedium: AppTextStyles.displayMedium(textColor: defaultTextColor),
        displaySmall: AppTextStyles.displaySmall(textColor: defaultTextColor),
        headlineMedium: AppTextStyles.headlineMedium(
          textColor: defaultTextColor,
        ),
        bodyLarge: AppTextStyles.bodyLarge(textColor: defaultTextColor),
        bodyMedium: AppTextStyles.bodyMedium(textColor: defaultTextColor),
        labelSmall: AppTextStyles.labelSmall(textColor: defaultTextColor),
        titleMedium: AppTextStyles.titleMedium(textColor: defaultTextColor),
      ),
    );

    return base.copyWith(
      brightness: base.colorScheme.brightness,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      textSelectionTheme: base.textSelectionTheme.copyWith(
        cursorColor: base.colorScheme.secondary,
        selectionColor: base.colorScheme.secondary,
        selectionHandleColor: base.colorScheme.secondary,
      ),
      splashFactory: NoSplash.splashFactory,
      primaryColor: base.colorScheme.primary,
      primaryColorLight: base.colorScheme.primary,
      primaryColorDark: base.colorScheme.primary,
      scaffoldBackgroundColor: base.colorScheme.surface,
      appBarTheme: base.appBarTheme.copyWith(
        centerTitle: true,
        elevation: Dimens.zero,
        systemOverlayStyle: lightSystemUIOverlayStyle,
        iconTheme: base.iconTheme.copyWith(color: base.colorScheme.onSurface),
        actionsIconTheme: base.iconTheme.copyWith(
          color: base.colorScheme.onSurface,
        ),
        backgroundColor: base.colorScheme.surface,
        titleTextStyle: base.textTheme.displayMedium,
      ),
      dividerColor: base.disabledColor,
      snackBarTheme: base.snackBarTheme.copyWith(
        elevation: Dimens.zero,
        shape: const BeveledRectangleBorder(),
      ),
      datePickerTheme: base.datePickerTheme.copyWith(
        elevation: Dimens.zero,
        dayBackgroundColor: WidgetStateProperty.fromMap({
          WidgetState.disabled: Colors.transparent,
          WidgetState.selected: base.colorScheme.tertiary,
          WidgetState.hovered: base.colorScheme.error.withAlpha(127),
        }),
        dayForegroundColor: WidgetStateProperty.fromMap({
          WidgetState.disabled: base.colorScheme.onSurface.withAlpha(127),
          WidgetState.selected: base.colorScheme.primary,
          WidgetState.hovered: base.colorScheme.onPrimary,
        }),
        confirmButtonStyle: ButtonStyle(
          foregroundColor: WidgetStatePropertyAll(base.colorScheme.onPrimary),
          textStyle: WidgetStatePropertyAll(
            base.textTheme.bodyMedium?.copyWith(
              color: base.colorScheme.onPrimary,
            ),
          ),
        ),
        todayForegroundColor: WidgetStatePropertyAll(
          base.colorScheme.onPrimary,
        ),
        todayBackgroundColor: WidgetStatePropertyAll(Colors.transparent),
        cancelButtonStyle: ButtonStyle(
          foregroundColor: WidgetStatePropertyAll(base.colorScheme.error),
          textStyle: WidgetStatePropertyAll(
            base.textTheme.bodyMedium?.copyWith(color: base.colorScheme.error),
          ),
        ),
        dayStyle: base.textTheme.bodyLarge?.copyWith(
          color: base.colorScheme.onSurface,
        ),
        rangePickerBackgroundColor: base.colorScheme.error,
        dayOverlayColor: WidgetStatePropertyAll(
          base.colorScheme.error.withAlpha(127),
        ),
        rangePickerSurfaceTintColor: base.colorScheme.error,
      ),
      inputDecorationTheme: AppTheme.inputDecorationTheme(
        base.inputDecorationTheme,
        floatingLabelStyle: base.textTheme.labelSmall,
        labelStyle: base.textTheme.bodyLarge,
        errorStyle: base.textTheme.labelSmall,
        errorColor: base.colorScheme.error,
        borderColor: base.colorScheme.onSurface,
        iconColor: base.colorScheme.surface,
      ),
      buttonTheme: AppTheme.buttonTheme(
        base.buttonTheme,
        borderColor: base.colorScheme.onSurface,
      ),
    );
  }

  static ThemeData darkTheme() {
    const defaultTextColor = AppColors.white;

    // Basic Config
    final base = ThemeData.dark().copyWith(
      disabledColor: AppColors.disabled,
      colorScheme: const ColorScheme(
        primary: AppColors.brownDark,
        secondary: AppColors.brown,
        tertiary: AppColors.brownMuted,
        surface: AppColors.black,
        error: AppColors.error,
        onPrimary: AppColors.white,
        onSecondary: AppColors.white,
        onSurface: AppColors.white,
        onError: AppColors.white,
        brightness: Brightness.dark,
      ),
      textTheme: TextTheme(
        displayLarge: AppTextStyles.displayLarge(textColor: defaultTextColor),
        displayMedium: AppTextStyles.displayMedium(textColor: defaultTextColor),
        displaySmall: AppTextStyles.displaySmall(textColor: defaultTextColor),
        bodyLarge: AppTextStyles.bodyLarge(textColor: defaultTextColor),
        bodyMedium: AppTextStyles.bodyMedium(textColor: defaultTextColor),
        labelSmall: AppTextStyles.labelSmall(textColor: defaultTextColor),
        titleLarge: AppTextStyles.titleMedium(textColor: defaultTextColor),
      ),
    );

    // Other Configs
    return base.copyWith(
      brightness: base.colorScheme.brightness,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      textSelectionTheme: base.textSelectionTheme.copyWith(
        cursorColor: base.colorScheme.secondary,
        selectionColor: base.colorScheme.secondary,
        selectionHandleColor: base.colorScheme.secondary,
      ),
      splashFactory: NoSplash.splashFactory,
      primaryColor: base.colorScheme.primary,
      primaryColorLight: base.colorScheme.primary,
      primaryColorDark: base.colorScheme.primary,
      scaffoldBackgroundColor: base.colorScheme.surface,
      appBarTheme: base.appBarTheme.copyWith(
        centerTitle: true,
        elevation: Dimens.zero,
        systemOverlayStyle: darkSystemUIOverlayStyle,
        iconTheme: base.iconTheme.copyWith(color: base.colorScheme.onSurface),
        actionsIconTheme: base.iconTheme.copyWith(
          color: base.colorScheme.onSurface,
        ),
        backgroundColor: base.colorScheme.surface,
        titleTextStyle: base.textTheme.displayMedium,
      ),
      dividerColor: base.disabledColor,
      snackBarTheme: base.snackBarTheme.copyWith(
        elevation: Dimens.zero,
        shape: const BeveledRectangleBorder(),
      ),
      inputDecorationTheme: AppTheme.inputDecorationTheme(
        base.inputDecorationTheme,
        floatingLabelStyle: base.textTheme.labelSmall,
        labelStyle: base.textTheme.bodyLarge,
        errorStyle: base.textTheme.labelSmall,
        errorColor: base.colorScheme.error,
        borderColor: base.colorScheme.onSurface,
        iconColor: base.colorScheme.surface,
      ),
      buttonTheme: AppTheme.buttonTheme(
        base.buttonTheme,
        borderColor: base.colorScheme.onSurface,
      ),
    );
  }
}
