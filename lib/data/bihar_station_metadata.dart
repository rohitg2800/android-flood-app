// lib/data/bihar_station_metadata.dart
//
// Single source of truth for Bihar CWC gauging station metadata.
//
// v2.1 (17 Jun 2026):
//   FIX: 'kamtaul' key was ambiguous — three stations share the name:
//     Kamtaul (Adhwara), Kamtaul (Bagmati), Kamtaul (Kamla).
//     forSite('Kamtaul (Kamla)') stripped parens → 'kamtaul' → returned
//     Adhwara data (DL 50.00) for a Kamla station whose real DL is 44.00.
//     That is a 6.00 m error — station would never show DANGER/CRITICAL.
//   FIX: Added explicit keys 'kamtaul (kamla)' and 'kamtaul (bagmati)'
//     so all three variants resolve correctly. 'kamtaul' (bare) still
//     resolves to Adhwara (the most frequently scraped variant).
//   FIX: dhengraghat (bagmati) HFL corrected 38.20 → 47.30
//     (was a copy-paste from Mahananda Dhengraghat; Bagmati 2002 value is 47.30)
//
// v2.0 (17 Jun 2026): All WL/DL/HFL synced to bihar_rivers.dart v4.4.
library;

import 'package:latlong2/latlong.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Model
// ─────────────────────────────────────────────────────────────────────────────

class BiharStationMeta {
  final String river;
  final String site;
  final String district;
  final double lat;
  final double lng;
  final List<String> coversCities;
  final double? warningLevel;
  final double? dangerLevel;
  final double? hfl;

  const BiharStationMeta({
    required this.river,
    required this.site,
    required this.district,
    required this.lat,
    required this.lng,
    required this.coversCities,
    this.warningLevel,
    this.dangerLevel,
    this.hfl,
  });

  LatLng get latLng => LatLng(lat, lng);
}

// ─────────────────────────────────────────────────────────────────────────────
// Registry
// ─────────────────────────────────────────────────────────────────────────────

class BiharStationRegistry {
  BiharStationRegistry._();

  static BiharStationMeta? forSite(String site) =>
      _all[site.toLowerCase().trim()];

  static List<BiharStationMeta> get all => _all.values.toList();

  static Set<String> get districts =>
      _all.values.map((m) => m.district).toSet();

  static const _all = <String, BiharStationMeta>{
    // ═══════════════════════════════════════════════════════════════════════
    // ADHWARA GROUP
    // ═══════════════════════════════════════════════════════════════════════

    'ekmighat': BiharStationMeta(
      river: 'Khiroi',
      site: 'Ekmighat',
      district: 'Darbhanga',
      lat: 26.25,
      lng: 86.00,
      coversCities: [
        'Sitamarhi',
        'Runni Saidpur',
        'Pupri',
        'Riga',
        'Parihar',
        'Sursand'
      ],
      warningLevel: 45.00,
      dangerLevel: 46.94,
      hfl: 49.52,
    ),

    // 'kamtaul' bare key → Adhwara (most commonly scraped variant).
    // For the other two see explicit keys below.
    'kamtaul': BiharStationMeta(
      river: 'Adhwara',
      site: 'Kamtaul',
      district: 'Darbhanga',
      lat: 26.392,
      lng: 85.862,
      coversCities: [
        'Kamtaul',
        'Darbhanga',
        'Baheri',
        'Manigachhi',
        'Biraul',
        'Kusheshwar Asthan'
      ],
      warningLevel: 48.00,
      dangerLevel: 50.00,
      hfl: 53.05,
    ),

    // Explicit Adhwara variant (same data, extra lookup key)
    'kamtaul (adhwara)': BiharStationMeta(
      river: 'Adhwara',
      site: 'Kamtaul (Adhwara)',
      district: 'Darbhanga',
      lat: 26.392,
      lng: 85.862,
      coversCities: [
        'Kamtaul',
        'Darbhanga',
        'Baheri',
        'Manigachhi',
        'Biraul',
        'Kusheshwar Asthan'
      ],
      warningLevel: 48.00,
      dangerLevel: 50.00,
      hfl: 53.05,
    ),

    'sonbarsa': BiharStationMeta(
      river: 'Jhim',
      site: 'Sonbarsa',
      district: 'Sitamarhi',
      lat: 26.70,
      lng: 85.48,
      coversCities: [
        'Samastipur',
        'Sonbarsa',
        'Bibhutipur',
        'Patori',
        'Ujiarpur',
        'Morwa'
      ],
      warningLevel: 80.50,
      dangerLevel: 81.85,
      hfl: 83.20,
    ),

    // ═══════════════════════════════════════════════════════════════════════
    // BAGMATI
    // ═══════════════════════════════════════════════════════════════════════

    'benibad': BiharStationMeta(
      river: 'Bagmati',
      site: 'Benibad',
      district: 'Muzaffarpur',
      lat: 26.05,
      lng: 85.65,
      coversCities: [
        'Muzaffarpur',
        'Katra',
        'Minapur',
        'Motipur',
        'Sakra',
        'Gaighat'
      ],
      warningLevel: 47.68,
      dangerLevel: 48.68,
      hfl: 50.12,
    ),

    'dheng bridge': BiharStationMeta(
      river: 'Bagmati',
      site: 'Dheng Bridge',
      district: 'Sitamarhi',
      lat: 26.58,
      lng: 85.49,
      coversCities: [
        'Dheng',
        'Bajpatti',
        'Sheohar',
        'Piprahi',
        'Belsand',
        'Parsauni'
      ],
      warningLevel: 70.00,
      dangerLevel: 71.00,
      hfl: 73.47,
    ),

    'hayaghat': BiharStationMeta(
      river: 'Bagmati',
      site: 'Hayaghat',
      district: 'Darbhanga',
      lat: 26.02,
      lng: 85.95,
      coversCities: [
        'Hayaghat',
        'Darbhanga',
        'Jale',
        'Kiratpur',
        'Ghanshyampur',
        'Biraul'
      ],
      warningLevel: 44.50,
      dangerLevel: 45.72,
      hfl: 48.96,
    ),

    // FIX v2.1: explicit Bagmati key so forSite('Kamtaul (Bagmati)') resolves correctly.
    // HFL corrected: 53.01 (from kBiharGauges; was missing entry, fell through to Adhwara)
    'kamtaul (bagmati)': BiharStationMeta(
      river: 'Bagmati',
      site: 'Kamtaul (Bagmati)',
      district: 'Darbhanga',
      lat: 26.392,
      lng: 85.862,
      coversCities: [
        'Kamtaul',
        'Darbhanga',
        'Baheri',
        'Manigachhi',
        'Biraul',
        'Kusheshwar Asthan'
      ],
      warningLevel: 49.00,
      dangerLevel: 50.00,
      hfl: 53.01,
    ),

    // FIX v2.1: HFL corrected 38.20 → 47.30 (was copy-pasted from Mahananda Dhengraghat)
    'dhengraghat (bagmati)': BiharStationMeta(
      river: 'Bagmati',
      site: 'Dhengraghat (Bagmati)',
      district: 'Darbhanga',
      lat: 26.098,
      lng: 87.951,
      coversCities: ['Darbhanga', 'Hayaghat', 'Biraul', 'Manigachhi'],
      warningLevel: 34.65,
      dangerLevel: 35.65,
      hfl: 47.30,
    ),

    // ═══════════════════════════════════════════════════════════════════════
    // BURHI GANDAK
    // ═══════════════════════════════════════════════════════════════════════

    'khagaria': BiharStationMeta(
      river: 'Burhi Gandak',
      site: 'Khagaria',
      district: 'Khagaria',
      lat: 25.50,
      lng: 86.47,
      coversCities: [
        'Khagaria',
        'Mansi',
        'Alauli',
        'Chautham',
        'Parwalpur',
        'Gogri'
      ],
      warningLevel: 35.40,
      dangerLevel: 36.58,
      hfl: 39.22,
    ),

    'rosera': BiharStationMeta(
      river: 'Burhi Gandak',
      site: 'Rosera',
      district: 'Samastipur',
      lat: 25.86,
      lng: 85.98,
      coversCities: [
        'Rosera',
        'Dalsingh Sarai',
        'Bibhutipur',
        'Tajpur',
        'Pusa',
        'Sarairanjan'
      ],
      warningLevel: 41.50,
      dangerLevel: 42.63,
      hfl: 46.56,
    ),

    'samastipur': BiharStationMeta(
      river: 'Burhi Gandak',
      site: 'Samastipur',
      district: 'Samastipur',
      lat: 25.862,
      lng: 85.781,
      coversCities: [
        'Samastipur',
        'Mohiuddinagar',
        'Pusa',
        'Warisnagar',
        'Shivajinagar',
        'Kalyanpur'
      ],
      warningLevel: 44.80,
      dangerLevel: 46.00,
      hfl: 49.40,
    ),

    'sikandarpur (muzzafarpur)': BiharStationMeta(
      river: 'Burhi Gandak',
      site: 'Sikandarpur (Muzzafarpur)',
      district: 'Muzaffarpur',
      lat: 26.1209,
      lng: 85.3647,
      coversCities: [
        'Muzaffarpur',
        'Sikandarpur',
        'Aurai',
        'Kanti',
        'Marwan',
        'Paroo'
      ],
      warningLevel: 51.40,
      dangerLevel: 52.53,
      hfl: 54.29,
    ),

    // ═══════════════════════════════════════════════════════════════════════
    // GANDAK
    // ═══════════════════════════════════════════════════════════════════════

    'chatia': BiharStationMeta(
      river: 'Gandak',
      site: 'Chatia',
      district: 'East Champaran',
      lat: 26.85,
      lng: 84.90,
      coversCities: [
        'Chatia',
        'Motihari',
        'Areraj',
        'Dhaka',
        'Banjaria',
        'Paharpur'
      ],
      warningLevel: 68.10,
      dangerLevel: 69.15,
      hfl: 70.04,
    ),

    'dumariaghat': BiharStationMeta(
      river: 'Gandak',
      site: 'Dumariaghat',
      district: 'Gopalganj',
      lat: 26.4833,
      lng: 84.4667,
      coversCities: [
        'Bettiah',
        'Bagaha',
        'Narkatiaganj',
        'Raxaul',
        'Sikta',
        'Gaunaha'
      ],
      warningLevel: 61.10,
      dangerLevel: 62.22,
      hfl: 64.36,
    ),

    'hajipur': BiharStationMeta(
      river: 'Gandak',
      site: 'Hajipur',
      district: 'Vaishali',
      lat: 25.6933,
      lng: 85.2094,
      coversCities: [
        'Hajipur',
        'Vaishali',
        'Lalganj',
        'Mahua',
        'Raghopur',
        'Patepur'
      ],
      warningLevel: 49.40,
      dangerLevel: 50.32,
      hfl: 50.93,
    ),

    'rewaghat': BiharStationMeta(
      river: 'Gandak',
      site: 'Rewaghat',
      district: 'Muzaffarpur',
      lat: 26.10,
      lng: 85.30,
      coversCities: [
        'Muzaffarpur',
        'Rewaghat',
        'Minapur',
        'Kanti',
        'Sakra',
        'Bochahan'
      ],
      warningLevel: 53.40,
      dangerLevel: 54.41,
      hfl: 55.46,
    ),

    // ═══════════════════════════════════════════════════════════════════════
    // GANGA — absolute MSL values (CWC 2025 FFEM gazette)
    // ═══════════════════════════════════════════════════════════════════════

    'bhagalpur': BiharStationMeta(
      river: 'Ganga',
      site: 'Bhagalpur',
      district: 'Bhagalpur',
      lat: 25.2425,
      lng: 86.9842,
      coversCities: [
        'Bhagalpur',
        'Sultanganj',
        'Kahalgaon',
        'Naugachia',
        'Bihpur',
        'Pirpainti'
      ],
      warningLevel: 32.50,
      dangerLevel: 33.68,
      hfl: 34.86,
    ),

    'buxar': BiharStationMeta(
      river: 'Ganga',
      site: 'Buxar',
      district: 'Buxar',
      lat: 25.565,
      lng: 83.981,
      coversCities: [
        'Buxar',
        'Dumraon',
        'Simri',
        'Chausa',
        'Brahmpur',
        'Itarhi'
      ],
      warningLevel: 59.20,
      dangerLevel: 60.30,
      hfl: 62.10,
    ),

    'dighaghat': BiharStationMeta(
      river: 'Ganga',
      site: 'Dighaghat',
      district: 'Patna',
      lat: 25.5941,
      lng: 85.0700,
      coversCities: [
        'Patna',
        'Danapur',
        'Dinapur',
        'Phulwari Sharif',
        'Maner',
        'Bihta'
      ],
      warningLevel: 49.30,
      dangerLevel: 50.45,
      hfl: 52.52,
    ),

    'gandhighat': BiharStationMeta(
      river: 'Ganga',
      site: 'Gandhighat',
      district: 'Patna',
      lat: 25.6129,
      lng: 85.1376,
      coversCities: [
        'Patna',
        'Patna City',
        'Fatuha',
        'Bakhtiyarpur',
        'Mokameh',
        'Barh'
      ],
      warningLevel: 47.50,
      dangerLevel: 48.60,
      hfl: 50.52,
    ),

    'hathidah': BiharStationMeta(
      river: 'Ganga',
      site: 'Hathidah',
      district: 'Begusarai',
      lat: 25.4167,
      lng: 85.75,
      coversCities: [
        'Hathidah',
        'Begusarai',
        'Teghra',
        'Lakhisarai',
        'Suryagarha',
        'Mokameh'
      ],
      warningLevel: 40.50,
      dangerLevel: 41.76,
      hfl: 43.52,
    ),

    'kahalgaon': BiharStationMeta(
      river: 'Ganga',
      site: 'Kahalgaon',
      district: 'Bhagalpur',
      lat: 25.2167,
      lng: 87.2667,
      coversCities: [
        'Kahalgaon',
        'Pirpainti',
        'Sanho',
        'Banka',
        'Katoria',
        'Sultanganj'
      ],
      warningLevel: 30.00,
      dangerLevel: 31.09,
      hfl: 32.87,
    ),

    'munger': BiharStationMeta(
      river: 'Ganga',
      site: 'Munger',
      district: 'Munger',
      lat: 25.375,
      lng: 86.474,
      coversCities: [
        'Munger',
        'Jamalpur',
        'Tarapur',
        'Lakhisarai',
        'Suryagarha',
        'Kharagpur'
      ],
      warningLevel: 38.20,
      dangerLevel: 39.33,
      hfl: 40.99,
    ),

    // ═══════════════════════════════════════════════════════════════════════
    // GHAGHRA
    // ═══════════════════════════════════════════════════════════════════════

    'darauli': BiharStationMeta(
      river: 'Ghaghra',
      site: 'Darauli',
      district: 'Siwan',
      lat: 26.07,
      lng: 84.41,
      coversCities: [
        'Darauli',
        'Siwan',
        'Maharajganj',
        'Barharia',
        'Raghunathpur',
        'Andar'
      ],
      warningLevel: 60.50,
      dangerLevel: 60.82,
      hfl: 61.82,
    ),

    'gangpur siswan': BiharStationMeta(
      river: 'Ghaghra',
      site: 'Gangpur Siswan',
      district: 'Siwan',
      lat: 26.25,
      lng: 84.35,
      coversCities: [
        'Gangpur Siswan',
        'Siwan',
        'Gopalganj',
        'Bhore',
        'Pachrukhia',
        'Hussainganj'
      ],
      warningLevel: 56.70,
      dangerLevel: 57.04,
      hfl: 58.26,
    ),

    // ═══════════════════════════════════════════════════════════════════════
    // KAMALABALAN / KAMLA
    // ═══════════════════════════════════════════════════════════════════════

    'jhanjharpur': BiharStationMeta(
      river: 'Kamla',
      site: 'Jhanjharpur',
      district: 'Madhubani',
      lat: 26.264,
      lng: 86.279,
      coversCities: [
        'Jhanjharpur',
        'Madhubani',
        'Phulparas',
        'Pandaul',
        'Laukaha',
        'Jaynagar'
      ],
      warningLevel: 48.50,
      dangerLevel: 50.00,
      hfl: 53.11,
    ),

    'jainagar': BiharStationMeta(
      river: 'Kamla',
      site: 'Jainagar',
      district: 'Madhubani',
      lat: 26.594,
      lng: 86.226,
      coversCities: [
        'Jainagar',
        'Madhubani',
        'Benipatti',
        'Phulparas',
        'Bisfi',
        'Rahika'
      ],
      warningLevel: 67.75,
      dangerLevel: 67.75,
      hfl: 71.35,
    ),

    // FIX v2.1: explicit Kamla variant — forSite('Kamtaul (Kamla)') now returns
    // correct thresholds (WL 43.00 / DL 44.00 / HFL 45.45) instead of
    // Adhwara data (DL 50.00) which was a 6.00 m error.
    'kamtaul (kamla)': BiharStationMeta(
      river: 'Kamla',
      site: 'Kamtaul (Kamla)',
      district: 'Madhubani',
      lat: 26.392,
      lng: 85.862,
      coversCities: [
        'Kamtaul',
        'Madhubani',
        'Jainagar',
        'Jhanjharpur',
        'Phulparas',
        'Pandaul'
      ],
      warningLevel: 43.00,
      dangerLevel: 44.00,
      hfl: 45.45,
    ),

    // ═══════════════════════════════════════════════════════════════════════
    // KOSI
    // ═══════════════════════════════════════════════════════════════════════

    'baltara': BiharStationMeta(
      river: 'Kosi',
      site: 'Baltara',
      district: 'Saharsa',
      lat: 25.50,
      lng: 86.583,
      coversCities: [
        'Saharsa',
        'Simri Bakhtiyarpur',
        'Banmankhi',
        'Salkhua',
        'Mahishi',
        'Sonbarsa'
      ],
      warningLevel: 32.85,
      dangerLevel: 33.85,
      hfl: 36.40,
    ),

    'basua': BiharStationMeta(
      river: 'Kosi',
      site: 'Basua',
      district: 'Supaul',
      lat: 26.1234,
      lng: 86.602,
      coversCities: [
        'Basua',
        'Supaul',
        'Triveniganj',
        'Kishanpur',
        'Salkhua',
        'Saraigarh'
      ],
      warningLevel: 46.50,
      dangerLevel: 47.75,
      hfl: 49.24,
    ),

    'birpur': BiharStationMeta(
      river: 'Kosi', site: 'Birpur', district: 'Supaul',
      lat: 26.5167, lng: 86.90,
      coversCities: [
        'Birpur',
        'Supaul',
        'Madhepura',
        'Araria',
        'Forbesganj',
        'Saharsa',
        'Darbhanga',
        'Khagaria',
        'Bhagalpur'
      ],
      warningLevel: 73.70, dangerLevel: 76.02, hfl: 77.10, // corrected DL
    ),

    'kursela': BiharStationMeta(
      river: 'Kosi',
      site: 'Kursela',
      district: 'Katihar',
      lat: 25.48,
      lng: 87.26,
      coversCities: [
        'Kursela',
        'Katihar',
        'Manihari',
        'Amdabad',
        'Kadwa',
        'Barari'
      ],
      warningLevel: 28.80,
      dangerLevel: 30.00,
      hfl: 32.10,
    ),

    // ═══════════════════════════════════════════════════════════════════════
    // MAHANANDA
    // ═══════════════════════════════════════════════════════════════════════

    'dhengraghat': BiharStationMeta(
      river: 'Mahananda',
      site: 'Dhengraghat',
      district: 'Purnia',
      lat: 25.98,
      lng: 87.48,
      coversCities: [
        'Kishanganj',
        'Thakurganj',
        'Kochadhaman',
        'Bahadurganj',
        'Islampur',
        'Jogbani'
      ],
      warningLevel: 34.65,
      dangerLevel: 35.65,
      hfl: 38.20,
    ),

    'taibpur': BiharStationMeta(
      river: 'Mahananda',
      site: 'Taibpur',
      district: 'Kishanganj',
      lat: 26.10,
      lng: 87.95,
      coversCities: [
        'Purnia',
        'Banmankhi',
        'Kasba',
        'Araria',
        'Forbesganj',
        'Rupauli'
      ],
      warningLevel: 64.40,
      dangerLevel: 66.00,
      hfl: 67.22,
    ),

    // ═══════════════════════════════════════════════════════════════════════
    // PUNPUN
    // ═══════════════════════════════════════════════════════════════════════

    'sripalpur': BiharStationMeta(
      river: 'Punpun',
      site: 'Sripalpur',
      district: 'Patna',
      lat: 25.52,
      lng: 85.38,
      coversCities: [
        'Patna (south)',
        'Fatuha',
        'Masaurhi',
        'Jehanabad',
        'Arwal',
        'Bikram'
      ],
      warningLevel: 50.60,
      dangerLevel: 51.83,
      hfl: 53.91,
    ),
  };
}
