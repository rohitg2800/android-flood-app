// lib/theme/theme_registry.dart
// ═══════════════════════════════════════════════════════════════════════════
// ThemeRegistry — Universe Command Center Edition
//
// Defines two skins:
//   AppSkin.deepSpace   — ‘Deep-Space Universe’: midnight blues, cyan glows
//   AppSkin.tacticalOps — ‘Tactical-Ops Robotic’: near-black, amber/green HUD
//
// Riverpod v3: appSkinProvider (NotifierProvider) holds the active skin.
// Any widget reads: final skin = ref.watch(appSkinProvider);
//                   final rc   = ref.watch(themeRegistryProvider);
// ═══════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ─── Skin enum ────────────────────────────────────────────────────────────────────
enum AppSkin {
  deepSpace, // Universe — dark navy + cyan
  tacticalOps, // Robotic  — near-black + amber/green HUD
}

// ─── SkinTokens ────────────────────────────────────────────────────────────────────
// Pure data — no BuildContext needed. Consumed directly by widgets.
class SkinTokens {
  // — Identity
  final AppSkin skin;
  final String displayName;

  // — Scaffold / surface
  final Color scaffoldBg;
  final Color surfaceLow; // card bg base layer
  final Color surfaceMid; // elevated card / modal
  final Color surfaceHigh; // chip / badge bg
  final Color divider;
  final Color stroke; // borders

  // — Text
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;

  // — Accent system
  final Color accent; // primary glow color
  final Color accentDim; // 30% opacity accent
  final Color accentContrast; // text on accent bg
  final Color accentSecondary; // secondary highlight

  // — Semantic colors
  final Color danger; // above danger level
  final Color warning; // above warning level
  final Color safe; // below warning
  final Color critical; // extreme / HFL exceeded

  // — Glow & shadow
  final List<BoxShadow> cardGlow; // terminal card glow
  final List<BoxShadow> accentGlow; // accent button glow
  final List<BoxShadow> dangerGlow; // danger badge glow

  // — Borders
  final BoxDecoration terminalBox; // data-terminal card decoration
  final BoxDecoration gaugeBox; // gauge container decoration
  final BoxDecoration chipBox; // small chip decoration
  final BorderRadius cardRadius;
  final BorderRadius chipRadius;

  // — Typography
  final TextStyle monoLg; // large monospace number (water level)
  final TextStyle monoMd; // medium monospace
  final TextStyle monoSm; // small monospace
  final TextStyle labelSm; // uppercase tracking label
  final TextStyle labelXs; // tiny uppercase label
  final TextStyle bodyMd; // body text

  // — Animation timing
  final Duration entryDuration; // card slide-in duration
  final Duration pulseDuration; // live-badge pulse duration
  final Curve entryCurve;

  const SkinTokens({
    required this.skin,
    required this.displayName,
    required this.scaffoldBg,
    required this.surfaceLow,
    required this.surfaceMid,
    required this.surfaceHigh,
    required this.divider,
    required this.stroke,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.accent,
    required this.accentDim,
    required this.accentContrast,
    required this.accentSecondary,
    required this.danger,
    required this.warning,
    required this.safe,
    required this.critical,
    required this.cardGlow,
    required this.accentGlow,
    required this.dangerGlow,
    required this.terminalBox,
    required this.gaugeBox,
    required this.chipBox,
    required this.cardRadius,
    required this.chipRadius,
    required this.monoLg,
    required this.monoMd,
    required this.monoSm,
    required this.labelSm,
    required this.labelXs,
    required this.bodyMd,
    required this.entryDuration,
    required this.pulseDuration,
    required this.entryCurve,
  });

  // Helper: semantic color for a water level vs thresholds
  Color levelColor(double current, double warning, double danger) {
    if (current >= danger) return this.danger;
    if (current >= warning) return this.warning;
    return safe;
  }

  // Helper: glow shadow for a semantic color
  List<BoxShadow> glowFor(Color c, {double spread = 0, double blur = 12}) => [
        BoxShadow(
            color: c.withValues(alpha: 0.35),
            blurRadius: blur,
            spreadRadius: spread),
        BoxShadow(
            color: c.withValues(alpha: 0.12),
            blurRadius: blur * 2.5,
            spreadRadius: spread + 2),
      ];
}

// ─── Deep-Space skin ───────────────────────────────────────────────────────────────────
// Palette: deep navy (#0a0e1a) + void-black surfaces + cyan-400 (#22d3ee) accent
// Font: JetBrains Mono — pure terminal aesthetic
const _dsAccent = Color(0xFF22d3ee); // cyan-400
const _dsAccentAlt = Color(0xFF818cf8); // indigo-400 secondary
const _dsDanger = Color(0xFFf87171); // red-400
const _dsWarning = Color(0xFFfbbf24); // amber-400
const _dsSafe = Color(0xFF4ade80); // green-400
const _dsCritical = Color(0xFFff4560); // deep red

final _deepSpaceTokens = SkinTokens(
  skin: AppSkin.deepSpace,
  displayName: 'Deep-Space',

  scaffoldBg: const Color(0xFF070b14),
  surfaceLow: const Color(0xFF0d1221),
  surfaceMid: const Color(0xFF111827),
  surfaceHigh: const Color(0xFF1a2235),
  divider: const Color(0xFF1e2d45),
  stroke: const Color(0xFF22d3ee).withValues(alpha: 0.18),

  textPrimary: const Color(0xFFe2e8f0),
  textSecondary: const Color(0xFF94a3b8),
  textMuted: const Color(0xFF475569),

  accent: _dsAccent,
  accentDim: _dsAccent.withValues(alpha: 0.18),
  accentContrast: const Color(0xFF070b14),
  accentSecondary: _dsAccentAlt,

  danger: _dsDanger,
  warning: _dsWarning,
  safe: _dsSafe,
  critical: _dsCritical,

  cardGlow: [
    BoxShadow(
        color: _dsAccent.withValues(alpha: 0.10),
        blurRadius: 20,
        spreadRadius: -4),
    BoxShadow(
        color: const Color(0xFF000000).withValues(alpha: 0.6),
        blurRadius: 8,
        offset: const Offset(0, 4)),
  ],
  accentGlow: [
    BoxShadow(
        color: _dsAccent.withValues(alpha: 0.45),
        blurRadius: 16,
        spreadRadius: 0),
    BoxShadow(
        color: _dsAccent.withValues(alpha: 0.15),
        blurRadius: 32,
        spreadRadius: 4),
  ],
  dangerGlow: [
    BoxShadow(color: _dsDanger.withValues(alpha: 0.45), blurRadius: 14),
    BoxShadow(
        color: _dsDanger.withValues(alpha: 0.15),
        blurRadius: 28,
        spreadRadius: 2),
  ],

  terminalBox: BoxDecoration(
    color: const Color(0xFF0d1221),
    borderRadius: BorderRadius.circular(10),
    border: Border.all(color: _dsAccent.withValues(alpha: 0.22), width: 1),
    boxShadow: [
      BoxShadow(
          color: _dsAccent.withValues(alpha: 0.08),
          blurRadius: 18,
          spreadRadius: -2),
    ],
  ),
  gaugeBox: BoxDecoration(
    color: const Color(0xFF0d1221),
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: _dsAccent.withValues(alpha: 0.30), width: 1),
    boxShadow: [
      BoxShadow(
          color: _dsAccent.withValues(alpha: 0.14),
          blurRadius: 24,
          spreadRadius: 0),
    ],
  ),
  chipBox: BoxDecoration(
    color: _dsAccent.withValues(alpha: 0.12),
    borderRadius: BorderRadius.circular(5),
    border: Border.all(color: _dsAccent.withValues(alpha: 0.35), width: 1),
  ),

  cardRadius: BorderRadius.circular(10),
  chipRadius: BorderRadius.circular(5),

  // Monospace typography — JetBrains Mono
  monoLg: const TextStyle(
    fontFamily: 'JetBrainsMono',
    fontSize: 28,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.5,
    color: _dsAccent,
    height: 1.0,
  ),
  monoMd: const TextStyle(
    fontFamily: 'JetBrainsMono',
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.2,
    color: _dsAccent,
  ),
  monoSm: const TextStyle(
    fontFamily: 'JetBrainsMono',
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.8,
    color: Color(0xFF94a3b8),
  ),
  labelSm: const TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.4,
    color: Color(0xFF94a3b8),
  ),
  labelXs: const TextStyle(
    fontSize: 9,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.2,
    color: Color(0xFF475569),
  ),
  bodyMd: const TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: Color(0xFFe2e8f0),
    height: 1.4,
  ),

  entryDuration: const Duration(milliseconds: 480),
  pulseDuration: const Duration(milliseconds: 1400),
  entryCurve: Curves.easeOutCubic,
);

// ─── Tactical-Ops skin ─────────────────────────────────────────────────────────────────
// Palette: void-black (#080b0f) + sharp amber (#f59e0b) HUD + green-500 data
const _toAccent = Color(0xFFf59e0b); // amber-500
const _toAccentAlt = Color(0xFF22c55e); // green-500
const _toDanger = Color(0xFFef4444); // red-500
const _toWarning = Color(0xFFf97316); // orange-500
const _toSafe = Color(0xFF22c55e); // green-500
const _toCritical = Color(0xFFdc2626); // red-600

final _tacticalOpsTokens = SkinTokens(
  skin: AppSkin.tacticalOps,
  displayName: 'Tactical-Ops',

  scaffoldBg: const Color(0xFF080b0f),
  surfaceLow: const Color(0xFF0e1117),
  surfaceMid: const Color(0xFF131920),
  surfaceHigh: const Color(0xFF1a2130),
  divider: const Color(0xFF1f2937),
  stroke: const Color(0xFFf59e0b).withValues(alpha: 0.20),

  textPrimary: const Color(0xFFf1f5f9),
  textSecondary: const Color(0xFF9ca3af),
  textMuted: const Color(0xFF4b5563),

  accent: _toAccent,
  accentDim: _toAccent.withValues(alpha: 0.14),
  accentContrast: const Color(0xFF080b0f),
  accentSecondary: _toAccentAlt,

  danger: _toDanger,
  warning: _toWarning,
  safe: _toSafe,
  critical: _toCritical,

  cardGlow: [
    BoxShadow(
        color: _toAccent.withValues(alpha: 0.08),
        blurRadius: 16,
        spreadRadius: -4),
    BoxShadow(
        color: const Color(0xFF000000).withValues(alpha: 0.7),
        blurRadius: 8,
        offset: const Offset(0, 4)),
  ],
  accentGlow: [
    BoxShadow(color: _toAccent.withValues(alpha: 0.50), blurRadius: 14),
    BoxShadow(
        color: _toAccent.withValues(alpha: 0.18),
        blurRadius: 30,
        spreadRadius: 4),
  ],
  dangerGlow: [
    BoxShadow(color: _toDanger.withValues(alpha: 0.50), blurRadius: 12),
    BoxShadow(
        color: _toDanger.withValues(alpha: 0.18),
        blurRadius: 26,
        spreadRadius: 2),
  ],

  terminalBox: BoxDecoration(
    color: const Color(0xFF0e1117),
    borderRadius: BorderRadius.circular(6), // sharper corners
    border: Border.all(color: _toAccent.withValues(alpha: 0.24), width: 1),
    boxShadow: [
      BoxShadow(
          color: _toAccent.withValues(alpha: 0.06),
          blurRadius: 14,
          spreadRadius: -2),
    ],
  ),
  gaugeBox: BoxDecoration(
    color: const Color(0xFF0e1117),
    borderRadius: BorderRadius.circular(6),
    border: Border.all(color: _toAccent.withValues(alpha: 0.28), width: 1),
    boxShadow: [
      BoxShadow(color: _toAccent.withValues(alpha: 0.10), blurRadius: 18),
    ],
  ),
  chipBox: BoxDecoration(
    color: _toAccent.withValues(alpha: 0.10),
    borderRadius: BorderRadius.circular(3), // sharp
    border: Border.all(color: _toAccent.withValues(alpha: 0.40), width: 1),
  ),

  cardRadius: BorderRadius.circular(6),
  chipRadius: BorderRadius.circular(3),

  // Monospace typography — JetBrains Mono (amber tint for Tactical)
  monoLg: const TextStyle(
    fontFamily: 'JetBrainsMono',
    fontSize: 28,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.5,
    color: _toAccent,
    height: 1.0,
  ),
  monoMd: const TextStyle(
    fontFamily: 'JetBrainsMono',
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.2,
    color: _toAccent,
  ),
  monoSm: const TextStyle(
    fontFamily: 'JetBrainsMono',
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.8,
    color: Color(0xFF9ca3af),
  ),
  labelSm: const TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.4,
    color: Color(0xFF9ca3af),
  ),
  labelXs: const TextStyle(
    fontSize: 9,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.2,
    color: Color(0xFF4b5563),
  ),
  bodyMd: const TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: Color(0xFFf1f5f9),
    height: 1.4,
  ),

  entryDuration: const Duration(milliseconds: 360),
  pulseDuration: const Duration(milliseconds: 900),
  entryCurve: Curves.easeOutQuart,
);

// ─── ThemeRegistry ───────────────────────────────────────────────────────────────────
class ThemeRegistry {
  static SkinTokens of(AppSkin skin) {
    switch (skin) {
      case AppSkin.deepSpace:
        return _deepSpaceTokens;
      case AppSkin.tacticalOps:
        return _tacticalOpsTokens;
    }
  }

  static SkinTokens get deepSpace => _deepSpaceTokens;
  static SkinTokens get tacticalOps => _tacticalOpsTokens;

  static const all = [AppSkin.deepSpace, AppSkin.tacticalOps];
}

// ─── Riverpod v3 providers ─────────────────────────────────────────────────────────────

/// Holds which skin is active. Toggle via:
///   ref.read(appSkinProvider.notifier).toggle();
///   ref.read(appSkinProvider.notifier).set(AppSkin.tacticalOps);
class AppSkinNotifier extends Notifier<AppSkin> {
  @override
  AppSkin build() => AppSkin.deepSpace; // default skin

  void toggle() {
    state =
        state == AppSkin.deepSpace ? AppSkin.tacticalOps : AppSkin.deepSpace;
  }

  void set(AppSkin skin) => state = skin;
}

final appSkinProvider =
    NotifierProvider<AppSkinNotifier, AppSkin>(AppSkinNotifier.new);

/// Derived provider — always returns the active SkinTokens.
/// Widgets that only need colors use this; they rebuild only when skin changes.
final themeRegistryProvider = Provider<SkinTokens>((ref) {
  return ThemeRegistry.of(ref.watch(appSkinProvider));
});
