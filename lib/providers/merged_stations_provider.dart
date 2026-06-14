// lib/providers/merged_stations_provider.dart
// Re-export shim — mergedStationsProvider is defined in
// real_time_river_provider.dart.  Other files (district_heatmap_provider,
// map_live_index_provider) import this path, so we forward it here.
library;

export 'real_time_river_provider.dart'
    show
        mergedStationsProvider,
        wrdStationsProvider,
        realTimeRiverProvider,
        wrdRiverStationsProvider;
