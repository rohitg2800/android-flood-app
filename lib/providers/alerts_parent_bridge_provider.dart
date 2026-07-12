// lib/providers/alerts_parent_bridge_provider.dart
//
// AlertsParentBridgeState — thin shared-state bridge between the MainShell
// (parent) and the AlertsScreen (child tab).  Used to:
//   • track which alert tab (All / Critical / Severe / Warning) is active
//   • pass a pending deep-link stationFilter from the parent
//   • signal whether the badge should pulse

import 'package:flutter_riverpod/flutter_riverpod.dart';

// ── State class ─────────────────────────────────────────────────────────────

enum AlertsTab { all, critical, severe, warning }

class AlertsParentBridgeState {
  final AlertsTab activeTab;
  final String? pendingStationFilter;
  final bool badgePulse;

  const AlertsParentBridgeState({
    this.activeTab = AlertsTab.all,
    this.pendingStationFilter,
    this.badgePulse = false,
  });

  AlertsParentBridgeState copyWith({
    AlertsTab? activeTab,
    String? pendingStationFilter,
    bool clearFilter = false,
    bool? badgePulse,
  }) =>
      AlertsParentBridgeState(
        activeTab: activeTab ?? this.activeTab,
        pendingStationFilter: clearFilter
            ? null
            : pendingStationFilter ?? this.pendingStationFilter,
        badgePulse: badgePulse ?? this.badgePulse,
      );
}

// ── Notifier ────────────────────────────────────────────────────────────────

class AlertsParentBridgeNotifier extends Notifier<AlertsParentBridgeState> {
  @override
  AlertsParentBridgeState build() => const AlertsParentBridgeState();

  void setTab(AlertsTab tab) => state = state.copyWith(activeTab: tab);

  void setStationFilter(String? station) => state = state.copyWith(
        pendingStationFilter: station,
        clearFilter: station == null,
      );

  void clearFilter() => state = state.copyWith(clearFilter: true);

  void setBadgePulse({required bool pulse}) =>
      state = state.copyWith(badgePulse: pulse);
}

// ── Provider ────────────────────────────────────────────────────────────────

final alertsParentBridgeProvider =
    NotifierProvider<AlertsParentBridgeNotifier, AlertsParentBridgeState>(
  AlertsParentBridgeNotifier.new,
);
