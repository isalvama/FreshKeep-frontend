import 'package:flutter/cupertino.dart';

enum AdaptiveThemeState {
  light._(Brightness.dark),
  dark._(Brightness.light);

  final Brightness brightness;

  const AdaptiveThemeState._(this.brightness);
}
