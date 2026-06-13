// lib/screens/community_screen.dart
library;

import 'package:flutter/material.dart';
import '../theme/river_theme.dart';

/// Minimal CommunityScreen stub — const-constructible so router
/// switch-case can reference CommunityScreen.route as a constant.
class CommunityScreen extends StatelessWidget {
  const CommunityScreen({super.key});

  static const String route = '/community';

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    return Scaffold(
      backgroundColor: t.scaffoldBg,
      appBar: AppBar(
        title: const Text('Community'),
        backgroundColor: t.navBg,
        foregroundColor: t.textPrimary,
        elevation: 0,
      ),
      body: Center(
        child: Text(
          'Community feed\n(coming soon)',
          textAlign: TextAlign.center,
          style: TextStyle(color: t.textSecondary, fontSize: 16),
        ),
      ),
    );
  }
}
