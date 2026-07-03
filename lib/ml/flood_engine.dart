// OpsFlood ML Engine — Dart port of backend/app.py + state_severity_matrix.py
//
// Mirrors:
//   complex_predict_flood()       — ensemble blend
//   fallback_prediction()         — heuristic path
//   severity_from_entry()         — dual-axis scoring
//   danger_level_override_guard() — Option-A CWC guard
//   risk_score formula            — identical weight map
//   STATE_SEVERITY_MATRIX         — Full India (all 36 states/UTs)
//
// FIXES (v1.3 — 12 Jun 2026):
//   1. PLAINS rainfall thresholds raised  150/300/450 → 200/350/500 (CWC Ganga 2025).
//   2. HIMALAYAN thresholds raised        150/300/500 → 200/350/550.
//   3. COASTAL thresholds LOWERED         200/400/600 → 150/300/500 (IMD coastal norms).
//   4. ARID thresholds lowered            100/200/350 →  80/160/280 (Barmer 2024).
//   5. Bihar state entry recalibrated to backend dashboard + CWC Bihar 2026.
//   6. Assam / Odisha / Gujarat / UP state entries updated post-2024 bulletins.
//   7. Ensemble weights: peakScore 0.52→0.55, rainScore 0.38→0.35.
//   8. ML/Rule blend: mlW 0.75→0.70, ruleW 0.25→0.30 (rule engine stronger in deficit year).
//
// FIXES (v1.2 — carried forward):
//   1. Delhi MSL-elevation flag (usesAbsoluteElevation = true).
//   2. Unknown-state fallback returns PLAINS generic instead of Maharashtra.
//   3. Rule engine probability distribution is right-skewed.
//   4. Duration, timeToPeak, recessionTime contribute to combinedScore.
//   5. Full India matrix restored (Bihar-only scope reverted for test compat).

class FloodInput {
  final double peakFloodLevelM;
  final double eventDurationDays;
  final double timeToPeakDays;
  final double recessionTimeDay;
  final double t1d, t2d, t3d, t4d, t5d, t6d, t7d;
  final String state;
  final String? station;

  const FloodInput({
    required this.peakFloodLevelM,
    required this.eventDurationDays,
    required this.timeToPeakDays,
    required this.recessionTimeDay,
    required this.t1d,
    required this.t2d,
    required this.t3d,
    required this.t4d,
    required this.t5d,
    required this.t6d,
    required this.t7d,
    required this.state,
    this.station,
  });

  List<double> toFeatureVector() => [
        peakFloodLevelM,
        eventDurationDays,
        timeToPeakDays,
        recessionTimeDay,
        t1d,
        t2d,
        t3d,
        t4d,
        t5d,
        t6d,
        t7d,
      ];

  double get rainfall7d => t1d + t2d + t3d + t4d + t5d + t6d + t7d;
}

class FloodResult {
  final String severity;
  final double confidencePercent;
  final Map<String, double> probabilities;
  final int riskScore;
  final double proximityToDangerM;
  final String algorithm;
  final String alert;
  final String monitoringLevel;
  final String monitoringAction;
  final bool usedApi;
  final bool isOfflineEstimate;
  final Map<String, double> ruleProbs;
  final Map<String, double> mlProbs;
  final String thresholdSeverity;

  const FloodResult({
    required this.severity,
    required this.confidencePercent,
    required this.probabilities,
    required this.riskScore,
    required this.proximityToDangerM,
    required this.algorithm,
    required this.alert,
    required this.monitoringLevel,
    required this.monitoringAction,
    required this.usedApi,
    required this.isOfflineEstimate,
    required this.ruleProbs,
    required this.mlProbs,
    required this.thresholdSeverity,
  });
}

// ───────────────────────────────────────────────────────────────────────────────
const _severityOrder = {'LOW': 0, 'MODERATE': 1, 'SEVERE': 2, 'CRITICAL': 3};

const Map<int, String> classLabelMap = {
  0: 'LOW',
  1: 'MODERATE',
  2: 'SEVERE',
  3: 'CRITICAL',
};

const Map<String, double> riskWeights = {
  'LOW': 16,
  'MODERATE': 46,
  'SEVERE': 78,
  'CRITICAL': 96,
};

// ───────────────────────────────────────────────────────────────────────────────
// REGION RAINFALL THRESHOLDS  (mm / 7-day)
// v1.3: PLAINS +50/+50/+50 | HIMALAYAN +50/+50/+50 | COASTAL -50/-100/-100 | ARID -20/-40/-70
// ───────────────────────────────────────────────────────────────────────────────
const Map<String, Map<String, double>> regionRainfallThresholds = {
  'PLAINS': {'moderate': 200.0, 'severe': 350.0, 'critical': 500.0},
  'COASTAL': {'moderate': 150.0, 'severe': 300.0, 'critical': 500.0},
  'HIMALAYAN': {'moderate': 200.0, 'severe': 350.0, 'critical': 550.0},
  'NORTHEAST': {'moderate': 200.0, 'severe': 400.0, 'critical': 600.0},
  'ARID': {'moderate': 80.0, 'severe': 160.0, 'critical': 280.0},
  'ISLAND': {'moderate': 200.0, 'severe': 400.0, 'critical': 600.0},
  'URBAN_UT': {'moderate': 100.0, 'severe': 200.0, 'critical': 350.0},
};

Map<String, double> getRegionRainfallThresholds(String region) =>
    regionRainfallThresholds[region.toUpperCase()] ??
    regionRainfallThresholds['PLAINS']!;

// ───────────────────────────────────────────────────────────────────────────────
class StateEntry {
  final String region;
  final Map<String, double> peakLevelM;
  final Map<String, double> rainfall7dMm;
  final double dangerLevelM;
  final double warningLevelM;
  final double hflM;
  final List<String> primaryRivers;
  final List<String> vulnerableDistricts;
  final bool usesAbsoluteElevation;

  const StateEntry({
    required this.region,
    required this.peakLevelM,
    required this.rainfall7dMm,
    required this.dangerLevelM,
    required this.warningLevelM,
    required this.hflM,
    required this.primaryRivers,
    required this.vulnerableDistricts,
    this.usesAbsoluteElevation = false,
  });
}

StateEntry _entry({
  required String region,
  required Map<String, double> peak,
  required double danger,
  required double warning,
  required double hfl,
  List<String> rivers = const [],
  List<String> districts = const [],
  bool absoluteElevation = false,
}) {
  return StateEntry(
    region: region,
    peakLevelM: peak,
    rainfall7dMm: getRegionRainfallThresholds(region),
    dangerLevelM: danger,
    warningLevelM: warning,
    hflM: hfl,
    primaryRivers: rivers,
    vulnerableDistricts: districts,
    usesAbsoluteElevation: absoluteElevation,
  );
}

final StateEntry _unknownStateFallback = _entry(
  region: 'PLAINS',
  peak: {'moderate': 8.5, 'severe': 11.0, 'critical': 13.0},
  danger: 11.0,
  warning: 9.0,
  hfl: 13.5,
);

// ───────────────────────────────────────────────────────────────────────────────
// STATE SEVERITY MATRIX — Full India (28 states + 8 UTs = 36)
// v1.3: Bihar, Assam, Odisha, Gujarat, UP entries updated.
// ───────────────────────────────────────────────────────────────────────────────
final Map<String, StateEntry> stateSeverityMatrix = {
  // ── 28 STATES ──
  'andhra pradesh': _entry(
    region: 'COASTAL',
    peak: {'moderate': 10.0, 'severe': 13.0, 'critical': 16.0},
    danger: 13.0,
    warning: 10.5,
    hfl: 17.0,
    rivers: ['Krishna', 'Godavari'],
    districts: ['Guntur', 'East Godavari', 'Krishna'],
  ),
  'arunachal pradesh': _entry(
    region: 'HIMALAYAN',
    peak: {'moderate': 7.0, 'severe': 10.0, 'critical': 13.0},
    danger: 10.0,
    warning: 7.5,
    hfl: 14.0,
    rivers: ['Siang', 'Lohit', 'Subansiri'],
    districts: ['East Siang', 'Lohit', 'Dibang Valley'],
  ),
  // v1.3: danger 11.5 → 12.0 (Brahmaputra Dibrugarh DL recalibrated post-2024)
  'assam': _entry(
    region: 'NORTHEAST',
    peak: {'moderate': 8.0, 'severe': 11.0, 'critical': 14.0},
    danger: 12.0,
    warning: 8.5,
    hfl: 15.0,
    rivers: ['Brahmaputra', 'Barak', 'Kopili'],
    districts: ['Dhubri', 'Barpeta', 'Morigaon', 'Goalpara'],
  ),
  // v1.3: peak 9.0/11.5/13.5 → 11.0/12.0/13.2 | danger 11.5→12.0 | warning 9.2→11.0 | hfl 14.0→13.5
  'bihar': _entry(
    region: 'PLAINS',
    peak: {'moderate': 11.0, 'severe': 12.0, 'critical': 13.2},
    danger: 12.0,
    warning: 11.0,
    hfl: 13.5,
    rivers: ['Gandak', 'Kosi', 'Bagmati', 'Kamla', 'Mahananda'],
    districts: ['Darbhanga', 'Sitamarhi', 'Muzaffarpur', 'Supaul', 'Madhubani'],
  ),
  'chhattisgarh': _entry(
    region: 'PLAINS',
    peak: {'moderate': 8.0, 'severe': 10.5, 'critical': 13.0},
    danger: 10.5,
    warning: 8.0,
    hfl: 14.0,
    rivers: ['Mahanadi', 'Sheonath', 'Indravati'],
    districts: ['Raipur', 'Rajnandgaon', 'Bastar'],
  ),
  'goa': _entry(
    region: 'COASTAL',
    peak: {'moderate': 6.0, 'severe': 9.0, 'critical': 12.0},
    danger: 9.0,
    warning: 6.5,
    hfl: 13.0,
    rivers: ['Mandovi', 'Zuari'],
    districts: ['North Goa', 'South Goa'],
  ),
  // v1.3: danger 11.5 → 12.0 (Tapi Surat 2024 revised)
  'gujarat': _entry(
    region: 'COASTAL',
    peak: {'moderate': 8.0, 'severe': 11.0, 'critical': 14.0},
    danger: 12.0,
    warning: 8.5,
    hfl: 15.0,
    rivers: ['Sabarmati', 'Tapi', 'Narmada'],
    districts: ['Vadodara', 'Bharuch', 'Surat', 'Anand'],
  ),
  'haryana': _entry(
    region: 'PLAINS',
    peak: {'moderate': 7.0, 'severe': 9.5, 'critical': 12.0},
    danger: 9.5,
    warning: 7.0,
    hfl: 13.0,
    rivers: ['Ghaggar', 'Yamuna', 'Markanda'],
    districts: ['Ambala', 'Kurukshetra', 'Panipat'],
  ),
  'himachal pradesh': _entry(
    region: 'HIMALAYAN',
    peak: {'moderate': 6.0, 'severe': 9.0, 'critical': 12.0},
    danger: 9.0,
    warning: 6.5,
    hfl: 13.0,
    rivers: ['Beas', 'Ravi', 'Chenab', 'Sutlej'],
    districts: ['Kullu', 'Mandi', 'Kangra', 'Solan'],
  ),
  'jharkhand': _entry(
    region: 'PLAINS',
    peak: {'moderate': 8.5, 'severe': 11.0, 'critical': 13.5},
    danger: 11.0,
    warning: 8.5,
    hfl: 14.5,
    rivers: ['Damodar', 'Subarnarekha', 'Koel'],
    districts: ['East Singhbhum', 'West Singhbhum', 'Ranchi'],
  ),
  'karnataka': _entry(
    region: 'COASTAL',
    peak: {'moderate': 9.0, 'severe': 12.0, 'critical': 15.0},
    danger: 12.0,
    warning: 9.5,
    hfl: 16.0,
    rivers: ['Cauvery', 'Krishna', 'Tungabhadra'],
    districts: ['Raichur', 'Yadgir', 'Bidar', 'Dharwad'],
  ),
  'kerala': _entry(
    region: 'COASTAL',
    peak: {'moderate': 7.0, 'severe': 10.0, 'critical': 13.0},
    danger: 10.5,
    warning: 7.5,
    hfl: 14.0,
    rivers: ['Periyar', 'Pamba', 'Chaliyar'],
    districts: ['Alappuzha', 'Ernakulam', 'Thrissur', 'Wayanad'],
  ),
  'madhya pradesh': _entry(
    region: 'PLAINS',
    peak: {'moderate': 8.5, 'severe': 11.5, 'critical': 14.0},
    danger: 11.5,
    warning: 9.0,
    hfl: 15.0,
    rivers: ['Narmada', 'Chambal', 'Betwa', 'Son'],
    districts: ['Jabalpur', 'Hoshangabad', 'Sehore'],
  ),
  'maharashtra': _entry(
    region: 'COASTAL',
    peak: {'moderate': 9.5, 'severe': 12.5, 'critical': 15.5},
    danger: 13.0,
    warning: 10.0,
    hfl: 16.5,
    rivers: ['Godavari', 'Krishna', 'Bhima', 'Tapi'],
    districts: ['Kolhapur', 'Sangli', 'Nashik', 'Pune'],
  ),
  'manipur': _entry(
    region: 'NORTHEAST',
    peak: {'moderate': 7.0, 'severe': 10.0, 'critical': 13.0},
    danger: 10.0,
    warning: 7.5,
    hfl: 14.0,
    rivers: ['Manipur River', 'Iril', 'Barak'],
    districts: ['Imphal West', 'Thoubal', 'Bishnupur'],
  ),
  'meghalaya': _entry(
    region: 'NORTHEAST',
    peak: {'moderate': 7.5, 'severe': 10.5, 'critical': 13.5},
    danger: 10.5,
    warning: 8.0,
    hfl: 14.5,
    rivers: ['Umiam', 'Kopili', 'Myntdu'],
    districts: ['East Khasi Hills', 'West Khasi Hills', 'Ri Bhoi'],
  ),
  'mizoram': _entry(
    region: 'HIMALAYAN',
    peak: {'moderate': 6.5, 'severe': 9.5, 'critical': 12.5},
    danger: 9.5,
    warning: 7.0,
    hfl: 13.5,
    rivers: ['Tlawng', 'Tuirial', 'Kolodyne'],
    districts: ['Aizawl', 'Lunglei', 'Champhai'],
    absoluteElevation: true,
  ),
  'nagaland': _entry(
    region: 'NORTHEAST',
    peak: {'moderate': 7.0, 'severe': 10.0, 'critical': 13.0},
    danger: 10.0,
    warning: 7.5,
    hfl: 14.0,
    rivers: ['Doyang', 'Dhansiri', 'Tizu'],
    districts: ['Dimapur', 'Mokokchung', 'Wokha'],
  ),
  // v1.3: hfl 16.5 → 17.0 (Mahanadi Mundali 2024 new HFL)
  'odisha': _entry(
    region: 'COASTAL',
    peak: {'moderate': 9.5, 'severe': 12.5, 'critical': 15.5},
    danger: 13.0,
    warning: 10.0,
    hfl: 17.0,
    rivers: ['Mahanadi', 'Brahmani', 'Baitarani'],
    districts: ['Cuttack', 'Jagatsinghpur', 'Kendrapara', 'Bhadrak'],
  ),
  'punjab': _entry(
    region: 'PLAINS',
    peak: {'moderate': 7.5, 'severe': 10.0, 'critical': 12.5},
    danger: 10.0,
    warning: 7.5,
    hfl: 13.5,
    rivers: ['Sutlej', 'Beas', 'Ravi', 'Ghaggar'],
    districts: ['Roopnagar', 'Ludhiana', 'Patiala', 'Fatehgarh Sahib'],
  ),
  'rajasthan': _entry(
    region: 'ARID',
    peak: {'moderate': 5.0, 'severe': 7.5, 'critical': 10.0},
    danger: 7.5,
    warning: 5.0,
    hfl: 11.0,
    rivers: ['Luni', 'Chambal', 'Banas'],
    districts: ['Barmer', 'Jalore', 'Pali', 'Sirohi'],
  ),
  'sikkim': _entry(
    region: 'HIMALAYAN',
    peak: {'moderate': 5.0, 'severe': 8.0, 'critical': 11.0},
    danger: 8.0,
    warning: 5.5,
    hfl: 12.0,
    rivers: ['Teesta', 'Rangit'],
    districts: ['East Sikkim', 'South Sikkim'],
  ),
  'tamil nadu': _entry(
    region: 'COASTAL',
    peak: {'moderate': 8.0, 'severe': 11.0, 'critical': 14.0},
    danger: 11.5,
    warning: 8.5,
    hfl: 15.0,
    rivers: ['Cauvery', 'Palar', 'Vaigai', 'Tamirabarani'],
    districts: ['Chennai', 'Cuddalore', 'Nagapattinam', 'Thanjavur'],
  ),
  'telangana': _entry(
    region: 'PLAINS',
    peak: {'moderate': 9.0, 'severe': 12.0, 'critical': 15.0},
    danger: 12.0,
    warning: 9.5,
    hfl: 16.0,
    rivers: ['Krishna', 'Godavari', 'Musi'],
    districts: ['Khammam', 'Nalgonda', 'Bhadradri Kothagudem'],
  ),
  'tripura': _entry(
    region: 'NORTHEAST',
    peak: {'moderate': 7.0, 'severe': 10.0, 'critical': 13.0},
    danger: 10.0,
    warning: 7.5,
    hfl: 14.0,
    rivers: ['Gumti', 'Haora', 'Manu'],
    districts: ['West Tripura', 'Sepahijala', 'Khowai'],
  ),
  // v1.3: warning 9.5 → 10.0 (CWC Ganga Varanasi WL bulletin 2025)
  'uttar pradesh': _entry(
    region: 'PLAINS',
    peak: {'moderate': 9.5, 'severe': 12.5, 'critical': 15.0},
    danger: 12.5,
    warning: 10.0,
    hfl: 16.0,
    rivers: ['Ganga', 'Yamuna', 'Ghaghra', 'Rapti', 'Sharda'],
    districts: ['Varanasi', 'Allahabad', 'Ballia', 'Gorakhpur', 'Bahraich'],
  ),
  'uttarakhand': _entry(
    region: 'HIMALAYAN',
    peak: {'moderate': 6.5, 'severe': 9.5, 'critical': 12.5},
    danger: 9.5,
    warning: 7.0,
    hfl: 13.5,
    rivers: ['Ganga', 'Yamuna', 'Alaknanda', 'Bhagirathi'],
    districts: ['Haridwar', 'Dehradun', 'Pauri Garhwal', 'Tehri'],
  ),
  'west bengal': _entry(
    region: 'COASTAL',
    peak: {'moderate': 9.0, 'severe': 12.0, 'critical': 15.0},
    danger: 12.5,
    warning: 9.5,
    hfl: 16.0,
    rivers: ['Ganga', 'Damodar', 'Teesta', 'Mayurakshi'],
    districts: ['Murshidabad', 'Malda', 'Hooghly', 'Bardhaman'],
  ),

  // ── 8 UNION TERRITORIES ──
  'andaman and nicobar islands': _entry(
    region: 'ISLAND',
    peak: {'moderate': 6.0, 'severe': 9.0, 'critical': 12.0},
    danger: 9.0,
    warning: 6.5,
    hfl: 13.0,
    rivers: ['Kalpong'],
    districts: ['North & Middle Andaman', 'South Andaman'],
  ),
  'chandigarh': _entry(
    region: 'URBAN_UT',
    peak: {'moderate': 4.0, 'severe': 6.0, 'critical': 8.5},
    danger: 6.5,
    warning: 4.5,
    hfl: 9.5,
    rivers: ['Sukhna Choe', 'Patiala ki Rao'],
    districts: ['Chandigarh'],
  ),
  'dadra and nagar haveli': _entry(
    region: 'COASTAL',
    peak: {'moderate': 7.0, 'severe': 10.0, 'critical': 13.0},
    danger: 10.0,
    warning: 7.5,
    hfl: 14.0,
    rivers: ['Damanganga', 'Daman Ganga'],
    districts: ['Dadra and Nagar Haveli', 'Daman', 'Diu'],
  ),
  'delhi': _entry(
    region: 'URBAN_UT',
    peak: {'moderate': 204.5, 'severe': 205.5, 'critical': 206.5},
    danger: 205.33,
    warning: 204.5,
    hfl: 207.49,
    rivers: ['Yamuna'],
    districts: ['North Delhi', 'Central Delhi', 'East Delhi', 'South Delhi'],
    absoluteElevation: true,
  ),
  'jammu and kashmir': _entry(
    region: 'HIMALAYAN',
    peak: {'moderate': 6.0, 'severe': 9.0, 'critical': 12.0},
    danger: 9.5,
    warning: 6.5,
    hfl: 13.0,
    rivers: ['Jhelum', 'Chenab', 'Ravi', 'Tawi'],
    districts: ['Srinagar', 'Anantnag', 'Bandipora', 'Jammu'],
  ),
  'ladakh': _entry(
    region: 'HIMALAYAN',
    peak: {'moderate': 4.0, 'severe': 6.5, 'critical': 9.0},
    danger: 6.5,
    warning: 4.5,
    hfl: 10.0,
    rivers: ['Indus', 'Shyok', 'Zanskar'],
    districts: ['Leh', 'Kargil'],
  ),
  'lakshadweep': _entry(
    region: 'ISLAND',
    peak: {'moderate': 1.5, 'severe': 2.5, 'critical': 3.5},
    danger: 2.5,
    warning: 1.8,
    hfl: 4.0,
    rivers: [],
    districts: ['Kavaratti', 'Agatti', 'Minicoy'],
  ),
  'puducherry': _entry(
    region: 'COASTAL',
    peak: {'moderate': 5.0, 'severe': 8.0, 'critical': 11.0},
    danger: 8.0,
    warning: 5.5,
    hfl: 12.0,
    rivers: ['Gingee', 'Pennaiyar'],
    districts: ['Puducherry', 'Karaikal', 'Mahe', 'Yanam'],
  ),
};

StateEntry getStateEntry(String state) {
  final key = state.trim().toLowerCase();
  final normalized = <String, String>{
        'orissa': 'odisha',
        'nct of delhi': 'delhi',
        'new delhi': 'delhi',
        'j&k': 'jammu and kashmir',
        'j & k': 'jammu and kashmir',
        'uttaranchal': 'uttarakhand',
        'dnhdd': 'dadra and nagar haveli',
      }[key] ??
      key;
  return stateSeverityMatrix[normalized] ?? _unknownStateFallback;
}

// ───────────────────────────────────────────────────────────────────────────────
// OPTION-A GUARD
// ───────────────────────────────────────────────────────────────────────────────
String _dangerLevelGuard({
  required String severity,
  required double riverLevelM,
  required double rainfall7dMm,
  required StateEntry entry,
}) {
  final warnM = entry.warningLevelM;
  final dangerM = entry.dangerLevelM;
  final hflM = entry.hflM;

  if (warnM <= 0 || dangerM <= 0) return severity;

  final regionT = getRegionRainfallThresholds(entry.region);

  if (riverLevelM >= hflM) {
    return severity;
  } else if (riverLevelM >= dangerM) {
    if (severity == 'CRITICAL') return 'SEVERE';
    return severity;
  } else if (riverLevelM >= warnM) {
    return severity;
  } else {
    if (rainfall7dMm >= regionT['severe']!) return severity;
    if (severity == 'SEVERE' || severity == 'CRITICAL') return 'MODERATE';
    return severity;
  }
}

// ───────────────────────────────────────────────────────────────────────────────
// DUAL-AXIS SEVERITY
// ───────────────────────────────────────────────────────────────────────────────
String severityFromEntry({
  required double peakLevelM,
  required double rainfall7dMm,
  required StateEntry entry,
  double? riverLevelM,
}) {
  final p = entry.peakLevelM;
  final r = entry.rainfall7dMm;

  String depthSev;
  if (peakLevelM >= p['critical']!) {
    depthSev = 'CRITICAL';
  } else if (peakLevelM >= p['severe']!) {
    depthSev = 'SEVERE';
  } else if (peakLevelM >= p['moderate']!) {
    depthSev = 'MODERATE';
  } else {
    depthSev = 'LOW';
  }

  String rainSev;
  if (rainfall7dMm >= r['critical']!) {
    rainSev = 'CRITICAL';
  } else if (rainfall7dMm >= r['severe']!) {
    rainSev = 'SEVERE';
  } else if (rainfall7dMm >= r['moderate']!) {
    rainSev = 'MODERATE';
  } else {
    rainSev = 'LOW';
  }

  final rawSev = (_severityOrder[depthSev]! >= _severityOrder[rainSev]!)
      ? depthSev
      : rainSev;

  if (riverLevelM != null) {
    return _dangerLevelGuard(
      severity: rawSev,
      riverLevelM: riverLevelM,
      rainfall7dMm: rainfall7dMm,
      entry: entry,
    );
  }
  return rawSev;
}

// ───────────────────────────────────────────────────────────────────────────────
// RULE ENGINE — right-skewed distribution
// ───────────────────────────────────────────────────────────────────────────────
Map<String, double> _ruleEngineProbMap(String thresholdSev) {
  final rank = _severityOrder[thresholdSev]!;
  final all = ['LOW', 'MODERATE', 'SEVERE', 'CRITICAL'];
  final probs = <String, double>{};
  double total = 0;
  for (final label in all) {
    final diff = _severityOrder[label]! - rank;
    double w;
    if (diff == 0) {
      w = 0.60;
    } else if (diff == 1) {
      w = 0.25;
    } else if (diff == -1) {
      w = 0.10;
    } else if (diff > 1) {
      w = 0.04;
    } else {
      w = 0.01;
    }
    probs[label] = w;
    total += w;
  }
  return {for (final e in probs.entries) e.key: e.value / total};
}

// ───────────────────────────────────────────────────────────────────────────────
// HEURISTIC ON-DEVICE ENGINE
// v1.3: peakScore weight 0.52→0.55 | rainScore 0.38→0.35 | mlW 0.75→0.70 | ruleW 0.25→0.30
// ───────────────────────────────────────────────────────────────────────────────
FloodResult runOnDeviceEngine(FloodInput input) {
  final entry = getStateEntry(input.state);
  final rainfall7d = input.rainfall7d;

  final thresholdSev = severityFromEntry(
    peakLevelM: input.peakFloodLevelM,
    rainfall7dMm: rainfall7d,
    entry: entry,
  );

  final critP = entry.peakLevelM['critical']!;
  final sevP = entry.peakLevelM['severe']!;
  final modP = entry.peakLevelM['moderate']!;

  double peakScore;
  if (input.peakFloodLevelM >= critP) {
    peakScore = 1.0;
  } else if (input.peakFloodLevelM >= sevP) {
    peakScore = 0.67 + 0.33 * ((input.peakFloodLevelM - sevP) / (critP - sevP));
  } else if (input.peakFloodLevelM >= modP) {
    peakScore = 0.33 + 0.34 * ((input.peakFloodLevelM - modP) / (sevP - modP));
  } else {
    peakScore = 0.33 * (input.peakFloodLevelM / modP).clamp(0, 1);
  }

  final rainT = getRegionRainfallThresholds(entry.region);
  double rainScore;
  if (rainfall7d >= rainT['critical']!) {
    rainScore = 1.0;
  } else if (rainfall7d >= rainT['severe']!) {
    rainScore = 0.67 +
        0.33 *
            ((rainfall7d - rainT['severe']!) /
                (rainT['critical']! - rainT['severe']!));
  } else if (rainfall7d >= rainT['moderate']!) {
    rainScore = 0.33 +
        0.34 *
            ((rainfall7d - rainT['moderate']!) /
                (rainT['severe']! - rainT['moderate']!));
  } else {
    rainScore = 0.33 * (rainfall7d / rainT['moderate']!).clamp(0, 1);
  }

  final durationScore = (input.eventDurationDays / 14.0).clamp(0.0, 1.0);
  final riseScore = input.timeToPeakDays > 0
      ? (1.0 - (input.timeToPeakDays / 7.0).clamp(0.0, 1.0))
      : 0.0;
  final recessionScore = (input.recessionTimeDay / 10.0).clamp(0.0, 1.0);
  final temporalScore =
      (durationScore * 0.4 + riseScore * 0.35 + recessionScore * 0.25)
          .clamp(0.0, 1.0);

  // v1.3: 0.52/0.38/0.10 → 0.55/0.35/0.10
  final combinedScore =
      (peakScore * 0.55 + rainScore * 0.35 + temporalScore * 0.10)
          .clamp(0.0, 1.0);

  final mlRank = (combinedScore * 3.0).clamp(0.0, 3.0);
  final mlProbs = <String, double>{};
  double mlTotal = 0;
  for (final label in ['LOW', 'MODERATE', 'SEVERE', 'CRITICAL']) {
    final dist = (_severityOrder[label]! - mlRank).abs();
    final w = (dist < 0.5)
        ? 0.65
        : (dist < 1.5)
            ? 0.25
            : (dist < 2.5)
                ? 0.08
                : 0.02;
    mlProbs[label] = w;
    mlTotal += w;
  }
  final normMlProbs = {
    for (final e in mlProbs.entries) e.key: e.value / mlTotal
  };

  final ruleProbs = _ruleEngineProbMap(thresholdSev);

  // v1.3: mlW 0.75→0.70, ruleW 0.25→0.30 (rule engine stronger in 2025 deficit year)
  const mlW = 0.70;
  const ruleW = 0.30;
  final finalProbs = <String, double>{};
  for (final label in ['LOW', 'MODERATE', 'SEVERE', 'CRITICAL']) {
    finalProbs[label] =
        (normMlProbs[label]! * mlW) + (ruleProbs[label]! * ruleW);
  }

  final fTotal = finalProbs.values.fold(0.0, (a, b) => a + b);
  final normFinal = {
    for (final e in finalProbs.entries) e.key: e.value / fTotal
  };

  String severity =
      normFinal.entries.reduce((a, b) => a.value > b.value ? a : b).key;

  final warnM = entry.warningLevelM;
  if (warnM > 0 &&
      input.peakFloodLevelM < warnM &&
      (severity == 'SEVERE' || severity == 'CRITICAL')) {
    normFinal['SEVERE'] = 0.0;
    normFinal['CRITICAL'] = 0.0;
    double s2 = normFinal.values.fold(0.0, (a, b) => a + b);
    for (final k in normFinal.keys) {
      normFinal[k] = s2 > 0 ? normFinal[k]! / s2 : 0;
    }
    severity =
        normFinal.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  }

  final confidence = (normFinal[severity]! * 100).roundToDouble();
  double rs = 0;
  for (final label in ['LOW', 'MODERATE', 'SEVERE', 'CRITICAL']) {
    rs += normFinal[label]! * riskWeights[label]!;
  }
  final riskScore = rs.round().clamp(0, 100);
  final proximityToDanger = entry.dangerLevelM - input.peakFloodLevelM;

  final String alert;
  if (severity == 'CRITICAL' || severity == 'SEVERE') {
    alert = '🚨';
  } else if (severity == 'MODERATE') {
    alert = '⚠️';
  } else {
    alert = '🟢';
  }

  final monitoring = _monitoringAdvice(severity, riskScore);

  return FloodResult(
    severity: severity,
    confidencePercent: confidence,
    probabilities: {for (final e in normFinal.entries) e.key: e.value * 100},
    riskScore: riskScore,
    proximityToDangerM: proximityToDanger,
    algorithm: 'On-Device Heuristic Ensemble v1.3 (OpsFlood port)',
    alert: alert,
    monitoringLevel: monitoring['level']!,
    monitoringAction: monitoring['action']!,
    usedApi: false,
    isOfflineEstimate: true,
    ruleProbs: {for (final e in ruleProbs.entries) e.key: e.value * 100},
    mlProbs: {for (final e in normMlProbs.entries) e.key: e.value * 100},
    thresholdSeverity: thresholdSev,
  );
}

Map<String, String> _monitoringAdvice(String severity, int riskScore) {
  switch (severity) {
    case 'CRITICAL':
      return {
        'level': 'CRITICAL',
        'action':
            'Immediate evacuation. Contact NDRF. Activate emergency protocol.',
      };
    case 'SEVERE':
      return {
        'level': 'HIGH ALERT',
        'action':
            'Alert district administration. Prepare evacuation routes. 4-hour monitoring.',
      };
    case 'MODERATE':
      return {
        'level': 'WATCH',
        'action':
            'Monitor river levels every 6 hours. Pre-position rescue teams.',
      };
    default:
      return {
        'level': 'NORMAL',
        'action': 'Standard monitoring. Review 7-day forecast daily.',
      };
  }
}
