// lib/widgets/map/station_coord_seed.dart
// Static coordinate lookup for all known Bihar + national stations.
// coordFor() returns null when a station has no known coordinates;
// callers must guard against null before rendering a Marker.
import 'package:latlong2/latlong.dart';
import '../../models/river_station.dart';

const Map<String, LatLng> kStationCoords = {
  // ── Bihar districts ───────────────────────────────────────────────────
  'patna': LatLng(25.5941, 85.1376),
  'gaya': LatLng(24.7955, 85.0002),
  'bhagalpur': LatLng(25.2425, 86.9842),
  'muzaffarpur':
      LatLng(26.1209, 85.3647), // also matches 'muzzafarpur' via substring
  'darbhanga': LatLng(26.1542, 85.8918),
  'araria': LatLng(26.1475, 87.4733),
  'sitamarhi': LatLng(26.5921, 85.4879),
  'supaul': LatLng(26.1237, 86.6032),
  'vaishali': LatLng(25.6938, 85.2001),
  'saran': LatLng(25.9177, 84.7430),
  'east champaran': LatLng(26.6539, 84.9184),
  'west champaran': LatLng(27.0, 84.4),
  'gopalganj': LatLng(26.4699, 84.4341),
  'siwan': LatLng(26.2215, 84.3547),
  'begusarai': LatLng(25.4182, 86.1272),
  'samastipur': LatLng(25.8627, 85.7816),
  'madhubani': LatLng(26.3566, 86.0711),
  'khagaria': LatLng(25.5014, 86.4717),
  'katihar': LatLng(25.5398, 87.5677),
  'purnea': LatLng(25.7771, 87.4753),
  // ── CWC / WRD gauge sites ─────────────────────────────────────────────
  'ekmighat': LatLng(26.45, 86.12),
  'kamtaul': LatLng(26.30, 85.80),
  'sonbarsa': LatLng(27.10, 85.50),
  'benibad': LatLng(25.90, 85.50),
  'dheng bridge': LatLng(25.75, 85.30),
  'dhengbridge': LatLng(25.75, 85.30),
  'hayaghat': LatLng(25.70, 85.70),
  'rosera': LatLng(25.90, 85.90),
  'hajipur': LatLng(25.6853, 85.2093),
  'dumariaghat': LatLng(27.00, 84.15),
  'chatia': LatLng(26.60, 84.80),
  'rewaghat': LatLng(26.00, 84.50),
  'dighaghat': LatLng(25.60, 85.10),
  'gandhighat': LatLng(25.58, 85.13),
  'hathidah': LatLng(25.38, 85.80),
  'kahalgaon': LatLng(25.24, 87.25),
  'munger': LatLng(25.375, 86.474),
  'buxar': LatLng(25.565, 83.981),
  'birpur': LatLng(26.51, 87.00),
  'baltara': LatLng(25.40, 86.60),
  'basua': LatLng(25.75, 87.00),
  'kursela': LatLng(25.47, 87.27),
  'jhanjharpur': LatLng(26.26, 86.28),
  'jainagar': LatLng(26.60, 86.25),
  'dhengraghat': LatLng(25.60, 87.80),
  'taibpur': LatLng(26.00, 87.20),
  'sripalpur': LatLng(25.18, 85.33),
  'darauli': LatLng(26.05, 84.48),
  'gangpur siswan': LatLng(26.35, 84.40),
  'gangpur': LatLng(26.35, 84.40),
  'sikandarpur': LatLng(26.17, 85.52),
  // ── Additional WRD sites ──────────────────────────────────────────────
  'donar': LatLng(26.55, 85.25),
  'naugachia': LatLng(25.39, 87.10),
  'dhamara ghat': LatLng(25.93, 86.43),
  'dhamara': LatLng(25.93, 86.43),
  'ghonghepur': LatLng(26.25, 85.58),
  'sheohar': LatLng(26.52, 85.30),
  'pandaul': LatLng(26.16, 86.00),
  'lalbakeya': LatLng(26.50, 85.45),
  'bagmati': LatLng(25.80, 85.50),
  'runnisaidpur': LatLng(26.55, 85.90),
  'pupri': LatLng(26.47, 85.70),
  'gaighat': LatLng(26.08, 85.72),
  'tikulia': LatLng(26.30, 86.45),
  'phulparas': LatLng(26.43, 86.49),
  'nirmali': LatLng(26.31, 86.58),
  'bhim nagar': LatLng(26.57, 87.08),
  'bhimnagar': LatLng(26.57, 87.08),
  'katiya': LatLng(26.38, 87.11),
  'balmikinagar': LatLng(27.16, 84.62),
  'balmiki nagar': LatLng(27.16, 84.62),
  'turkaulia': LatLng(26.60, 84.75),
  'bhitaha': LatLng(27.05, 84.35),
  'sikta': LatLng(27.00, 84.55),
  'bagaha': LatLng(27.11, 84.08),
  'lauriya': LatLng(27.07, 84.39),
  'motihari': LatLng(26.65, 84.92),
  'areraj': LatLng(26.86, 84.89),
  // ── National sites ────────────────────────────────────────────────────
  'prayagraj': LatLng(25.4358, 81.8463),
  'varanasi': LatLng(25.3176, 82.9739),
  'lucknow': LatLng(26.8467, 80.9462),
  'guwahati': LatLng(26.1445, 91.7362),
  'dibrugarh': LatLng(27.4728, 94.9120),
  'kolkata': LatLng(22.5726, 88.3639),
  'bhubaneswar': LatLng(20.2961, 85.8189),
  'delhi': LatLng(28.6139, 77.2090),
  'srinagar': LatLng(34.0837, 74.7973),
};

/// Returns the best-guess [LatLng] for [s], or null if unknown.
/// Tries city and station name against all keys with partial matching.
LatLng? coordFor(RiverStation s) {
  String norm(String v) => v
      .toLowerCase()
      .replaceAll(RegExp(r'\s*\(.*?\)'), '')
      .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  final cityKey = norm(s.city);
  final stationKey = norm(s.station);

  // 1. Exact match
  for (final entry in kStationCoords.entries) {
    final k = norm(entry.key);
    if (cityKey == k || stationKey == k) return entry.value;
  }

  // 2. Substring / prefix match
  for (final entry in kStationCoords.entries) {
    final k = norm(entry.key);
    if (cityKey.contains(k) ||
        k.contains(cityKey) ||
        stationKey.contains(k) ||
        k.contains(stationKey)) {
      return entry.value;
    }
  }

  // 3. Embedded lat/lon fallback
  if (s.lat != null && s.lon != null) return LatLng(s.lat!, s.lon!);

  return null;
}
