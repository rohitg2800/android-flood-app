// Plain Dart model — no freezed / json_serializable
// Maps to: public.predictions

enum PredictionStatus { pending, processing, completed, failed }
enum FloodRisk { none, low, moderate, high, critical }

PredictionStatus predictionStatusFromString(String s) =>
    PredictionStatus.values.firstWhere((e) => e.name == s,
        orElse: () => PredictionStatus.pending);

FloodRisk floodRiskFromString(String s) =>
    FloodRisk.values.firstWhere((e) => e.name == s,
        orElse: () => FloodRisk.none);

class PredictionModel {
  final String id;
  final String? stationId;
  final String? zoneId;
  final double? predictedWaterLevel;
  final double? confidenceScore;
  final FloodRisk floodRisk;
  final PredictionStatus status;
  final DateTime predictionFor; // target datetime
  final String? modelVersion;
  final Map<String, dynamic>? featureImportance;
  final String? errorMessage;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PredictionModel({
    required this.id,
    this.stationId,
    this.zoneId,
    this.predictedWaterLevel,
    this.confidenceScore,
    required this.floodRisk,
    required this.status,
    required this.predictionFor,
    this.modelVersion,
    this.featureImportance,
    this.errorMessage,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PredictionModel.fromJson(Map<String, dynamic> json) => PredictionModel(
        id: json['id'] as String,
        stationId: json['station_id'] as String?,
        zoneId: json['zone_id'] as String?,
        predictedWaterLevel:
            (json['predicted_water_level'] as num?)?.toDouble(),
        confidenceScore: (json['confidence_score'] as num?)?.toDouble(),
        floodRisk: floodRiskFromString(json['flood_risk'] as String),
        status: predictionStatusFromString(json['status'] as String),
        predictionFor: DateTime.parse(json['prediction_for'] as String),
        modelVersion: json['model_version'] as String?,
        featureImportance:
            json['feature_importance'] as Map<String, dynamic>?,
        errorMessage: json['error_message'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'station_id': stationId,
        'zone_id': zoneId,
        'predicted_water_level': predictedWaterLevel,
        'confidence_score': confidenceScore,
        'flood_risk': floodRisk.name,
        'status': status.name,
        'prediction_for': predictionFor.toIso8601String(),
        'model_version': modelVersion,
        'feature_importance': featureImportance,
        'error_message': errorMessage,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  bool get isHighRisk =>
      floodRisk == FloodRisk.high || floodRisk == FloodRisk.critical;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is PredictionModel && other.id == id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'PredictionModel(id: $id, risk: ${floodRisk.name}, status: ${status.name})';
}
