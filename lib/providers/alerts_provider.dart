// lib/providers/alerts_provider.dart  v3.1
// Re-exports alert symbols from data_fetch_provider + alert_engine.
// criticalAlertCountProvider removed from show list — it is not exported
// by data_fetch_provider.dart (fixes undefined_shown_name warning).
library;

export 'data_fetch_provider.dart'
    show
        alertsProvider,
        criticalAlertsProvider,
        emergencyAlertsProvider,
        warningAlertsProvider,
        alertCountProvider,
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
