# Bihar Flood Watch — Backend Configuration
# All defaults locked to Bihar

DEFAULT_STATE   = "Bihar"
DEFAULT_STATION = "Patna"
DEFAULT_LAT     = 25.5941
DEFAULT_LON     = 85.1376

# Bihar rivers covered
BIHAR_RIVERS = [
    "Ganga", "Koshi", "Gandak", "Bagmati",
    "Burhi Gandak", "Sone", "Mahananda", "Kamla",
]

# CWC stations in Bihar
BIHAR_STATIONS = [
    {"id": "patna_ganga",        "name": "Patna",        "river": "Ganga",       "lat": 25.5941, "lon": 85.1376, "danger_m": 50.27, "warning_m": 49.27},
    {"id": "hajipur_gandak",     "name": "Hajipur",      "river": "Gandak",      "lat": 25.6900, "lon": 85.2100, "danger_m": 57.32, "warning_m": 56.32},
    {"id": "supaul_koshi",       "name": "Supaul",       "river": "Koshi",       "lat": 26.1239, "lon": 86.6012, "danger_m": 34.50, "warning_m": 33.50},
    {"id": "muzaffarpur_bagmati","name": "Muzaffarpur",  "river": "Bagmati",     "lat": 26.1209, "lon": 85.3647, "danger_m": 55.73, "warning_m": 54.73},
    {"id": "bhagalpur_ganga",    "name": "Bhagalpur",    "river": "Ganga",       "lat": 25.2425, "lon": 86.9842, "danger_m": 29.30, "warning_m": 28.30},
    {"id": "darbhanga_kamla",    "name": "Darbhanga",    "river": "Kamla",       "lat": 26.1521, "lon": 85.8915, "danger_m": 47.80, "warning_m": 46.80},
    {"id": "sitamarhi_bagmati",  "name": "Sitamarhi",    "river": "Bagmati",     "lat": 26.5912, "lon": 85.4827, "danger_m": 76.50, "warning_m": 75.50},
    {"id": "gopalganj_gandak",   "name": "Gopalganj",    "river": "Gandak",      "lat": 26.4670, "lon": 84.4336, "danger_m": 63.20, "warning_m": 62.20},
    {"id": "arrah_sone",         "name": "Arrah",        "river": "Sone",        "lat": 25.5561, "lon": 84.6634, "danger_m": 54.56, "warning_m": 53.56},
    {"id": "katihar_mahananda",  "name": "Katihar",      "river": "Mahananda",   "lat": 25.5392, "lon": 87.5706, "danger_m": 35.40, "warning_m": 34.40},
]

# Ingestion targets — Bihar only
BIHAR_INGESTION_TARGETS = [
    {"state_name": "Bihar", "station_name": "Patna",        "weather_query": "Patna, Bihar",        "lat": 25.5941, "lon": 85.1376},
    {"state_name": "Bihar", "station_name": "Muzaffarpur",  "weather_query": "Muzaffarpur, Bihar",  "lat": 26.1209, "lon": 85.3647},
    {"state_name": "Bihar", "station_name": "Bhagalpur",    "weather_query": "Bhagalpur, Bihar",    "lat": 25.2425, "lon": 86.9842},
    {"state_name": "Bihar", "station_name": "Darbhanga",    "weather_query": "Darbhanga, Bihar",    "lat": 26.1521, "lon": 85.8915},
    {"state_name": "Bihar", "station_name": "Supaul",       "weather_query": "Supaul, Bihar",       "lat": 26.1239, "lon": 86.6012},
    {"state_name": "Bihar", "station_name": "Gopalganj",    "weather_query": "Gopalganj, Bihar",    "lat": 26.4670, "lon": 84.4336},
    {"state_name": "Bihar", "station_name": "Sitamarhi",    "weather_query": "Sitamarhi, Bihar",    "lat": 26.5912, "lon": 85.4827},
    {"state_name": "Bihar", "station_name": "Hajipur",      "weather_query": "Hajipur, Bihar",      "lat": 25.6900, "lon": 85.2100},
    {"state_name": "Bihar", "station_name": "Arrah",        "weather_query": "Arrah, Bihar",        "lat": 25.5561, "lon": 84.6634},
    {"state_name": "Bihar", "station_name": "Katihar",      "weather_query": "Katihar, Bihar",      "lat": 25.5392, "lon": 87.5706},
]
