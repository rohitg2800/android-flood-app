// lib/screens/settings_screen.dart
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/river_theme.dart';
import '../theme/theme_registry.dart';
import '../theme/theme_3d.dart';
import '../providers/theme_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static const String route = '/settings';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t    = RiverColors.of(context);
    final mode = ref.watch(themeModeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: t.scaffoldBg,
      body: CustomScrollView(
        slivers: [
          Td3AppBar(
            title: 'Settings',
            subtitle: 'App preferences',
            leading: Navigator.canPop(context)
                ? IconButton(
                    icon: Icon(Icons.arrow_back_ios_new_rounded,
                        color: t.textPrimary, size: 18),
                    onPressed: () => Navigator.pop(context),
                  )
                : null,
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const Td3SectionHeader('Appearance'),
                const SizedBox(height: 10),
                Td3Card(
                  elevation: Td3.elevMid,
                  child: Column(
                    children: [
                      _SettingsTile(
                        icon: Icons.palette_rounded,
                        title: 'Theme',
                        subtitle: mode.name,
                        onTap: () => _showThemePicker(context, ref),
                      ),
                      const Td3Divider(),
                      _SettingsTile(
                        icon: Icons.dark_mode_rounded,
                        title: 'Dark Mode',
                        subtitle: isDark ? 'On' : 'Off',
                        onTap: () {
                          final notifier =
                              ref.read(themeModeProvider.notifier);
                          notifier.setMode(
                              isDark ? AppThemeMode.light : AppThemeMode.dark);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Td3SectionHeader('About'),
                const SizedBox(height: 10),
                Td3Card(
                  elevation: Td3.elevMid,
                  child: _SettingsTile(
                    icon: Icons.info_outline_rounded,
                    title: 'OpsFlood',
                    subtitle: 'v1.0.0',
                    onTap: () {},
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  void _showThemePicker(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (_) => _ThemePickerSheet(ref: ref),
    );
  }
}

class _ThemePickerSheet extends ConsumerWidget {
  const _ThemePickerSheet({required this.ref});
  final WidgetRef ref;

  @override
  Widget build(BuildContext context, WidgetRef innerRef) {
    final t    = RiverColors.of(context);
    final mode = innerRef.watch(themeModeProvider);
    return Container(
      color: t.cardBg,
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: AppThemeMode.values.map((m) => ListTile(
          title: Text(m.name,
              style: TextStyle(
                  color: m == mode ? t.accent : t.textPrimary)),
          trailing: m == mode
              ? Icon(Icons.check_rounded, color: t.accent)
              : null,
          onTap: () {
            innerRef.read(themeModeProvider.notifier).setMode(m);
            Navigator.pop(context);
          },
        )).toList(),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData  icon;
  final String    title;
  final String    subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    return ListTile(
      leading:  Icon(icon, color: t.accent, size: 22),
      title:    Text(title,   style: TextStyle(color: t.textPrimary,   fontSize: 14, fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: TextStyle(color: t.textSecondary, fontSize: 12)),
      trailing: Icon(Icons.chevron_right_rounded, color: t.textSecondary, size: 18),
      onTap:    onTap,
    );
  }
}
