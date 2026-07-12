// lib/constants/flood_thresholds.dart
// Domain: flood severity thresholds, water level defaults, risk color/icon maps

class FloodThresholds {
  // ── Capacity % thresholds ─────────────────────────────────────────────────
  static const double critical = 90.0;
  static const double high = 75.0;
  static const double moderate = 50.0;

  // ── Default CWC water levels (metres) ─────────────────────────────────────
  static const double defaultDangerLevel = 12.0;
  static const double defaultWarningLevel = 10.32;
  static const double defaultSafeLevel = 8.0;

  // ── Risk colour palette (ARGB hex) ────────────────────────────────────────
  static const Map<String, int> riskColors = {
    'LOW': 0xFF34C759,
    'MODERATE': 0xFFF59E0B,
    'SEVERE': 0xFFFF5500,
    'CRITICAL': 0xFF8B0000,
    'HIGH': 0xFFEF4444,
  };

  // ── Risk icon tags ─────────────────────────────────────────────────────────
  static const Map<String, String> riskIcons = {
    'LOW': 'SAFE',
    'MODERATE': 'WATCH',
    'SEVERE': 'WARN',
    'CRITICAL': 'ALERT',
    'HIGH': 'WARN',
  };
}

// ── Shared severity classifier — single source of truth ──────────────────
// Use this everywhere instead of inline pct/riskScore comparisons.
// predict_screen_impl.dart and bihar_prediction_provider.dart both call this.
String severityFromPercent(double pct) {
  if (pct >= 100) return 'CRITICAL';
  if (pct >= 80) return 'SEVERE';
  if (pct >= 65) return 'MODERATE';
  return 'LOW';
}
