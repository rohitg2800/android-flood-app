// lib/widgets/theme_aware_scaffold.dart
// Drop-in Scaffold replacement that automatically sets scaffoldBackgroundColor
// and appBar style from the active RiverColors theme extension.
//
// Every screen should use ThemeAwareScaffold instead of raw Scaffold so that
// background / appBar colours respond to theme changes without any extra code.
library;

import 'package:flutter/material.dart';
import '../theme/rx.dart';

class ThemeAwareScaffold extends StatelessWidget {
  const ThemeAwareScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.drawer,
    this.endDrawer,
    this.resizeToAvoidBottomInset,
    this.extendBody = false,
    this.extendBodyBehindAppBar = false,
  });

  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final Widget? drawer;
  final Widget? endDrawer;
  final bool? resizeToAvoidBottomInset;
  final bool extendBody;
  final bool extendBodyBehindAppBar;

  @override
  Widget build(BuildContext context) {
    final rc = context.rc;
    return Scaffold(
      key: key,
      backgroundColor: rc.scaffoldBg,
      appBar: appBar,
      body: body,
      bottomNavigationBar: bottomNavigationBar,
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
      drawer: drawer,
      endDrawer: endDrawer,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      extendBody: extendBody,
      extendBodyBehindAppBar: extendBodyBehindAppBar,
    );
  }
}

/// Build a standard themed AppBar with automatic colours from RiverColors.
PreferredSizeWidget rxAppBar({
  required BuildContext context,
  required String title,
  List<Widget>? actions,
  bool centerTitle = false,
  Widget? leading,
  double elevation = 0,
}) {
  final rc = context.rc;
  return AppBar(
    backgroundColor: rc.navBg,
    foregroundColor: rc.textPrimary,
    elevation: elevation,
    centerTitle: centerTitle,
    surfaceTintColor: Colors.transparent,
    leading: leading,
    title: Text(
      title,
      style: TextStyle(
        color: rc.textPrimary,
        fontSize: 20,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
      ),
    ),
    actions: actions,
    iconTheme: IconThemeData(color: rc.accent),
  );
}
