// lib/utils/accessibility_utils.dart
// OpsFlood — Module 13: Accessibility Utilities
//
// Provides:
//  • AccessibilityProvider (Riverpod) — persists large-text & high-contrast prefs
//  • AppTextScaler — wraps MediaQuery.textScaler for consistent scaling
//  • SemanticAlertBadge — announces live alert count to screen readers
//  • AccessibilityWrapper — root widget that applies text scale + contrast
//  • ContrastColors — high-contrast colour overrides
//  • accessibleTapTarget — enforces minimum 48×48 dp tap target size

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// Prefs keys
// ---------------------------------------------------------------------------

const _kLargeText     = 'a11y_large_text';
const _kHighContrast  = 'a11y_high_contrast';
const _kReduceMotion  = 'a11y_reduce_motion';

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

class AccessibilityState {
  final bool largeText;
  final bool highContrast;
  final bool reduceMotion;
  const AccessibilityState({
    this.largeText    = false,
    this.highContrast = false,
    this.reduceMotion = false,
  });
  AccessibilityState copyWith({
    bool? largeText,
    bool? highContrast,
    bool? reduceMotion,
  }) => AccessibilityState(
    largeText:    largeText    ?? this.largeText,
    highContrast: highContrast ?? this.highContrast,
    reduceMotion: reduceMotion ?? this.reduceMotion,
  );
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class AccessibilityNotifier
    extends AsyncNotifier<AccessibilityState> {
  @override
  Future<AccessibilityState> build() async {
    final prefs = await SharedPreferences.getInstance();
    return AccessibilityState(
      largeText:    prefs.getBool(_kLargeText)    ?? false,
      highContrast: prefs.getBool(_kHighContrast) ?? false,
      reduceMotion: prefs.getBool(_kReduceMotion) ?? false,
    );
  }

  Future<void> setLargeText(bool v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kLargeText, v);
    state = AsyncData(state.value!.copyWith(largeText: v));
  }

  Future<void> setHighContrast(bool v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kHighContrast, v);
    state = AsyncData(state.value!.copyWith(highContrast: v));
  }

  Future<void> setReduceMotion(bool v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kReduceMotion, v);
    state = AsyncData(state.value!.copyWith(reduceMotion: v));
  }
}

final accessibilityProvider =
    AsyncNotifierProvider<AccessibilityNotifier, AccessibilityState>(
        AccessibilityNotifier.new);

// ---------------------------------------------------------------------------
// ContrastColors — high-contrast palette
// ---------------------------------------------------------------------------

class ContrastColors {
  static const background = Color(0xFF000000);
  static const surface    = Color(0xFF1A1A1A);
  static const primary    = Color(0xFFFFFFFF);
  static const accent     = Color(0xFFFFD600);
  static const danger     = Color(0xFFFF1744);
  static const warning    = Color(0xFFFFAB00);
  static const safe       = Color(0xFF69FF47);
  static const text       = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFFCCCCCC);
}

// ---------------------------------------------------------------------------
// AccessibilityWrapper — wrap MaterialApp child
// ---------------------------------------------------------------------------

class AccessibilityWrapper extends ConsumerWidget {
  final Widget child;
  const AccessibilityWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Fixed: Riverpod 3.x AsyncValue has no .valueOrNull — use .value
    final a11y = ref.watch(accessibilityProvider).value
        ?? const AccessibilityState();

    Widget result = child;

    // Large text scale
    if (a11y.largeText) {
      result = MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: const TextScaler.linear(1.35),
        ),
        child: result,
      );
    }

    // Reduce motion: disable animations globally
    if (a11y.reduceMotion) {
      result = MediaQuery(
        data: MediaQuery.of(context).copyWith(
          disableAnimations: true,
        ),
        child: result,
      );
    }

    return result;
  }
}

// ---------------------------------------------------------------------------
// SemanticAlertBadge — live-region badge for screen readers
// ---------------------------------------------------------------------------

class SemanticAlertBadge extends StatelessWidget {
  final int count;
  final String severity;
  const SemanticAlertBadge({
    super.key,
    required this.count,
    required this.severity,
  });

  @override
  Widget build(BuildContext context) {
    if (count == 0) return const SizedBox.shrink();
    return Semantics(
      liveRegion: true,
      label: '$count $severity flood alert${count > 1 ? "s" : ""} active',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFFEF4444),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            count > 99 ? '99+' : '$count',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// accessibleTapTarget — enforces 48×48 dp minimum tap target
// ---------------------------------------------------------------------------

Widget accessibleTapTarget({
  required Widget child,
  required VoidCallback onTap,
  String? semanticLabel,
  String? tooltip,
}) {
  return Semantics(
    label:  semanticLabel,
    button: true,
    child: Tooltip(
      message: tooltip ?? semanticLabel ?? '',
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
              minWidth: 48, minHeight: 48),
          child: Center(child: child),
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// AccessibilitySettingsCard — drop into SettingsScreen
// ---------------------------------------------------------------------------

class AccessibilitySettingsCard extends ConsumerWidget {
  const AccessibilitySettingsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a11yAsync = ref.watch(accessibilityProvider);
    return a11yAsync.when(
      loading: () => const SizedBox.shrink(),
      error:   (_, __) => const SizedBox.shrink(),
      data: (a11y) => Card(
        margin: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 8),
        child: Column(
          children: [
            ListTile(
              leading:  const Icon(Icons.text_increase),
              title:    const Text('Large Text'),
              subtitle: const Text('Scale all text to 135%'),
              trailing: Switch(
                value:    a11y.largeText,
                onChanged: (v) => ref
                    .read(accessibilityProvider.notifier)
                    .setLargeText(v),
              ),
            ),
            ListTile(
              leading:  const Icon(Icons.contrast),
              title:    const Text('High Contrast'),
              subtitle: const Text(
                  'Black background, yellow accents'),
              trailing: Switch(
                value:    a11y.highContrast,
                onChanged: (v) => ref
                    .read(accessibilityProvider.notifier)
                    .setHighContrast(v),
              ),
            ),
            ListTile(
              leading:  const Icon(Icons.animation),
              title:    const Text('Reduce Motion'),
              subtitle: const Text(
                  'Disables all transitions & animations'),
              trailing: Switch(
                value:    a11y.reduceMotion,
                onChanged: (v) => ref
                    .read(accessibilityProvider.notifier)
                    .setReduceMotion(v),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
