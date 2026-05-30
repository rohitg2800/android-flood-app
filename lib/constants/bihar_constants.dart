// Bihar Flood Watch — बिहार बाढ़ निगरानी
// All Bihar-specific constants: rivers, districts, stations, thresholds

/// Default state & station for all API calls
const String kBiharState = 'Bihar';
const String kBiharDefaultStation = 'Patna';
const double kBiharDefaultLat = 25.5941;
const double kBiharDefaultLon = 85.1376;

/// All major Bihar rivers monitored
const List<Map<String, dynamic>> kBiharRivers = [
  {
    'name': 'Ganga',
    'hindi': 'गंगा',
    'basin': 'Ganga',
    'length_km': 445,
    'stations': ['Patna', 'Bhagalpur', 'Munger', 'Hajipur', 'Buxar', 'Farakka'],
    'danger_level_m': 50.27,
    'warning_level_m': 49.27,
    'lat': 25.6,
    'lon': 85.1,
  },
  {
    'name': 'Koshi',
    'hindi': 'कोसी',
    'basin': 'Ganga',
    'length_km': 729,
    'stations': ['Supaul', 'Birpur', 'Basua', 'Nirmali', 'Khagaria'],
    'danger_level_m': 34.50,
    'warning_level_m': 33.50,
    'lat': 26.12,
    'lon': 86.98,
  },
  {
    'name': 'Gandak',
    'hindi': 'गंडक',
    'basin': 'Ganga',
    'length_km': 425,
    'stations': ['Muzaffarpur', 'Hajipur', 'Gopalganj', 'Bagha', 'Dumariaghat'],
    'danger_level_m': 57.32,
    'warning_level_m': 56.32,
    'lat': 26.12,
    'lon': 84.90,
  },
  {
    'name': 'Bagmati',
    'hindi': 'बागमती',
    'basin': 'Ganga',
    'length_km': 394,
    'stations': ['Sitamarhi', 'Muzaffarpur', 'Hayaghat', 'Runni Saidpur'],
    'danger_level_m': 55.73,
    'warning_level_m': 54.73,
    'lat': 26.60,
    'lon': 85.49,
  },
  {
    'name': 'Burhi Gandak',
    'hindi': 'बूढ़ी गंडक',
    'basin': 'Ganga',
    'length_km': 320,
    'stations': ['Muzaffarpur', 'Samastipur', 'Rosera', 'Khagaria'],
    'danger_level_m': 48.85,
    'warning_level_m': 47.85,
    'lat': 26.12,
    'lon': 85.39,
  },
  {
    'name': 'Sone',
    'hindi': 'सोन',
    'basin': 'Ganga',
    'length_km': 784,
    'stations': ['Arrah', 'Patna', 'Dehri', 'Koelwar'],
    'danger_level_m': 54.56,
    'warning_level_m': 53.56,
    'lat': 25.18,
    'lon': 84.01,
  },
  {
    'name': 'Mahananda',
    'hindi': 'महानंदा',
    'basin': 'Ganga',
    'length_km': 360,
    'stations': ['Kishanganj', 'Katihar', 'Dhantola'],
    'danger_level_m': 35.40,
    'warning_level_m': 34.40,
    'lat': 25.94,
    'lon': 87.93,
  },
  {
    'name': 'Kamla',
    'hindi': 'कमला',
    'basin': 'Ganga',
    'length_km': 328,
    'stations': ['Darbhanga', 'Jhanjharpur', 'Jainagar'],
    'danger_level_m': 47.80,
    'warning_level_m': 46.80,
    'lat': 26.30,
    'lon': 86.00,
  },
];

/// All Bihar districts with flood vulnerability
const List<Map<String, dynamic>> kBiharDistricts = [
  {'name': 'Patna',       'hindi': 'पटना',       'lat': 25.5941, 'lon': 85.1376, 'risk': 'HIGH',     'river': 'Ganga'},
  {'name': 'Darbhanga',   'hindi': 'दरभंगा',     'lat': 26.1521, 'lon': 85.8915, 'risk': 'CRITICAL', 'river': 'Bagmati'},
  {'name': 'Muzaffarpur', 'hindi': 'मुजफ्फरपुर', 'lat': 26.1209, 'lon': 85.3647, 'risk': 'CRITICAL', 'river': 'Gandak'},
  {'name': 'Bhagalpur',   'hindi': 'भागलपुर',    'lat': 25.2425, 'lon': 86.9842, 'risk': 'HIGH',     'river': 'Ganga'},
  {'name': 'Supaul',      'hindi': 'सुपौल',       'lat': 26.1239, 'lon': 86.6012, 'risk': 'CRITICAL', 'river': 'Koshi'},
  {'name': 'Sitamarhi',   'hindi': 'सीतामढ़ी',   'lat': 26.5912, 'lon': 85.4827, 'risk': 'CRITICAL', 'river': 'Bagmati'},
  {'name': 'Gopalganj',   'hindi': 'गोपालगंज',   'lat': 26.4670, 'lon': 84.4336, 'risk': 'HIGH',     'river': 'Gandak'},
  {'name': 'Samastipur',  'hindi': 'समस्तीपुर',  'lat': 25.8584, 'lon': 85.7813, 'risk': 'HIGH',     'river': 'Burhi Gandak'},
  {'name': 'Madhubani',   'hindi': 'मधुबनी',      'lat': 26.3526, 'lon': 86.0718, 'risk': 'CRITICAL', 'river': 'Kamla'},
  {'name': 'Khagaria',    'hindi': 'खगड़िया',    'lat': 25.5021, 'lon': 86.4720, 'risk': 'CRITICAL', 'river': 'Koshi'},
  {'name': 'Katihar',     'hindi': 'कटिहार',      'lat': 25.5392, 'lon': 87.5706, 'risk': 'HIGH',     'river': 'Mahananda'},
  {'name': 'Kishanganj',  'hindi': 'किशनगंज',    'lat': 26.1050, 'lon': 87.9402, 'risk': 'HIGH',     'river': 'Mahananda'},
  {'name': 'Araria',      'hindi': 'अररिया',      'lat': 26.1521, 'lon': 87.4720, 'risk': 'HIGH',     'river': 'Koshi'},
  {'name': 'Saran',       'hindi': 'सारण',        'lat': 25.9219, 'lon': 84.9126, 'risk': 'MODERATE', 'river': 'Ganga'},
  {'name': 'Vaishali',    'hindi': 'वैशाली',      'lat': 25.7163, 'lon': 85.2012, 'risk': 'MODERATE', 'river': 'Gandak'},
  {'name': 'Begusarai',   'hindi': 'बेगूसराय',   'lat': 25.4182, 'lon': 86.1338, 'risk': 'MODERATE', 'river': 'Burhi Gandak'},
  {'name': 'Munger',      'hindi': 'मुंगेर',      'lat': 25.3738, 'lon': 86.4739, 'risk': 'MODERATE', 'river': 'Ganga'},
  {'name': 'Hajipur',     'hindi': 'हाजीपुर',    'lat': 25.6900, 'lon': 85.2100, 'risk': 'HIGH',     'river': 'Gandak'},
  {'name': 'Buxar',       'hindi': 'बक्सर',       'lat': 25.5630, 'lon': 83.9760, 'risk': 'MODERATE', 'river': 'Ganga'},
  {'name': 'Siwan',       'hindi': 'सिवान',       'lat': 26.2237, 'lon': 84.3553, 'risk': 'MODERATE', 'river': 'Gandak'},
];

/// Key CWC monitoring stations in Bihar
const List<Map<String, dynamic>> kBiharStations = [
  {'id': 'patna_ganga',       'name': 'Patna',        'river': 'Ganga',       'lat': 25.5941, 'lon': 85.1376, 'danger_m': 50.27, 'warning_m': 49.27},
  {'id': 'hajipur_gandak',    'name': 'Hajipur',      'river': 'Gandak',      'lat': 25.6900, 'lon': 85.2100, 'danger_m': 57.32, 'warning_m': 56.32},
  {'id': 'supaul_koshi',      'name': 'Supaul',       'river': 'Koshi',       'lat': 26.1239, 'lon': 86.6012, 'danger_m': 34.50, 'warning_m': 33.50},
  {'id': 'muzaffarpur_bagmati','name': 'Muzaffarpur', 'river': 'Bagmati',     'lat': 26.1209, 'lon': 85.3647, 'danger_m': 55.73, 'warning_m': 54.73},
  {'id': 'bhagalpur_ganga',   'name': 'Bhagalpur',    'river': 'Ganga',       'lat': 25.2425, 'lon': 86.9842, 'danger_m': 29.30, 'warning_m': 28.30},
  {'id': 'darbhanga_kamla',   'name': 'Darbhanga',    'river': 'Kamla',       'lat': 26.1521, 'lon': 85.8915, 'danger_m': 47.80, 'warning_m': 46.80},
  {'id': 'sitamarhi_bagmati', 'name': 'Sitamarhi',    'river': 'Bagmati',     'lat': 26.5912, 'lon': 85.4827, 'danger_m': 76.50, 'warning_m': 75.50},
  {'id': 'gopalganj_gandak',  'name': 'Gopalganj',    'river': 'Gandak',      'lat': 26.4670, 'lon': 84.4336, 'danger_m': 63.20, 'warning_m': 62.20},
  {'id': 'arrah_sone',        'name': 'Arrah',         'river': 'Sone',        'lat': 25.5561, 'lon': 84.6634, 'danger_m': 54.56, 'warning_m': 53.56},
  {'id': 'katihar_mahananda', 'name': 'Katihar',      'river': 'Mahananda',   'lat': 25.5392, 'lon': 87.5706, 'danger_m': 35.40, 'warning_m': 34.40},
];

/// Severity color mapping
const Map<String, int> kSeverityColors = {
  'LOW':      0xFF4CAF50, // green
  'MODERATE': 0xFFFFC107, // amber
  'HIGH':     0xFFFF9800, // orange
  'SEVERE':   0xFFF44336, // red
  'CRITICAL': 0xFF9C27B0, // purple
};

/// Bihar monsoon season (June–October)
const int kMonsoonStartMonth = 6;
const int kMonsoonEndMonth = 10;
