// lib/providers/alerts_provider.dart  v3.0
// Re-exports alert symbols from data_fetch_provider + alert_engine.
// Removed the broken activeAlertsCountProvider that referenced missing
// dataFetchProvider / AlertEngine directly — use alertCountProvider instead.
library;

export 'data_fetch_provider.dart'
    show
        alertsProvider,
        criticalAlertsProvider,
        emergencyAlertsProvider,
        warningAlertsProvider,
        alertCountProvider,
        criticalAlertCountProvider,
        stationAlertsProvider,
        sourceStatusProvider,
        dataFetchProvider,
        dataFetchStationsProvider,
        lastFetchTimeProvider2,
        fetchSnapshotKpiProvider;

export '../services/alert_engine.dart'
    show
        FloodAlert,
        AlertSeverity,
        AlertSeverityExt,
        AlertType,
        AlertTypeExt,
        AlertEngine;

export '../services/data_fetch_engine.dart'
    show
        DataFetchEngine,
        DataFetchSnapshot,
        StationReading,
        SourceStatus;
