import 'package:flutter/material.dart';

abstract class Dimens {
  const Dimens._();

  // Zero
  static const double zero = 0.0;

  // Margins
  static const double marginXxxSmall = 2;
  static const double marginXxSmall = 4;
  static const double marginXSmall = 8;
  static const double marginSmall = 12;
  static const double marginMedium = 16;
  static const double marginLarge = 20;
  static const double marginXLarge = 24;
  static const double marginXxLarge = 36;
  static const double marginXxxLarge = 48;

  static SizedBox get boxXxxSmall =>
      const SizedBox(height: marginXxxSmall, width: marginXxxSmall);

  static SizedBox get boxXxSmall =>
      const SizedBox(height: marginXxSmall, width: marginXxSmall);

  static SizedBox get boxXSmall =>
      const SizedBox(height: marginXSmall, width: marginXSmall);

  static SizedBox get boxSmall =>
      const SizedBox(height: marginSmall, width: marginSmall);

  static SizedBox get boxMedium =>
      const SizedBox(height: marginMedium, width: marginMedium);

  static SizedBox get boxLarge =>
      const SizedBox(height: marginLarge, width: marginLarge);

  static SizedBox get boxXLarge =>
      const SizedBox(height: marginXLarge, width: marginXLarge);

  static SizedBox get boxXxLarge =>
      const SizedBox(height: marginXxLarge, width: marginXxLarge);

  static SizedBox get boxXxxLarge =>
      const SizedBox(height: marginXxxLarge, width: marginXxxLarge);

  // Other app-wide dimensions
  static const double minInteractiveDimension = kMinInteractiveDimension;

  static const double listItemHeightMedium = 60;

  static const double dividerHeight = 1;

  static const double buttonHeightXSmall = 30;
  static const double buttonHeightSmall = 40;
  static const double buttonHeightMedium = 50;
  static const double buttonHeightLarge = 64;
  static const double buttonRadiusXxSmall = 2;
  static const double buttonRadiusXSmall = 4;
  static const double buttonRadiusSmall = 8;
  static const double buttonRadiusMedium = 12;
  static const double buttonRadiusLarge = 16;
  static const double buttonRadiusXLarge = 20;
  static const double buttonRadiusXxLarge = 24;
  static const double buttonRadiusXxxLarge = 36;

  static const double inputDecorationRadius = 0;
  static const double inputDecorationBorderWidth = 2;

  static const double iconSizeLarge = 40;
  static const double iconSizeMedium = 30;
  static const double iconSizeSmall = 20;
  static const double iconSizeXSmall = 17;
  static const double iconButtonSize = 40;
  static const double horizontalProgressHeight = 2;

  static const double borderSmall = 1;
  static const double borderMedium = 2;
  static const double borderLarge = 3;

  static const double navigationBarElevation = 0;
  static const double appBarHeight = 60;
  static const double appBarHeightSmall = 40;
  static const double expandedAppBarHeight = 50;
  static const double sliverPersistentHeaderHeight = 30;
  static const double dialogBorderRadius = 24;
  static const double bottomSheetBorderRadius = 24;
  static const double snackBarBorderRadius = 0;

  static const int errorMaxLines = 4;

  // View-specific dimensions
  static const double paginationLoaderHeight = 76;

  // Animations
  static const Duration defaultAnimationDuration = Duration(milliseconds: 250);
  static const Duration slideAnimationDuration = Duration(milliseconds: 400);

  // Alerts
  static const int alertDurationShort = 3;
  static const int alertDurationMedium = 6;
  static const int alertDurationLong = 9;
}
