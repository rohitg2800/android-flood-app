// lib/screens/notification_settings_screen.dart  v2 — explicit back button
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/river_theme.dart';
import '../widgets/app_back_button.dart';

// ── simple local state ─────────────────────────────────────────────────────
final _pushEnabledProvider    = StateProvider<bool>((_) => true);
final _floodAlertsProvider    = StateProvider<bool>((_) => true);
final _weatherAlertsProvider  = StateProvider<bool>((_) => true);
final _dailyDigestProvider    = StateProvider<bool>((_) => false);
final _quietHoursProvider     = StateProvider<bool>((_) => false);

class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t            = RiverColors.of(context);
    final pushEnabled  = ref.watch(_pushEnabledProvider);
    final floodAlerts  = ref.watch(_floodAlertsProvider);
    final weatherAlert = ref.watch(_weatherAlertsProvider);
    final dailyDigest  = ref.watch(_dailyDigestProvider);
    final quietHours   = ref.watch(_quietHoursProvider);

    return Scaffold(
      backgroundColor: t.scaffoldBg,
      appBar: AppBar(
        backgroundColor: t.navBg,
        foregroundColor: t.textPrimary,
        leading: const AppBackButton(),
        title: Text(
          'Notifications',
          style: TextStyle(color: t.textPrimary, fontWeight: FontWeight.w700),
        ),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          _SectionHeader(label: 'Push Notifications', t: t),
          _SwitchTile(
            t: t,
            icon: Icons.notifications_active_rounded,
            title: 'Enable Push Notifications',
            subtitle: 'Master switch for all push alerts',
            value: pushEnabled,
            onChanged: (v) =>
                ref.read(_pushEnabledProvider.notifier).state = v,
          ),
          const SizedBox(height: 16),
          _SectionHeader(label: 'Alert Types', t: t),
          _SwitchTile(
            t: t,
            icon: Icons.flood_rounded,
            title: 'Flood Alerts',
            subtitle: 'Danger / warning level breach notifications',
            value: floodAlerts && pushEnabled,
            onChanged: pushEnabled
                ? (v) => ref.read(_floodAlertsProvider.notifier).state = v
                : null,
          ),
          _SwitchTile(
            t: t,
            icon: Icons.thunderstorm_rounded,
            title: 'Weather Alerts',
            subtitle: 'Heavy rainfall and storm warnings',
            value: weatherAlert && pushEnabled,
            onChanged: pushEnabled
                ? (v) => ref.read(_weatherAlertsProvider.notifier).state = v
                : null,
          ),
          _SwitchTile(
            t: t,
            icon: Icons.summarize_rounded,
            title: 'Daily Digest',
            subtitle: 'Morning summary of river conditions',
            value: dailyDigest && pushEnabled,
            onChanged: pushEnabled
                ? (v) => ref.read(_dailyDigestProvider.notifier).state = v
                : null,
          ),
          const SizedBox(height: 16),
          _SectionHeader(label: 'Schedule', t: t),
          _SwitchTile(
            t: t,
            icon: Icons.bedtime_rounded,
            title: 'Quiet Hours (10 PM – 6 AM)',
            subtitle: 'Silence non-critical alerts at night',
            value: quietHours,
            onChanged: (v) =>
                ref.read(_quietHoursProvider.notifier).state = v,
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, required this.t});
  final String label;
  final RiverColors t;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 6),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: t.accent,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.t,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });
  final RiverColors t;
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: SwitchListTile(
        secondary: Icon(icon,
            color: onChanged != null ? t.accent : t.textSecondary,
            size: 22),
        title: Text(title,
            style: TextStyle(
                color: onChanged != null ? t.textPrimary : t.textSecondary,
                fontWeight: FontWeight.w600,
                fontSize: 14)),
        subtitle: Text(subtitle,
            style: TextStyle(color: t.textSecondary, fontSize: 12)),
        value: value,
        activeColor: t.accent,
        onChanged: onChanged,
      ),
    );
  }
}
