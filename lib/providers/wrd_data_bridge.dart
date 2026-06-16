// lib/providers/wrd_data_bridge.dart
// v1 — Bridge: exposes WRD parent data to every non-map screen
//             without those screens needing to know about WrdStation.
//
// Import this file in any screen that previously used its own fetch:
//   DashboardScreen, RiverMonitorScreen, AlertsScreen,
//   WeatherScreen, CityDetailScreen, PredictionScreen, LiveStationsScreen.
//
// Usage:
//   final stations = ref.watch(allBiharStationsProvider);
//   final critical = ref.watch(wrdCriticalStationsProvider);
//   final byRiver  = ref.watch(wrdByRiverProvider);
library;

export 'real_time_river_provider.dart'
    show
        // Raw WRD layer
        wrdStationsProvider,
        // Converted RiverStation layers
        wrdRiverStationsProvider,
        realTimeRiverProvider,
        // Derived convenience providers
        wrdIsLoadingProvider,
        wrdErrorProvider;

export 'map_command_provider.dart'
    show
        // Merged WRD + CWC station list (the true parent)
        mapStationsProvider,
        // District heatmap risk
        biharDistrictRiskProvider,
        // Sync timestamps
        mapSyncMetaProvider,
        SyncMeta;

// ── Convenience re-export of the WrdStation model ────────────────────────────
export '../services/wrd_bihar_service.dart' show WrdStation;

// ── Convenience re-export of the RiverStation model ─────────────────────────
export '../models/river_station.dart' show RiverStation, DangerClass;
