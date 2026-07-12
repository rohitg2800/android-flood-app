// lib/screens/accessibility_settings_screen.dart  Step 5.5
// Accessibility section of Settings:
//   • High Contrast toggle
//   • Text scale slider (1.0 → 1.4 in 3 steps)
//   • Language selector (English | हिंदी | বাंলা | ଓଡ଼ିଆ)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/accessibility_provider.dart';
import '../theme/river_theme.dart';

class AccessibilitySettingsScreen extends ConsumerWidget {
  const AccessibilitySettingsScreen({super.key});
  static const String route = '/settings/accessibility';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = RiverColors.of(context);
    final state = ref.watch(accessibilityProvider);
    final notifier = ref.read(accessibilityProvider.notifier);

    return Scaffold(
      backgroundColor: t.scaffoldBg,
      appBar: AppBar(
        title: const Text('Accessibility'),
        backgroundColor: t.navBg,
        foregroundColor: t.textPrimary,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
        children: [
          // ── Section: Display
          _SectionHeader('Display', t),
          const SizedBox(height: 8),

          // High Contrast
          _SettingCard(
            t: t,
            child: SwitchListTile(
              value: state.highContrast,
              onChanged: notifier.setHighContrast,
              activeColor: t.accent,
              contentPadding: EdgeInsets.zero,
              title: Text('High Contrast',
                  style: TextStyle(
                      color: t.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700)),
              subtitle: Text(
                'Increases colour contrast for better readability (WCAG AA)',
                style: TextStyle(color: t.textSecondary, fontSize: 11),
              ),
              secondary: Icon(
                state.highContrast
                    ? Icons.contrast_rounded
                    : Icons.contrast_outlined,
                color: t.accent,
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Text Scale
          _SettingCard(
            t: t,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.text_fields_rounded, color: t.accent),
                  title: Text('Text Size',
                      style: TextStyle(
                          color: t.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700)),
                  subtitle: Text(
                    _scaleName(state.textScaleFactor),
                    style: TextStyle(color: t.textSecondary, fontSize: 11),
                  ),
                  trailing: Text(
                    '×${state.textScaleFactor.toStringAsFixed(1)}',
                    style: TextStyle(
                        color: t.accent,
                        fontWeight: FontWeight.w900,
                        fontSize: 14),
                  ),
                ),
                Slider(
                  value: state.textScaleFactor,
                  min: 1.0,
                  max: 1.4,
                  divisions: 4,
                  label: '×${state.textScaleFactor.toStringAsFixed(1)}',
                  activeColor: t.accent,
                  onChanged: notifier.setTextScale,
                ),
                // Live preview
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                        textScaler: TextScaler.linear(state.textScaleFactor)),
                    child: Text(
                      'Preview: River level 12.34 m — CRITICAL',
                      style: TextStyle(
                          color: AppPalette.critical,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── Section: Language
          _SectionHeader('Language', t),
          const SizedBox(height: 8),

          _SettingCard(
            t: t,
            child: Column(
              children: [
                _LangTile(
                  tag: 'en',
                  label: 'English',
                  selected: state.locale == 'en',
                  t: t,
                  onTap: () => notifier.setLocale('en'),
                ),
                _Divider(t),
                _LangTile(
                  tag: 'hi',
                  label: 'हिंदी (Hindi)',
                  selected: state.locale == 'hi',
                  t: t,
                  onTap: () => notifier.setLocale('hi'),
                ),
                _Divider(t),
                _LangTile(
                  tag: 'bn',
                  label: 'বাংলা (Bengali)',
                  selected: state.locale == 'bn',
                  t: t,
                  onTap: () => notifier.setLocale('bn'),
                ),
                _Divider(t),
                _LangTile(
                  tag: 'or',
                  label: 'ଓଡ଼ିଆ (Odia)',
                  selected: state.locale == 'or',
                  t: t,
                  onTap: () => notifier.setLocale('or'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── WCAG note
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: t.accent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: t.accent.withValues(alpha: 0.2)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.verified_outlined, color: t.accent, size: 16),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'OpsFlood targets WCAG 2.1 Level AA compliance. '
                    'High Contrast mode achieves ≥4.5:1 contrast ratio '
                    'for all body text.',
                    style: TextStyle(
                        color: t.textSecondary, fontSize: 11, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _scaleName(double v) {
    if (v <= 1.0) return 'Default';
    if (v <= 1.2) return 'Medium';
    if (v <= 1.3) return 'Large';
    return 'Extra Large';
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  final RiverColors t;
  const _SectionHeader(this.label, this.t);

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: TextStyle(
          color: t.accent,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2),
    );
  }
}

class _SettingCard extends StatelessWidget {
  final Widget child;
  final RiverColors t;
  const _SettingCard({required this.child, required this.t});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: t.cardBg,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: t.divider.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 3)),
          ],
        ),
        child: child,
      ),
    );
  }
}

class _LangTile extends StatelessWidget {
  final String tag, label;
  final bool selected;
  final RiverColors t;
  final VoidCallback onTap;
  const _LangTile({
    required this.tag,
    required this.label,
    required this.selected,
    required this.t,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      button: true,
      selected: selected,
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        onTap: onTap,
        title: Text(
          label,
          style: TextStyle(
              color: selected ? t.accent : t.textPrimary,
              fontSize: 14,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w500),
        ),
        trailing: selected
            ? Icon(Icons.check_circle_rounded, color: t.accent, size: 20)
            : Icon(Icons.circle_outlined, color: t.divider, size: 20),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  final RiverColors t;
  const _Divider(this.t);
  @override
  Widget build(BuildContext context) =>
      Divider(height: 1, color: t.divider.withValues(alpha: 0.3));
}
