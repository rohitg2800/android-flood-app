// lib/providers/bihar_dashboard_provider.dart
//
// BiharDashboardState — extra UI state for the dashboard screen:
//   • selectedDistrict filter
//   • sort order
//   • whether the summary strip is expanded
//
// Used by dashboard_screen.dart via ref.watch(biharDashboardProvider).

import 'package:flutter_riverpod/flutter_riverpod.dart';

// ── State class ─────────────────────────────────────────────────────────────

enum DashboardSort { alphabetical, riskDescending, levelDescending }

class BiharDashboardState {
  final String?       selectedDistrict;
  final DashboardSort sort;
  final bool          summaryExpanded;

  const BiharDashboardState({
    this.selectedDistrict,
    this.sort          = DashboardSort.riskDescending,
    this.summaryExpanded = true,
  });

  BiharDashboardState copyWith({
    String?       selectedDistrict,
    bool          clearDistrict = false,
    DashboardSort? sort,
    bool?          summaryExpanded,
  }) =>
      BiharDashboardState(
        selectedDistrict:
            clearDistrict ? null : selectedDistrict ?? this.selectedDistrict,
        sort:            sort            ?? this.sort,
        summaryExpanded: summaryExpanded ?? this.summaryExpanded,
      );
}

// ── Notifier ────────────────────────────────────────────────────────────────

class BiharDashboardNotifier extends Notifier<BiharDashboardState> {
  @override
  BiharDashboardState build() => const BiharDashboardState();

  void selectDistrict(String? district) =>
      state = state.copyWith(
        selectedDistrict: district,
        clearDistrict: district == null,
      );

  void setSort(DashboardSort sort) => state = state.copyWith(sort: sort);

  void toggleSummary() =>
      state = state.copyWith(summaryExpanded: !state.summaryExpanded);
}

// ── Provider ────────────────────────────────────────────────────────────────

final biharDashboardProvider =
    NotifierProvider<BiharDashboardNotifier, BiharDashboardState>(
  BiharDashboardNotifier.new,
);
