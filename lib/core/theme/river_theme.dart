import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'river_colors.dart';

class RiverTheme extends InheritedWidget {
  final AppTheme appTheme;

  const RiverTheme({super.key, required this.appTheme, required super.child});

  RiverColors get colors => appTheme.colors;

  static RiverTheme of(BuildContext context) {
    final result = context.dependOnInheritedWidgetOfExactType<RiverTheme>();
    assert(result != null, 'No RiverTheme found in context.');
    return result!;
  }

  static RiverTheme? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<RiverTheme>();

  @override
  bool updateShouldNotify(RiverTheme old) =>
      old.appTheme.colors != appTheme.colors ||
      old.appTheme.highContrast != appTheme.highContrast;
}
