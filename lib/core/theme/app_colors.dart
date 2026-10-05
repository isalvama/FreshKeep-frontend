import 'package:flutter/material.dart';

/// The Fresh Keep palette: warm cream surfaces, brown actions and sage-green
/// accents.
abstract class AppColors {
  const AppColors._();

  // Brown — primary actions and text
  static const brown = Color(0xFF8E5B3F);
  static const brownDark = Color(0xFF4F3422);
  static const brownMuted = Color(0xFF7A6558);
  static const brownLight = Color(0xFFEFE4DB);

  // Sage green — accents, selection and progress
  static const sage = Color(0xFF9BB068);
  static const sageDark = Color(0xFF5E7136);
  static const sageLight = Color(0xFFEEF2E3);

  // Neutrals
  static const cream = Color(0xFFF7F4F0);
  static const white = Color(0xFFFFFFFF);
  static const outline = Color(0xFFE3DCD4);
  static const outlineLight = Color(0xFFEDE8E2);

  static const error = Color(0xFFC0473A);

  // Expiration dates — expired (or expiring today) and expiring soon
  static const expiredLight = Color(0xFFF6DEDA);
  static const expiringSoon = Color(0xFF7A5C00);
  static const expiringSoonLight = Color(0xFFFCEFC2);
}
