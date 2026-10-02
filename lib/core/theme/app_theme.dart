import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Headings, titles, labels and buttons.
const kHeadingFontFamily = 'WorkSans';

/// Body text.
const kBodyFontFamily = 'NunitoSans';

abstract class AppTheme {
  const AppTheme._();

  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(seedColor: AppColors.brown)
        .copyWith(
          primary: AppColors.brown,
          onPrimary: AppColors.white,
          primaryContainer: AppColors.brownLight,
          onPrimaryContainer: AppColors.brownDark,
          secondary: AppColors.sage,
          onSecondary: AppColors.white,
          secondaryContainer: AppColors.sageLight,
          onSecondaryContainer: AppColors.sageDark,
          surface: AppColors.cream,
          onSurface: AppColors.brownDark,
          onSurfaceVariant: AppColors.brownMuted,
          surfaceContainerLowest: AppColors.white,
          surfaceContainerLow: AppColors.white,
          surfaceContainer: AppColors.cream,
          surfaceContainerHigh: AppColors.cream,
          surfaceContainerHighest: AppColors.outlineLight,
          outline: AppColors.outline,
          outlineVariant: AppColors.outlineLight,
          error: AppColors.error,
          surfaceTint: Colors.transparent,
        );

    final textTheme = _textTheme(colorScheme);
    const pill = StadiumBorder();
    const buttonPadding = EdgeInsets.symmetric(horizontal: 24, vertical: 16);
    final buttonText = textTheme.labelLarge!.copyWith(fontSize: 16);

    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: AppColors.outline),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.cream,
      canvasColor: AppColors.cream,
      fontFamily: kBodyFontFamily,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.cream,
        foregroundColor: AppColors.brownDark,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: textTheme.titleLarge,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.brown,
          foregroundColor: AppColors.white,
          disabledBackgroundColor: AppColors.outline,
          disabledForegroundColor: AppColors.brownMuted,
          elevation: 0,
          shape: pill,
          padding: buttonPadding,
          textStyle: buttonText,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.brown,
          foregroundColor: AppColors.white,
          disabledBackgroundColor: AppColors.outline,
          disabledForegroundColor: AppColors.brownMuted,
          shape: pill,
          padding: buttonPadding,
          textStyle: buttonText,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.brownDark,
          backgroundColor: AppColors.white,
          side: const BorderSide(color: AppColors.outline),
          shape: pill,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.brown,
          shape: pill,
          textStyle: textTheme.labelLarge,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: AppColors.brownDark),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.brown,
        foregroundColor: AppColors.white,
        elevation: 2,
        shape: StadiumBorder(),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        hintStyle: textTheme.bodyLarge!.copyWith(color: AppColors.brownMuted),
        labelStyle: textTheme.bodyLarge!.copyWith(color: AppColors.brownMuted),
        floatingLabelStyle: textTheme.bodyMedium!.copyWith(
          color: AppColors.sageDark,
        ),
        border: inputBorder,
        enabledBorder: inputBorder,
        disabledBorder: inputBorder.copyWith(
          borderSide: const BorderSide(color: AppColors.outlineLight),
        ),
        focusedBorder: inputBorder.copyWith(
          borderSide: const BorderSide(color: AppColors.sage, width: 1.5),
        ),
        errorBorder: inputBorder.copyWith(
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: inputBorder.copyWith(
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.white,
        selectedColor: AppColors.sageLight,
        side: const BorderSide(color: AppColors.outline),
        shape: const StadiumBorder(),
        labelStyle: textTheme.labelLarge,
        secondaryLabelStyle: textTheme.labelLarge!.copyWith(
          color: AppColors.sageDark,
        ),
        checkmarkColor: AppColors.sageDark,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        side: const BorderSide(color: AppColors.brownMuted, width: 1.5),
      ),
      cardTheme: CardThemeData(
        color: AppColors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.outlineLight),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: AppColors.brownDark,
        textColor: AppColors.brownDark,
        selectedColor: AppColors.sageDark,
        selectedTileColor: AppColors.sageLight,
        titleTextStyle: textTheme.titleMedium,
        subtitleTextStyle: textTheme.bodyMedium!.copyWith(
          color: AppColors.brownMuted,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.outlineLight,
        thickness: 1,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.cream,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        titleTextStyle: textTheme.headlineSmall,
        contentTextStyle: textTheme.bodyLarge,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.cream,
        surfaceTintColor: Colors.transparent,
        showDragHandle: false,
      ),
      datePickerTheme: const DatePickerThemeData(
        backgroundColor: AppColors.cream,
        surfaceTintColor: Colors.transparent,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: AppColors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.brownDark,
        contentTextStyle: textTheme.bodyMedium!.copyWith(
          color: AppColors.white,
        ),
        actionTextColor: AppColors.sageLight,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.sage,
        linearTrackColor: AppColors.outlineLight,
        circularTrackColor: Colors.transparent,
      ),
    );
  }

  /// Work Sans for display, headline, title and label styles; Nunito Sans
  /// (the theme's default family) for body styles.
  static TextTheme _textTheme(ColorScheme colorScheme) {
    final base = Typography.material2021(colorScheme: colorScheme).black.apply(
      bodyColor: colorScheme.onSurface,
      displayColor: colorScheme.onSurface,
    );

    TextStyle? heading(TextStyle? style, FontWeight weight) =>
        style?.copyWith(fontFamily: kHeadingFontFamily, fontWeight: weight);

    return base.copyWith(
      displayLarge: heading(base.displayLarge, FontWeight.w500),
      displayMedium: heading(base.displayMedium, FontWeight.w500),
      displaySmall: heading(base.displaySmall, FontWeight.w500),
      headlineLarge: heading(base.headlineLarge, FontWeight.w500),
      headlineMedium: heading(base.headlineMedium, FontWeight.w500),
      headlineSmall: heading(base.headlineSmall, FontWeight.w500),
      titleLarge: heading(base.titleLarge, FontWeight.w500),
      titleMedium: heading(base.titleMedium, FontWeight.w500),
      titleSmall: heading(base.titleSmall, FontWeight.w500),
      labelLarge: heading(base.labelLarge, FontWeight.w500),
      labelMedium: heading(base.labelMedium, FontWeight.w500),
      labelSmall: heading(base.labelSmall, FontWeight.w500),
      bodyLarge: base.bodyLarge?.copyWith(fontFamily: kBodyFontFamily),
      bodyMedium: base.bodyMedium?.copyWith(fontFamily: kBodyFontFamily),
      bodySmall: base.bodySmall?.copyWith(
        fontFamily: kBodyFontFamily,
        color: colorScheme.onSurfaceVariant,
      ),
    );
  }
}
