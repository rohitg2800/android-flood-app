import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/accessibility_provider.dart';

class AccessibilityScreen extends ConsumerWidget {
  const AccessibilityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(accessibilityProvider);
    final notifier = ref.read(accessibilityProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Accessibility'),
        actions: [
          TextButton(
            onPressed: () {
              notifier.resetToDefaults();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Settings reset to defaults')),
              );
            },
            child: const Text('Reset'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // ── Text Size ────────────────────────────────────────────
          _SectionHeader(title: 'Text'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Font Size'),
                    Text(
                      _fontSizeLabel(settings.fontSizeScale),
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, color: Colors.blue),
                    ),
                  ],
                ),
                Slider(
                  value: settings.fontSizeScale,
                  min: 0.8,
                  max: 1.6,
                  divisions: 4,
                  label: _fontSizeLabel(settings.fontSizeScale),
                  onChanged: notifier.setFontSizeScale,
                ),
                // Preview
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Sample flood alert text preview',
                    style: TextStyle(
                      fontSize: 14 * settings.fontSizeScale,
                      fontWeight: settings.boldText
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),

          _SettingsTile(
            title: 'Bold Text',
            subtitle: 'Make all text heavier and easier to read',
            icon: Icons.format_bold,
            value: settings.boldText,
            onChanged: (_) => notifier.toggleBoldText(),
          ),

          const Divider(indent: 16, endIndent: 16),

          // ── Display ──────────────────────────────────────────────
          _SectionHeader(title: 'Display'),

          _SettingsTile(
            title: 'High Contrast',
            subtitle: 'Increase colour contrast for better visibility',
            icon: Icons.contrast,
            value: settings.highContrast,
            onChanged: (_) => notifier.toggleHighContrast(),
          ),

          _SettingsTile(
            title: 'Large Icons',
            subtitle: 'Increase icon size throughout the app',
            icon: Icons.zoom_in,
            value: settings.largeIcons,
            onChanged: (_) => notifier.toggleLargeIcons(),
          ),

          // Theme mode
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Theme',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(
                        value: ThemeMode.light,
                        icon: Icon(Icons.light_mode),
                        label: Text('Light')),
                    ButtonSegment(
                        value: ThemeMode.system,
                        icon: Icon(Icons.brightness_auto),
                        label: Text('Auto')),
                    ButtonSegment(
                        value: ThemeMode.dark,
                        icon: Icon(Icons.dark_mode),
                        label: Text('Dark')),
                  ],
                  selected: {settings.themeMode},
                  onSelectionChanged: (modes) =>
                      notifier.setThemeMode(modes.first),
                ),
              ],
            ),
          ),

          const Divider(indent: 16, endIndent: 16),

          // ── Motion & Interaction ──────────────────────────────────
          _SectionHeader(title: 'Motion & Interaction'),

          _SettingsTile(
            title: 'Reduce Motion',
            subtitle: 'Minimise animations and transitions',
            icon: Icons.animation,
            value: settings.reduceMotion,
            onChanged: (_) => notifier.toggleReduceMotion(),
          ),

          _SettingsTile(
            title: 'Screen Reader Support',
            subtitle: 'Optimise layout for TalkBack / VoiceOver',
            icon: Icons.record_voice_over,
            value: settings.screenReaderOptimized,
            onChanged: (_) => notifier.toggleScreenReaderOptimized(),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  String _fontSizeLabel(double scale) {
    if (scale <= 0.85) return 'Small';
    if (scale <= 0.95) return 'Medium-Small';
    if (scale <= 1.05) return 'Normal';
    if (scale <= 1.25) return 'Large';
    if (scale <= 1.45) return 'X-Large';
    return 'XX-Large';
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingsTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      secondary: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      value: value,
      onChanged: onChanged,
    );
  }
}
