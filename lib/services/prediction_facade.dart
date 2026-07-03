// lib/services/prediction_facade.dart
// DEPRECATED — this file is intentionally empty.
//
// All prediction logic has been consolidated into:
//   lib/services/predict.dart        — PredictionService (hybrid ML facade)
//   lib/services/prediction_service.dart — PredictionServiceImpl (engine)
//
// This file is kept as a stub to avoid breaking any stale imports.
// Remove it once all import references have been updated.
library;

export 'predict.dart'
    show FloodPrediction, FloodPredictionInput, PredictionService;
export 'prediction_service.dart' show MonitoringProtocol, PredictionInput;
