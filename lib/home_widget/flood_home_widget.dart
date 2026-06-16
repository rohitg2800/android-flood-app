// lib/home_widget/flood_home_widget.dart
// PHASE 3 — Android / iOS home-screen widget updater
//
// Uses the `home_widget` package to push the worst flood station data
// to the native home-screen widget so users can see live status without
// opening the app.
//
// Setup required (one-time, already in your pubspec if home_widget exists):
//   Android: android/app/src/main/res/layout/flood_widget.xml  (your layout)
//   iOS:     ios/FloodWidget/FloodWidget.swift
//
// Call FloodHomeWidget.update(prediction) from DataFetchEngine.onNewSnapshot()
// or from a background fetch handler.
library;

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import '../models/flood_prediction.dart';
import '../providers/prediction_provider.dart';

abstract final class FloodHomeWidget {
  // Android widget provider class name (matches AndroidManifest)
  static const _androidProvider =
      'com.opsflood.android.FloodWidgetProvider';

  // iOS widget kind (matches widget extension)
  static const _iOSKind = 'FloodWidget';

  /// Push the worst-station prediction to the home-screen widget.
  /// Safe to call from any isolate — catches and logs errors silently.
  static Future<void> update(FloodPrediction p) async {
    try {
      await Future.wait([
        HomeWidget.saveWidgetData<String>('station',    p.station),
        HomeWidget.saveWidgetData<String>('river',      p.river),
        HomeWidget.saveWidgetData<String>(
            'level',    '${p.currentLevel.toStringAsFixed(2)} m'),
        HomeWidget.saveWidgetData<String>(
            'danger',   '${p.dangerLevel.toStringAsFixed(2)} m'),
        HomeWidget.saveWidgetData<int>(
            'pct',      p.progressPct.round().clamp(0, 100)),
        HomeWidget.saveWidgetData<String>('trend',      p.trend),
        HomeWidget.saveWidgetData<String>('outlook',    p.outlook),
        HomeWidget.saveWidgetData<String>(
            'risk',     p.riskScore.toStringAsFixed(1)),
        HomeWidget.saveWidgetData<String>(
            'updated',  _fmtNow()),
      ]);

      await HomeWidget.updateWidget(
        androidName: _androidProvider,
        iOSName:     _iOSKind,
      );
    } catch (e, st) {
      // Never crash the main app over a widget update failure
      debugPrint('[FloodHomeWidget] update error: $e\n$st');
    }
  }

  /// Clear widget to a safe "loading" state (call on app first-launch).
  static Future<void> reset() async {
    try {
      await Future.wait([
        HomeWidget.saveWidgetData<String>('station', 'Loading…'),
        HomeWidget.saveWidgetData<String>('river',   '—'),
        HomeWidget.saveWidgetData<String>('level',   '—'),
        HomeWidget.saveWidgetData<int>   ('pct',     0),
        HomeWidget.saveWidgetData<String>('trend',   'stable'),
        HomeWidget.saveWidgetData<String>('outlook', 'Fetching data…'),
        HomeWidget.saveWidgetData<String>('updated', _fmtNow()),
      ]);
      await HomeWidget.updateWidget(
        androidName: _androidProvider,
        iOSName:     _iOSKind,
      );
    } catch (e) {
      debugPrint('[FloodHomeWidget] reset error: $e');
    }
  }

  /// Register a background callback so the widget can trigger a refresh
  /// from the home screen (Android only — "tap to refresh" button).
  static Future<void> registerInteractivityCallback(
      BackgroundCallback callback) async {
    try {
      await HomeWidget.registerInteractivityCallback(callback);
    } catch (e) {
      debugPrint('[FloodHomeWidget] interactivity register error: $e');
    }
  }

  // ── helpers ───────────────────────────────────────────────────────────
  static String _fmtNow() {
    final n = DateTime.now();
    final h = n.hour.toString().padLeft(2, '0');
    final m = n.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

/// Type alias for the home_widget background callback signature.
typedef BackgroundCallback = Future<void> Function(Uri? uri);
