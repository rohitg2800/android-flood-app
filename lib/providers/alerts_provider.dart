// lib/providers/alerts_provider.dart  v3.2
// Re-exports alert symbols from data_fetch_provider + alert_engine.
library;

export 'data_fetch_provider.dart'
    show
        alertsProvider,
        criticalAlertsProvider,
        emergencyAlertsProvider,
        warningAlertsProvider,
        alertCountProvider,
        stationAlertsProvider;

export 'stubs.dart' show sourceStatusProvider, dataFetchStationsProvider;

export '../services/alert_engine.dart'
    show
        FloodAlert,
        AlertSeverity,
        AlertSeverityExt,
        AlertType,
        AlertTypeExt,
        AlertEngine;

export '../services/data_fetch_engine.dart'
    show DataFetchEngine, DataFetchSnapshot, SourceStatus;

export '../models/station_reading.dart' show StationReading;
