// lib/providers/merged_stations_provider.dart
// Re-export shim — mergedStationsProvider lives in real_time_river_provider.dart.
library;

export 'real_time_river_provider.dart'
    show
        mergedStationsProvider,
        wrdStationsProvider,
        realTimeRiverProvider,
        wrdRiverStationsProvider,
        wrdErrorProvider,
        wrdIsLoadingProvider,
        mergedCriticalCountProvider;
