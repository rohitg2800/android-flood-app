// lib/screens/admin_dashboard_screen.dart
library;

import 'package:flutter/material.dart';
import '../theme/river_theme.dart';
import '../widgets/app_back_button.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    return Scaffold(
      backgroundColor: t.scaffoldBg,
      appBar: AppBar(
        backgroundColor: t.navBg,
        foregroundColor: t.textPrimary,
        leading: const AppBackButton(),
        title: Text(
          'Admin Dashboard',
          style: TextStyle(color: t.textPrimary, fontWeight: FontWeight.w700),
        ),
        elevation: 0,
      ),
      body: Center(
        child: Text(
          'Admin Panel — coming soon',
          style: TextStyle(color: t.textSecondary),
        ),
      ),
    );
  }
}
