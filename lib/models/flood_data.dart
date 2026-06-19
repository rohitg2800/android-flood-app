class FloodData {
  final String  stationId;
  final String  stationName;
  final String? city;
  final String? district;
  final String? state;
  final String? river;
  final String? riverName;
  final double  currentLevel;
  final double  warningLevel;
  final double  dangerLevel;
  final double? discharge;
  final double? flowRate;
  final double? imdRainfallMm;
  final double? latitude;
  final double? longitude;
  final DateTime  observedAt;
  final DateTime? lastUpdated;
  final String?   trend;

  // ML / severity fields (v4.2)
  final String? predictedSeverity;
  final int?    riskScore;
  final double? confidencePercent;
  final bool?   willBreachDanger;
  final double? peakLevel72h;

  FloodData({
    required this.stationId,
    required this.stationName,
    this.city,
    this.district,
    this.state,
    this.river,
    this.riverName,
    required this.currentLevel,
    required this.warningLevel,
    required this.dangerLevel,
    this.discharge,
    this.flowRate,
    this.imdRainfallMm,
    this.latitude,
    this.longitude,
    DateTime? observedAt,
    this.lastUpdated,
    this.trend,
    this.predictedSeverity,
    this.riskScore,
    this.confidencePercent,
    this.willBreachDanger,
    this.peakLevel72h,
  }) : observedAt = observedAt ?? lastUpdated ?? DateTime(1970);


  // ── Convenience getters ────────────────────────────────────────────────────
  String get station => stationName;

  String get riskLevel {
    if (currentLevel >= dangerLevel)              return 'CRITICAL';
    if (currentLevel >= warningLevel)             return 'SEVERE';
    if ((dangerLevel - currentLevel) <= 0.5)      return 'MODERATE';
    return 'NORMAL';
  }

  bool get isAtWarning => currentLevel >= warningLevel;
  bool get isAtDanger  => currentLevel >= dangerLevel;

  // ── Helpers ────────────────────────────────────────────────────────────────
  static double  _d(dynamic v)    => v == null ? 0.0 : (v as num).toDouble();
  static double? _dOpt(dynamic v) => v == null ? null : (v as num).toDouble();

  // ── fromJson ───────────────────────────────────────────────────────────────
  factory FloodData.fromJson(Map<String, dynamic> json) => FloodData(
    stationId:    (json['station_id']   ?? json['id']   ?? json['station'] ?? '') as String,
    stationName:  (json['station_name'] ?? json['name'] ?? json['station'] ?? '') as String,
    city:         json['city']      as String?,
    district:     json['district']  as String?,
    state:        json['state']     as String?,
    river:        json['river']     as String?,
    riverName:    json['riverName'] as String?,
    currentLevel: _d(json['current_level'] ?? json['level'] ?? json['currentLevel']),
    warningLevel: _d(json['warning_level'] ?? json['warning'] ?? json['warningLevel']),
    dangerLevel:  _d(json['danger_level']  ?? json['danger']  ?? json['dangerLevel']),
    discharge:    _dOpt(json['discharge']),
    flowRate:     _dOpt(json['flowRate'] ?? json['flow_rate']),
    imdRainfallMm: _dOpt(json['imdRainfallMm'] ?? json['rainfall24h']),
    latitude:     _dOpt(json['latitude']),
    longitude:    _dOpt(json['longitude']),
    observedAt:   json['observed_at'] != null
                    ? DateTime.parse(json['observed_at'] as String)
                    : json['lastUpdated'] != null
                        ? DateTime.parse(json['lastUpdated'] as String)
                        : null,
    lastUpdated:  json['lastUpdated'] != null
                    ? DateTime.parse(json['lastUpdated'] as String)
                    : null,
    trend:              json['trend']               as String?,
    predictedSeverity:  json['predictedSeverity']   as String?,
    riskScore:          (json['riskScore'] as num?)?.toInt(),
    confidencePercent:  _dOpt(json['confidencePercent']),
    willBreachDanger:   json['willBreachDanger']    as bool?,
    peakLevel72h:       _dOpt(json['peakLevel72h']),
  );

  // ── toJson ─────────────────────────────────────────────────────────────────
  Map<String, dynamic> toJson() => {
    'station_id':    stationId,
    'station':       stationName,
    'station_name':  stationName,
    if (city      != null) 'city':      city,
    if (district  != null) 'district':  district,
    if (state     != null) 'state':     state,
    if (river     != null) 'river':     river,
    if (riverName != null) 'riverName': riverName,
    'current_level': currentLevel,
    'warning_level': warningLevel,
    'danger_level':  dangerLevel,
    if (discharge      != null) 'discharge':      discharge,
    if (flowRate       != null) 'flowRate':       flowRate,
    if (imdRainfallMm  != null) 'imdRainfallMm':  imdRainfallMm,
    if (latitude       != null) 'latitude':       latitude,
    if (longitude      != null) 'longitude':      longitude,
    'observed_at': observedAt.toIso8601String(),
    if (lastUpdated    != null) 'lastUpdated':    lastUpdated!.toIso8601String(),
    if (trend          != null) 'trend':          trend,
    if (predictedSeverity != null) 'predictedSeverity': predictedSeverity,
    if (riskScore      != null) 'riskScore':      riskScore,
    if (confidencePercent != null) 'confidencePercent': confidencePercent,
    if (willBreachDanger  != null) 'willBreachDanger':  willBreachDanger,
    if (peakLevel72h   != null) 'peakLevel72h':   peakLevel72h,
  };
}
