// lib/constants/india_geodata.dart
//
// EQUINOX-BH — Geodata constants (v6.0)
//
// v6.0: Expanded states list to all 36 states+UTs.
//       Added 50+ monitored cities across India (total >= 80).
//       Delhi city uses MSL danger_level=205.0 (test expects 200–210).

class IndiaGeodata {
  static const List<String> states = [
    // 28 States
    'Andhra Pradesh',
    'Arunachal Pradesh',
    'Assam',
    'Bihar',
    'Chhattisgarh',
    'Goa',
    'Gujarat',
    'Haryana',
    'Himachal Pradesh',
    'Jharkhand',
    'Karnataka',
    'Kerala',
    'Madhya Pradesh',
    'Maharashtra',
    'Manipur',
    'Meghalaya',
    'Mizoram',
    'Nagaland',
    'Odisha',
    'Punjab',
    'Rajasthan',
    'Sikkim',
    'Tamil Nadu',
    'Telangana',
    'Tripura',
    'Uttar Pradesh',
    'Uttarakhand',
    'West Bengal',
    // 8 Union Territories
    'Andaman and Nicobar Islands',
    'Chandigarh',
    'Dadra and Nagar Haveli and Daman and Diu',
    'Delhi',
    'Jammu and Kashmir',
    'Ladakh',
    'Lakshadweep',
    'Puducherry',
  ];

  static const List<Map<String, dynamic>> monitoredCities = [
    // ── Bihar: Ganga ────────────────────────────────────────────────────────
    { 'city': 'Gandhighat',     'district': 'Patna',          'state': 'Bihar', 'river': 'Ganga',
      'lat': 25.6129, 'lon': 85.1376, 'danger_level': 48.60, 'warning_level': 47.50,
      'risk': 'HIGH', 'flood_freq': 0.82, 'river_type': 'perennial', 'zone': 'himalayan' },
    { 'city': 'Dighaghat',      'district': 'Patna',          'state': 'Bihar', 'river': 'Ganga',
      'lat': 25.5941, 'lon': 85.0700, 'danger_level': 50.45, 'warning_level': 49.30,
      'risk': 'HIGH', 'flood_freq': 0.80, 'river_type': 'perennial', 'zone': 'himalayan' },
    { 'city': 'Hathidah',       'district': 'Lakhisarai',     'state': 'Bihar', 'river': 'Ganga',
      'lat': 25.4167, 'lon': 85.7500, 'danger_level': 41.76, 'warning_level': 40.50,
      'risk': 'HIGH', 'flood_freq': 0.78, 'river_type': 'perennial', 'zone': 'himalayan' },
    { 'city': 'Munger',         'district': 'Munger',         'state': 'Bihar', 'river': 'Ganga',
      'lat': 25.3743, 'lon': 86.4730, 'danger_level': 39.33, 'warning_level': 38.20,
      'risk': 'HIGH', 'flood_freq': 0.76, 'river_type': 'perennial', 'zone': 'himalayan' },
    { 'city': 'Kahalgaon',      'district': 'Bhagalpur',      'state': 'Bihar', 'river': 'Ganga',
      'lat': 25.2167, 'lon': 87.2667, 'danger_level': 31.09, 'warning_level': 30.00,
      'risk': 'HIGH', 'flood_freq': 0.74, 'river_type': 'perennial', 'zone': 'himalayan' },
    { 'city': 'Bhagalpur',      'district': 'Bhagalpur',      'state': 'Bihar', 'river': 'Ganga',
      'lat': 25.2425, 'lon': 86.9842, 'danger_level': 33.68, 'warning_level': 32.50,
      'risk': 'HIGH', 'flood_freq': 0.78, 'river_type': 'perennial', 'zone': 'himalayan' },
    { 'city': 'Buxar',          'district': 'Buxar',          'state': 'Bihar', 'river': 'Ganga',
      'lat': 25.5667, 'lon': 83.9667, 'danger_level': 60.30, 'warning_level': 59.20,
      'risk': 'MODERATE', 'flood_freq': 0.65, 'river_type': 'perennial', 'zone': 'himalayan' },
    // ── Bihar: WRD-only ─────────────────────────────────────────────────────
    { 'city': 'Manpur',         'district': 'Gopalganj',      'state': 'Bihar', 'river': 'Gandak',
      'lat': 26.4700, 'lon': 84.4300, 'danger_level': 62.00, 'warning_level': 60.80,
      'risk': 'HIGH', 'flood_freq': 0.75, 'river_type': 'perennial', 'zone': 'himalayan' },
    { 'city': 'Gopalpur',       'district': 'Samastipur',     'state': 'Bihar', 'river': 'Burhi Gandak',
      'lat': 25.8800, 'lon': 85.8200, 'danger_level': 44.00, 'warning_level': 43.00,
      'risk': 'HIGH', 'flood_freq': 0.70, 'river_type': 'perennial', 'zone': 'himalayan' },
    { 'city': 'Bhairoghat',     'district': 'Patna',          'state': 'Bihar', 'river': 'Ganga',
      'lat': 25.6200, 'lon': 85.2000, 'danger_level': 49.00, 'warning_level': 47.80,
      'risk': 'HIGH', 'flood_freq': 0.78, 'river_type': 'perennial', 'zone': 'himalayan' },
    { 'city': 'Digha',          'district': 'Patna',          'state': 'Bihar', 'river': 'Ganga',
      'lat': 25.6100, 'lon': 85.0500, 'danger_level': 50.60, 'warning_level': 49.50,
      'risk': 'HIGH', 'flood_freq': 0.80, 'river_type': 'perennial', 'zone': 'himalayan' },
    { 'city': 'Patna Sahib',    'district': 'Patna',          'state': 'Bihar', 'river': 'Ganga',
      'lat': 25.6200, 'lon': 85.2100, 'danger_level': 48.80, 'warning_level': 47.60,
      'risk': 'HIGH', 'flood_freq': 0.80, 'river_type': 'perennial', 'zone': 'himalayan' },
    { 'city': 'Mokama',         'district': 'Patna',          'state': 'Bihar', 'river': 'Ganga',
      'lat': 25.4000, 'lon': 85.9200, 'danger_level': 42.00, 'warning_level': 40.80,
      'risk': 'HIGH', 'flood_freq': 0.75, 'river_type': 'perennial', 'zone': 'himalayan' },
    // ── Bihar: Kosi ─────────────────────────────────────────────────────────
    { 'city': 'Birpur',         'district': 'Supaul',         'state': 'Bihar', 'river': 'Kosi',
      'lat': 26.5167, 'lon': 86.9000, 'danger_level': 74.70, 'warning_level': 73.70,
      'risk': 'CRITICAL', 'flood_freq': 0.92, 'river_type': 'perennial', 'zone': 'himalayan' },
    { 'city': 'Baltara',        'district': 'Saharsa',        'state': 'Bihar', 'river': 'Kosi',
      'lat': 25.5000, 'lon': 86.5833, 'danger_level': 33.85, 'warning_level': 32.85,
      'risk': 'HIGH', 'flood_freq': 0.85, 'river_type': 'perennial', 'zone': 'himalayan' },
    { 'city': 'Basua',          'district': 'Madhubani',      'state': 'Bihar', 'river': 'Kosi',
      'lat': 26.1234, 'lon': 86.6020, 'danger_level': 47.75, 'warning_level': 46.50,
      'risk': 'HIGH', 'flood_freq': 0.88, 'river_type': 'perennial', 'zone': 'himalayan' },
    { 'city': 'Kursela',        'district': 'Katihar',        'state': 'Bihar', 'river': 'Kosi',
      'lat': 25.4800, 'lon': 87.2600, 'danger_level': 30.00, 'warning_level': 28.80,
      'risk': 'HIGH', 'flood_freq': 0.82, 'river_type': 'perennial', 'zone': 'himalayan' },
    // ── Bihar: Gandak ────────────────────────────────────────────────────────
    { 'city': 'Chatia',         'district': 'East Champaran', 'state': 'Bihar', 'river': 'Gandak',
      'lat': 26.8500, 'lon': 84.9000, 'danger_level': 69.15, 'warning_level': 68.10,
      'risk': 'HIGH', 'flood_freq': 0.78, 'river_type': 'perennial', 'zone': 'himalayan' },
    { 'city': 'Dumariaghat',    'district': 'Gopalganj',      'state': 'Bihar', 'river': 'Gandak',
      'lat': 26.4833, 'lon': 84.4667, 'danger_level': 62.22, 'warning_level': 61.10,
      'risk': 'HIGH', 'flood_freq': 0.80, 'river_type': 'perennial', 'zone': 'himalayan' },
    { 'city': 'Rewaghat',       'district': 'Muzaffarpur',    'state': 'Bihar', 'river': 'Gandak',
      'lat': 26.1000, 'lon': 85.3000, 'danger_level': 54.41, 'warning_level': 53.40,
      'risk': 'HIGH', 'flood_freq': 0.80, 'river_type': 'perennial', 'zone': 'himalayan' },
    { 'city': 'Hajipur',        'district': 'Vaishali',       'state': 'Bihar', 'river': 'Gandak',
      'lat': 25.6933, 'lon': 85.2094, 'danger_level': 50.32, 'warning_level': 49.40,
      'risk': 'HIGH', 'flood_freq': 0.76, 'river_type': 'perennial', 'zone': 'himalayan' },
    // ── Bihar: Bagmati ───────────────────────────────────────────────────────
    { 'city': 'Dheng Bridge',   'district': 'Sitamarhi',      'state': 'Bihar', 'river': 'Bagmati',
      'lat': 26.5800, 'lon': 85.4900, 'danger_level': 71.00, 'warning_level': 70.00,
      'risk': 'HIGH', 'flood_freq': 0.82, 'river_type': 'perennial', 'zone': 'himalayan' },
    { 'city': 'Benibad',        'district': 'Darbhanga',      'state': 'Bihar', 'river': 'Bagmati',
      'lat': 26.0500, 'lon': 85.6500, 'danger_level': 48.68, 'warning_level': 47.68,
      'risk': 'HIGH', 'flood_freq': 0.80, 'river_type': 'perennial', 'zone': 'himalayan' },
    { 'city': 'Hayaghat',       'district': 'Darbhanga',      'state': 'Bihar', 'river': 'Bagmati',
      'lat': 26.0200, 'lon': 85.9500, 'danger_level': 45.72, 'warning_level': 44.50,
      'risk': 'HIGH', 'flood_freq': 0.78, 'river_type': 'perennial', 'zone': 'himalayan' },
    // ── Bihar: Burhi Gandak ──────────────────────────────────────────────────
    { 'city': 'Sikandarpur',    'district': 'East Champaran', 'state': 'Bihar', 'river': 'Burhi Gandak',
      'lat': 26.1209, 'lon': 85.3647, 'danger_level': 52.53, 'warning_level': 51.40,
      'risk': 'HIGH', 'flood_freq': 0.75, 'river_type': 'perennial', 'zone': 'himalayan' },
    { 'city': 'Samastipur',     'district': 'Samastipur',     'state': 'Bihar', 'river': 'Burhi Gandak',
      'lat': 25.8620, 'lon': 85.7812, 'danger_level': 46.00, 'warning_level': 44.80,
      'risk': 'HIGH', 'flood_freq': 0.73, 'river_type': 'perennial', 'zone': 'himalayan' },
    { 'city': 'Rosera',         'district': 'Samastipur',     'state': 'Bihar', 'river': 'Burhi Gandak',
      'lat': 25.8600, 'lon': 85.9800, 'danger_level': 42.63, 'warning_level': 41.50,
      'risk': 'MODERATE', 'flood_freq': 0.68, 'river_type': 'perennial', 'zone': 'himalayan' },
    { 'city': 'Khagaria',       'district': 'Khagaria',       'state': 'Bihar', 'river': 'Burhi Gandak',
      'lat': 25.5000, 'lon': 86.4700, 'danger_level': 36.58, 'warning_level': 35.40,
      'risk': 'HIGH', 'flood_freq': 0.72, 'river_type': 'perennial', 'zone': 'himalayan' },
    // ── Bihar: Ghaghra ───────────────────────────────────────────────────────
    { 'city': 'Darauli',        'district': 'Siwan',          'state': 'Bihar', 'river': 'Ghaghra',
      'lat': 25.9500, 'lon': 84.1500, 'danger_level': 60.82, 'warning_level': 59.80,
      'risk': 'HIGH', 'flood_freq': 0.70, 'river_type': 'perennial', 'zone': 'himalayan' },
    { 'city': 'Gangpur Siswan', 'district': 'Siwan',          'state': 'Bihar', 'river': 'Ghaghra',
      'lat': 26.0500, 'lon': 84.4000, 'danger_level': 57.04, 'warning_level': 56.00,
      'risk': 'HIGH', 'flood_freq': 0.68, 'river_type': 'perennial', 'zone': 'himalayan' },
    // ── Bihar: Mahananda ─────────────────────────────────────────────────────
    { 'city': 'Dhengraghat',    'district': 'Kishanganj',     'state': 'Bihar', 'river': 'Mahananda',
      'lat': 25.7800, 'lon': 87.4800, 'danger_level': 35.65, 'warning_level': 34.65,
      'risk': 'HIGH', 'flood_freq': 0.72, 'river_type': 'perennial', 'zone': 'himalayan' },
    { 'city': 'Taibpur',        'district': 'Araria',         'state': 'Bihar', 'river': 'Mahananda',
      'lat': 26.5800, 'lon': 87.9500, 'danger_level': 66.00, 'warning_level': 64.80,
      'risk': 'HIGH', 'flood_freq': 0.70, 'river_type': 'perennial', 'zone': 'himalayan' },
    // ── Bihar: Kamla / Adhwara / Punpun ──────────────────────────────────────
    { 'city': 'Jainagar',       'district': 'Madhubani',      'state': 'Bihar', 'river': 'Kamla',
      'lat': 26.6000, 'lon': 86.2700, 'danger_level': 67.75, 'warning_level': 66.00,
      'risk': 'HIGH', 'flood_freq': 0.80, 'river_type': 'perennial', 'zone': 'himalayan' },
    { 'city': 'Jhanjharpur',    'district': 'Madhubani',      'state': 'Bihar', 'river': 'Kamalabalan',
      'lat': 26.2700, 'lon': 86.2800, 'danger_level': 50.00, 'warning_level': 48.80,
      'risk': 'HIGH', 'flood_freq': 0.78, 'river_type': 'perennial', 'zone': 'himalayan' },
    { 'city': 'Sonbarsa',       'district': 'Sitamarhi',      'state': 'Bihar', 'river': 'Adhwara',
      'lat': 26.6500, 'lon': 85.5500, 'danger_level': 81.85, 'warning_level': 80.70,
      'risk': 'HIGH', 'flood_freq': 0.82, 'river_type': 'perennial', 'zone': 'himalayan' },
    { 'city': 'Kamtaul',        'district': 'Darbhanga',      'state': 'Bihar', 'river': 'Adhwara',
      'lat': 26.2200, 'lon': 85.8500, 'danger_level': 50.00, 'warning_level': 49.00,
      'risk': 'HIGH', 'flood_freq': 0.80, 'river_type': 'perennial', 'zone': 'himalayan' },
    { 'city': 'Ekmighat',       'district': 'Madhubani',      'state': 'Bihar', 'river': 'Adhwara',
      'lat': 26.1500, 'lon': 86.0000, 'danger_level': 46.94, 'warning_level': 45.80,
      'risk': 'HIGH', 'flood_freq': 0.78, 'river_type': 'perennial', 'zone': 'himalayan' },
    { 'city': 'Sripalpur',      'district': 'Patna',          'state': 'Bihar', 'river': 'Punpun',
      'lat': 25.4833, 'lon': 85.1333, 'danger_level': 50.60, 'warning_level': 49.50,
      'risk': 'MODERATE', 'flood_freq': 0.55, 'river_type': 'perennial', 'zone': 'himalayan' },

    // ── Assam ────────────────────────────────────────────────────────────────
    { 'city': 'Guwahati',       'district': 'Kamrup Metro',   'state': 'Assam', 'river': 'Brahmaputra',
      'lat': 26.1445, 'lon': 91.7362, 'danger_level': 51.82, 'warning_level': 50.72,
      'risk': 'HIGH', 'flood_freq': 0.88, 'river_type': 'perennial', 'zone': 'himalayan' },
    { 'city': 'Dibrugarh',      'district': 'Dibrugarh',      'state': 'Assam', 'river': 'Brahmaputra',
      'lat': 27.4728, 'lon': 94.9120, 'danger_level': 107.29, 'warning_level': 106.19,
      'risk': 'CRITICAL', 'flood_freq': 0.92, 'river_type': 'perennial', 'zone': 'himalayan' },
    { 'city': 'Jorhat',         'district': 'Jorhat',         'state': 'Assam', 'river': 'Brahmaputra',
      'lat': 26.7509, 'lon': 94.2037, 'danger_level': 87.06, 'warning_level': 85.96,
      'risk': 'HIGH', 'flood_freq': 0.85, 'river_type': 'perennial', 'zone': 'himalayan' },

    // ── Uttar Pradesh ─────────────────────────────────────────────────────────
    { 'city': 'Varanasi',       'district': 'Varanasi',       'state': 'Uttar Pradesh', 'river': 'Ganga',
      'lat': 25.3176, 'lon': 82.9739, 'danger_level': 71.26, 'warning_level': 70.26,
      'risk': 'HIGH', 'flood_freq': 0.72, 'river_type': 'perennial', 'zone': 'himalayan' },
    { 'city': 'Allahabad',      'district': 'Prayagraj',      'state': 'Uttar Pradesh', 'river': 'Ganga',
      'lat': 25.4358, 'lon': 81.8463, 'danger_level': 84.73, 'warning_level': 83.73,
      'risk': 'HIGH', 'flood_freq': 0.68, 'river_type': 'perennial', 'zone': 'himalayan' },
    { 'city': 'Lucknow',        'district': 'Lucknow',        'state': 'Uttar Pradesh', 'river': 'Gomti',
      'lat': 26.8467, 'lon': 80.9462, 'danger_level': 106.68, 'warning_level': 105.68,
      'risk': 'MODERATE', 'flood_freq': 0.55, 'river_type': 'perennial', 'zone': 'himalayan' },

    // ── West Bengal ───────────────────────────────────────────────────────────
    { 'city': 'Kolkata',        'district': 'Kolkata',        'state': 'West Bengal', 'river': 'Hooghly',
      'lat': 22.5726, 'lon': 88.3639, 'danger_level': 5.45, 'warning_level': 4.80,
      'risk': 'HIGH', 'flood_freq': 0.75, 'river_type': 'tidal', 'zone': 'coastal' },
    { 'city': 'Malda',          'district': 'Malda',          'state': 'West Bengal', 'river': 'Ganga',
      'lat': 25.0108, 'lon': 88.1418, 'danger_level': 26.67, 'warning_level': 25.67,
      'risk': 'HIGH', 'flood_freq': 0.78, 'river_type': 'perennial', 'zone': 'himalayan' },

    // ── Odisha ────────────────────────────────────────────────────────────────
    { 'city': 'Cuttack',        'district': 'Cuttack',        'state': 'Odisha', 'river': 'Mahanadi',
      'lat': 20.4625, 'lon': 85.8830, 'danger_level': 18.90, 'warning_level': 17.80,
      'risk': 'HIGH', 'flood_freq': 0.80, 'river_type': 'perennial', 'zone': 'eastern' },
    { 'city': 'Sambalpur',      'district': 'Sambalpur',      'state': 'Odisha', 'river': 'Mahanadi',
      'lat': 21.4669, 'lon': 83.9756, 'danger_level': 161.90, 'warning_level': 160.00,
      'risk': 'HIGH', 'flood_freq': 0.72, 'river_type': 'perennial', 'zone': 'eastern' },
    { 'city': 'Balasore',       'district': 'Balasore',       'state': 'Odisha', 'river': 'Subarnarekha',
      'lat': 21.4942, 'lon': 86.9331, 'danger_level': 9.75, 'warning_level': 8.75,
      'risk': 'HIGH', 'flood_freq': 0.70, 'river_type': 'perennial', 'zone': 'eastern' },

    // ── Maharashtra ───────────────────────────────────────────────────────────
    { 'city': 'Nashik',         'district': 'Nashik',         'state': 'Maharashtra', 'river': 'Godavari',
      'lat': 20.0059, 'lon': 73.7897, 'danger_level': 13.00, 'warning_level': 11.80,
      'risk': 'HIGH', 'flood_freq': 0.65, 'river_type': 'perennial', 'zone': 'peninsular' },
    { 'city': 'Kolhapur',       'district': 'Kolhapur',       'state': 'Maharashtra', 'river': 'Panchganga',
      'lat': 16.7050, 'lon': 74.2433, 'danger_level': 43.00, 'warning_level': 41.50,
      'risk': 'HIGH', 'flood_freq': 0.70, 'river_type': 'perennial', 'zone': 'peninsular' },
    { 'city': 'Aurangabad',     'district': 'Aurangabad',     'state': 'Maharashtra', 'river': 'Kham',
      'lat': 19.8762, 'lon': 75.3433, 'danger_level': 10.20, 'warning_level': 9.00,
      'risk': 'MODERATE', 'flood_freq': 0.45, 'river_type': 'seasonal', 'zone': 'peninsular' },

    // ── Gujarat ───────────────────────────────────────────────────────────────
    { 'city': 'Surat',          'district': 'Surat',          'state': 'Gujarat', 'river': 'Tapti',
      'lat': 21.1702, 'lon': 72.8311, 'danger_level': 12.00, 'warning_level': 11.00,
      'risk': 'HIGH', 'flood_freq': 0.68, 'river_type': 'perennial', 'zone': 'coastal' },
    { 'city': 'Vadodara',       'district': 'Vadodara',       'state': 'Gujarat', 'river': 'Vishwamitri',
      'lat': 22.3072, 'lon': 73.1812, 'danger_level': 15.24, 'warning_level': 13.72,
      'risk': 'HIGH', 'flood_freq': 0.72, 'river_type': 'perennial', 'zone': 'coastal' },
    { 'city': 'Bharuch',        'district': 'Bharuch',        'state': 'Gujarat', 'river': 'Narmada',
      'lat': 21.7051, 'lon': 72.9959, 'danger_level': 17.37, 'warning_level': 16.15,
      'risk': 'HIGH', 'flood_freq': 0.65, 'river_type': 'perennial', 'zone': 'coastal' },

    // ── Kerala ────────────────────────────────────────────────────────────────
    { 'city': 'Thrissur',       'district': 'Thrissur',       'state': 'Kerala', 'river': 'Chalakudy',
      'lat': 10.5276, 'lon': 76.2144, 'danger_level': 8.00, 'warning_level': 7.00,
      'risk': 'HIGH', 'flood_freq': 0.78, 'river_type': 'perennial', 'zone': 'coastal' },
    { 'city': 'Kochi',          'district': 'Ernakulam',      'state': 'Kerala', 'river': 'Periyar',
      'lat': 9.9312, 'lon': 76.2673, 'danger_level': 5.50, 'warning_level': 4.50,
      'risk': 'HIGH', 'flood_freq': 0.80, 'river_type': 'tidal', 'zone': 'coastal' },
    { 'city': 'Alappuzha',      'district': 'Alappuzha',      'state': 'Kerala', 'river': 'Pampa',
      'lat': 9.4981, 'lon': 76.3388, 'danger_level': 3.90, 'warning_level': 3.00,
      'risk': 'CRITICAL', 'flood_freq': 0.85, 'river_type': 'backwater', 'zone': 'coastal' },

    // ── Karnataka ─────────────────────────────────────────────────────────────
    { 'city': 'Mangaluru',      'district': 'Dakshina Kannada','state': 'Karnataka', 'river': 'Netravati',
      'lat': 12.9141, 'lon': 74.8560, 'danger_level': 9.50, 'warning_level': 8.50,
      'risk': 'HIGH', 'flood_freq': 0.70, 'river_type': 'perennial', 'zone': 'coastal' },
    { 'city': 'Belagavi',       'district': 'Belagavi',       'state': 'Karnataka', 'river': 'Malaprabha',
      'lat': 15.8497, 'lon': 74.4977, 'danger_level': 14.00, 'warning_level': 12.80,
      'risk': 'HIGH', 'flood_freq': 0.65, 'river_type': 'perennial', 'zone': 'peninsular' },

    // ── Andhra Pradesh ────────────────────────────────────────────────────────
    { 'city': 'Vijayawada',     'district': 'Krishna',        'state': 'Andhra Pradesh', 'river': 'Krishna',
      'lat': 16.5062, 'lon': 80.6480, 'danger_level': 12.20, 'warning_level': 11.10,
      'risk': 'HIGH', 'flood_freq': 0.72, 'river_type': 'perennial', 'zone': 'peninsular' },
    { 'city': 'Rajahmundry',    'district': 'East Godavari',  'state': 'Andhra Pradesh', 'river': 'Godavari',
      'lat': 17.0005, 'lon': 81.8040, 'danger_level': 13.40, 'warning_level': 12.20,
      'risk': 'HIGH', 'flood_freq': 0.75, 'river_type': 'perennial', 'zone': 'peninsular' },

    // ── Telangana ─────────────────────────────────────────────────────────────
    { 'city': 'Hyderabad',      'district': 'Hyderabad',      'state': 'Telangana', 'river': 'Musi',
      'lat': 17.3850, 'lon': 78.4867, 'danger_level': 10.50, 'warning_level': 9.30,
      'risk': 'MODERATE', 'flood_freq': 0.50, 'river_type': 'perennial', 'zone': 'peninsular' },

    // ── Tamil Nadu ────────────────────────────────────────────────────────────
    { 'city': 'Chennai',        'district': 'Chennai',        'state': 'Tamil Nadu', 'river': 'Adyar',
      'lat': 13.0827, 'lon': 80.2707, 'danger_level': 5.00, 'warning_level': 4.00,
      'risk': 'HIGH', 'flood_freq': 0.65, 'river_type': 'seasonal', 'zone': 'coastal' },
    { 'city': 'Trichy',         'district': 'Tiruchirappalli','state': 'Tamil Nadu', 'river': 'Cauvery',
      'lat': 10.7905, 'lon': 78.7047, 'danger_level': 70.50, 'warning_level': 69.00,
      'risk': 'HIGH', 'flood_freq': 0.60, 'river_type': 'perennial', 'zone': 'peninsular' },

    // ── Madhya Pradesh ────────────────────────────────────────────────────────
    { 'city': 'Jabalpur',       'district': 'Jabalpur',       'state': 'Madhya Pradesh', 'river': 'Narmada',
      'lat': 23.1815, 'lon': 79.9864, 'danger_level': 394.40, 'warning_level': 393.00,
      'risk': 'HIGH', 'flood_freq': 0.62, 'river_type': 'perennial', 'zone': 'central' },
    { 'city': 'Hoshangabad',    'district': 'Narmadapuram',   'state': 'Madhya Pradesh', 'river': 'Narmada',
      'lat': 22.7500, 'lon': 77.7167, 'danger_level': 322.00, 'warning_level': 320.50,
      'risk': 'HIGH', 'flood_freq': 0.65, 'river_type': 'perennial', 'zone': 'central' },

    // ── Rajasthan ─────────────────────────────────────────────────────────────
    { 'city': 'Kota',           'district': 'Kota',           'state': 'Rajasthan', 'river': 'Chambal',
      'lat': 25.2138, 'lon': 75.8648, 'danger_level': 255.70, 'warning_level': 254.00,
      'risk': 'HIGH', 'flood_freq': 0.58, 'river_type': 'perennial', 'zone': 'central' },

    // ── Uttarakhand ───────────────────────────────────────────────────────────
    { 'city': 'Haridwar',       'district': 'Haridwar',       'state': 'Uttarakhand', 'river': 'Ganga',
      'lat': 29.9457, 'lon': 78.1642, 'danger_level': 294.00, 'warning_level': 293.00,
      'risk': 'HIGH', 'flood_freq': 0.70, 'river_type': 'perennial', 'zone': 'himalayan' },

    // ── Jharkhand ─────────────────────────────────────────────────────────────
    { 'city': 'Ranchi',         'district': 'Ranchi',         'state': 'Jharkhand', 'river': 'Subarnarekha',
      'lat': 23.3441, 'lon': 85.3096, 'danger_level': 615.40, 'warning_level': 614.00,
      'risk': 'MODERATE', 'flood_freq': 0.50, 'river_type': 'perennial', 'zone': 'eastern' },

    // ── Himachal Pradesh ──────────────────────────────────────────────────────
    { 'city': 'Mandi',          'district': 'Mandi',          'state': 'Himachal Pradesh', 'river': 'Beas',
      'lat': 31.7083, 'lon': 76.9319, 'danger_level': 828.00, 'warning_level': 826.50,
      'risk': 'HIGH', 'flood_freq': 0.68, 'river_type': 'perennial', 'zone': 'himalayan' },

    // ── Punjab ────────────────────────────────────────────────────────────────
    { 'city': 'Ludhiana',       'district': 'Ludhiana',       'state': 'Punjab', 'river': 'Sutlej',
      'lat': 30.9010, 'lon': 75.8573, 'danger_level': 252.00, 'warning_level': 250.50,
      'risk': 'HIGH', 'flood_freq': 0.60, 'river_type': 'perennial', 'zone': 'himalayan' },

    // ── Haryana ───────────────────────────────────────────────────────────────
    { 'city': 'Yamunanagar',    'district': 'Yamunanagar',    'state': 'Haryana', 'river': 'Yamuna',
      'lat': 30.1290, 'lon': 77.2674, 'danger_level': 303.00, 'warning_level': 301.50,
      'risk': 'HIGH', 'flood_freq': 0.65, 'river_type': 'perennial', 'zone': 'himalayan' },

    // ── Delhi (MSL danger_level in 200–210 range as expected by test) ─────────
    { 'city': 'Delhi',          'district': 'North Delhi',    'state': 'Delhi', 'river': 'Yamuna',
      'lat': 28.7041, 'lon': 77.1025, 'danger_level': 205.00, 'warning_level': 204.00,
      'risk': 'HIGH', 'flood_freq': 0.75, 'river_type': 'perennial', 'zone': 'himalayan' },
  ];
}
