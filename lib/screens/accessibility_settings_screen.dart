// lib/screens/accessibility_settings_screen.dart  v2 — explicit back button
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/river_theme.dart';
import '../widgets/app_back_button.dart';

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------
final _textScaleProvider    = StateProvider<double>((_) => 1.0);
final _highContrastProvider = StateProvider<bool>((_)   => false);
final _boldTextProvider     = StateProvider<bool>((_)   => false);
final _reduceMotionProvider = StateProvider<bool>((_)   => false);

class AccessibilitySettingsScreen extends ConsumerWidget {
  const AccessibilitySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t            = RiverColors.of(context);
    final textScale    = ref.watch(_textScaleProvider);
    final highContrast = ref.watch(_highContrastProvider);
    final boldText     = ref.watch(_boldTextProvider);
    final reduceMotion = ref.watch(_reduceMotionProvider);

    return Scaffold(
      backgroundColor: t.scaffoldBg,
      appBar: AppBar(
        backgroundColor: t.navBg,
        foregroundColor: t.textPrimary,
        leading: const AppBackButton(),
        title: Text(
          'Accessibility',
          style: TextStyle(color: t.textPrimary, fontWeight: FontWeight.w700),
        ),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          _SectionHeader(label: 'Display', t: t),
          _SwitchTile(
            t: t,
            icon: Icons.contrast_rounded,
            title: 'High Contrast',
            subtitle: 'Increases colour contrast for better readability',
            value: highContrast,
            onChanged: (v) => ref.read(_highContrastProvider.notifier).state = v,
          ),
          _SwitchTile(
            t: t,
            icon: Icons.format_bold_rounded,
            title: 'Bold Text',
            subtitle: 'Makes all text heavier weight',
            value: boldText,
            onChanged: (v) => ref.read(_boldTextProvider.notifier).state = v,
          ),
          const SizedBox(height: 16),
          _SectionHeader(label: 'Text Size', t: t),
          _SliderTile(
            t: t,
            label: 'Scale: ${textScale.toStringAsFixed(1)}×',
            value: textScale,
            min: 0.8,
            max: 1.6,
            divisions: 8,
            onChanged: (v) => ref.read(_textScaleProvider.notifier).state = v,
          ),
          const SizedBox(height: 16),
          _SectionHeader(label: 'Motion', t: t),
          _SwitchTile(
            t: t,
            icon: Icons.animation_rounded,
            title: 'Reduce Motion',
            subtitle: 'Minimises animations throughout the app',
            value: reduceMotion,
            onChanged: (v) => ref.read(_reduceMotionProvider.notifier).state = v,
          ),
          const SizedBox(height: 32),
          _InfoCard(
            t: t,
            text: 'These settings are stored locally. Some may require an app restart.',
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------
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
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: SwitchListTile(
        secondary: Icon(icon, color: t.accent, size: 22),
        title: Text(title,
            style: TextStyle(
                color: t.textPrimary,
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

class _SliderTile extends StatelessWidget {
  const _SliderTile({
    required this.t,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });
  final RiverColors t;
  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  color: t.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14)),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            activeColor: t.accent,
            inactiveColor: t.accent.withValues(alpha: 0.2),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.t, required this.text});
  final RiverColors t;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: t.accent.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, color: t.accent, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: t.textSecondary, fontSize: 12, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
