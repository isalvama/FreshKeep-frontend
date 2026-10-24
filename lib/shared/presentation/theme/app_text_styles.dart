import 'package:flutter/material.dart';

abstract class AppTextStyles {
  const AppTextStyles._();

  static const primaryFontFamily = "NunitoSans";
  static const fontFamilyFallback = ["Roboto"];

  static TextStyle displayLarge({required Color textColor}) {
    return TextStyle(
      letterSpacing: -2,
      fontWeight: FontWeight.w700,
      fontSize: 34,
      height: 1,
      color: textColor,
      fontStyle: FontStyle.normal,
      fontFamily: primaryFontFamily,
      fontFamilyFallback: fontFamilyFallback,
    );
  }

  static TextStyle displayMedium({required Color textColor}) {
    return TextStyle(
      letterSpacing: -1,
      fontWeight: FontWeight.w600,
      fontSize: 23,
      height: 1,
      color: textColor,
      fontStyle: FontStyle.normal,
      fontFamily: primaryFontFamily,
      fontFamilyFallback: fontFamilyFallback,
    );
  }

  static TextStyle displaySmall({required Color textColor}) {
    return TextStyle(
      letterSpacing: -1,
      fontWeight: FontWeight.w700,
      fontSize: 18,
      height: 1,
      color: textColor,
      fontStyle: FontStyle.normal,
      fontFamily: primaryFontFamily,
      fontFamilyFallback: fontFamilyFallback,
    );
  }

  static TextStyle bodyLarge({required Color textColor}) {
    return TextStyle(
      fontWeight: FontWeight.w500,
      fontSize: 16,
      height: 1,
      letterSpacing: -0.5,
      color: textColor,
      fontStyle: FontStyle.normal,
      fontFamily: primaryFontFamily,
      fontFamilyFallback: fontFamilyFallback,
    );
  }

  static TextStyle bodyMedium({required Color textColor}) {
    return TextStyle(
      fontWeight: FontWeight.normal,
      fontSize: 15,
      height: 1,
      letterSpacing: -0.5,
      color: textColor,
      fontStyle: FontStyle.normal,
      fontFamily: primaryFontFamily,
      fontFamilyFallback: fontFamilyFallback,
    );
  }

  static TextStyle labelSmall({required Color textColor}) {
    return TextStyle(
      fontWeight: FontWeight.normal,
      fontSize: 12,
      height: 1,
      letterSpacing: 0.0,
      color: textColor,
      fontStyle: FontStyle.normal,
      fontFamily: primaryFontFamily,
      fontFamilyFallback: fontFamilyFallback,
    );
  }

  static TextStyle titleMedium({required Color textColor}) {
    return TextStyle(
      fontWeight: FontWeight.normal,
      fontSize: 16,
      height: 1,
      color: textColor,
      letterSpacing: -0.06,
      fontStyle: FontStyle.normal,
      fontFamily: primaryFontFamily,
      fontFamilyFallback: const [primaryFontFamily, ...fontFamilyFallback],
    );
  }
}
