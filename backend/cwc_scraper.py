"""
cwc_scraper.py  —  OpsFlood Backend v11 (Open-Meteo GloFAS Edition)

Bihar: 120+ cities/blocks/gauge-points across all 38 districts.
Fix: _fetch_city_flood now sets state_name == state so get_live_telemetry
     filter finds all Bihar entries correctly (was returning only 14/60).
"""

import os
import datetime
import threading
import requests
from concurrent.futures import ThreadPoolExecutor, as_completed
from typing import Dict, Any, List, Optional

try:
    from backend.state_severity_matrix import get_state_severity_entry
except ImportError:
    from state_severity_matrix import get_state_severity_entry


# ─────────────────────────────────────────────────────────────────────────────
# CITY / GAUGE-POINT REGISTRY
# 120+ Bihar entries (all 38 districts, multiple towns + CWC gauge points)
# + ~80 rest-of-India for other states
# ─────────────────────────────────────────────────────────────────────────────
CITY_COORDS: List[Dict[str, Any]] = [

    # ══════════════════════════════════════════════════════════════════════
    # BIHAR — 38 districts, 120+ cities / blocks / CWC gauge-points
    # Source: CWC Flood Bulletins, FMISC WRD Bihar, IMD district HQ coords
    # ══════════════════════════════════════════════════════════════════════

    # ── 1. Patna ──────────────────────────────────────────────────────────
    {"city": "Patna",             "state": "Bihar", "lat": 25.5941, "lon": 85.1376, "river": "Ganga",        "district": "Patna"},
    {"city": "Gandhi Setu",       "state": "Bihar", "lat": 25.7360, "lon": 85.0040, "river": "Ganga",        "district": "Patna"},
    {"city": "Gandhighat",        "state": "Bihar", "lat": 25.6210, "lon": 85.1370, "river": "Ganga",        "district": "Patna"},
    {"city": "Danapur",           "state": "Bihar", "lat": 25.6200, "lon": 85.0400, "river": "Ganga",        "district": "Patna"},
    {"city": "Phulwari Sharif",   "state": "Bihar", "lat": 25.5420, "lon": 85.1100, "river": "Sone",         "district": "Patna"},
    {"city": "Mokama",            "state": "Bihar", "lat": 25.4020, "lon": 85.9220, "river": "Ganga",        "district": "Patna"},
    {"city": "Barh",              "state": "Bihar", "lat": 25.4820, "lon": 85.7020, "river": "Ganga",        "district": "Patna"},
    {"city": "Fatuha",            "state": "Bihar", "lat": 25.5120, "lon": 85.3120, "river": "Ganga",        "district": "Patna"},
    {"city": "Bakhtiyarpur",      "state": "Bihar", "lat": 25.4620, "lon": 85.5320, "river": "Ganga",        "district": "Patna"},
    {"city": "Punpun",            "state": "Bihar", "lat": 25.5020, "lon": 85.2320, "river": "Punpun",       "district": "Patna"},

    # ── 2. Nalanda ────────────────────────────────────────────────────────
    {"city": "Bihar Sharif",      "state": "Bihar", "lat": 25.1983, "lon": 85.5234, "river": "Panchane",     "district": "Nalanda"},
    {"city": "Rajgir",            "state": "Bihar", "lat": 25.0280, "lon": 85.4220, "river": "Panchane",     "district": "Nalanda"},
    {"city": "Hilsa",             "state": "Bihar", "lat": 25.2920, "lon": 85.2820, "river": "Panchane",     "district": "Nalanda"},
    {"city": "Islampur",          "state": "Bihar", "lat": 25.1380, "lon": 85.6580, "river": "Panchane",     "district": "Nalanda"},

    # ── 3. Gaya ───────────────────────────────────────────────────────────
    {"city": "Gaya",              "state": "Bihar", "lat": 24.7955, "lon": 85.0002, "river": "Falgu",        "district": "Gaya"},
    {"city": "Bodh Gaya",         "state": "Bihar", "lat": 24.6960, "lon": 84.9910, "river": "Falgu",        "district": "Gaya"},
    {"city": "Sherghati",         "state": "Bihar", "lat": 24.5610, "lon": 84.7920, "river": "Falgu",        "district": "Gaya"},
    {"city": "Dobhi",             "state": "Bihar", "lat": 24.4820, "lon": 84.6720, "river": "Falgu",        "district": "Gaya"},

    # ── 4. Nawada ─────────────────────────────────────────────────────────
    {"city": "Nawada",            "state": "Bihar", "lat": 24.8864, "lon": 85.5449, "river": "Sakri",        "district": "Nawada"},
    {"city": "Rajauli",           "state": "Bihar", "lat": 24.6420, "lon": 85.7220, "river": "Sakri",        "district": "Nawada"},
    {"city": "Warsaliganj",       "state": "Bihar", "lat": 24.9120, "lon": 85.6420, "river": "Sakri",        "district": "Nawada"},

    # ── 5. Aurangabad ─────────────────────────────────────────────────────
    {"city": "Aurangabad",        "state": "Bihar", "lat": 24.7522, "lon": 84.3742, "river": "Son",          "district": "Aurangabad"},
    {"city": "Daudnagar",         "state": "Bihar", "lat": 24.9020, "lon": 84.3920, "river": "Son",          "district": "Aurangabad"},
    {"city": "Obra",              "state": "Bihar", "lat": 24.7820, "lon": 84.2720, "river": "Son",          "district": "Aurangabad"},
    {"city": "Rafiganj",          "state": "Bihar", "lat": 24.8020, "lon": 84.6420, "river": "Son",          "district": "Aurangabad"},

    # ── 6. Arwal ──────────────────────────────────────────────────────────
    {"city": "Arwal",             "state": "Bihar", "lat": 25.2488, "lon": 84.6820, "river": "Son",          "district": "Arwal"},
    {"city": "Kaler",             "state": "Bihar", "lat": 25.2120, "lon": 84.5920, "river": "Son",          "district": "Arwal"},

    # ── 7. Jehanabad ──────────────────────────────────────────────────────
    {"city": "Jehanabad",         "state": "Bihar", "lat": 25.2100, "lon": 84.9940, "river": "Punpun",       "district": "Jehanabad"},
    {"city": "Makhdumpur",        "state": "Bihar", "lat": 25.0820, "lon": 84.9120, "river": "Punpun",       "district": "Jehanabad"},
    {"city": "Ghoshi",            "state": "Bihar", "lat": 25.1620, "lon": 85.0820, "river": "Punpun",       "district": "Jehanabad"},

    # ── 8. Bhojpur ────────────────────────────────────────────────────────
    {"city": "Ara",               "state": "Bihar", "lat": 25.5561, "lon": 84.6615, "river": "Ganga",        "district": "Bhojpur"},
    {"city": "Jagdishpur",        "state": "Bihar", "lat": 25.4620, "lon": 84.4320, "river": "Son",          "district": "Bhojpur"},
    {"city": "Piro",              "state": "Bihar", "lat": 25.5720, "lon": 84.3920, "river": "Son",          "district": "Bhojpur"},
    {"city": "Sandesh",           "state": "Bihar", "lat": 25.5620, "lon": 84.5120, "river": "Son",          "district": "Bhojpur"},

    # ── 9. Buxar ──────────────────────────────────────────────────────────
    {"city": "Buxar",             "state": "Bihar", "lat": 25.5690, "lon": 83.9820, "river": "Ganga",        "district": "Buxar"},
    {"city": "Dumraon",           "state": "Bihar", "lat": 25.5420, "lon": 84.1420, "river": "Ganga",        "district": "Buxar"},
    {"city": "Brahmpur",          "state": "Bihar", "lat": 25.5920, "lon": 83.8720, "river": "Ganga",        "district": "Buxar"},
    {"city": "Chausa",            "state": "Bihar", "lat": 25.5220, "lon": 83.8920, "river": "Ganga",        "district": "Buxar"},

    # ── 10. Rohtas ────────────────────────────────────────────────────────
    {"city": "Sasaram",           "state": "Bihar", "lat": 24.9468, "lon": 84.0266, "river": "Son",          "district": "Rohtas"},
    {"city": "Dehri",             "state": "Bihar", "lat": 24.9020, "lon": 84.1820, "river": "Son",          "district": "Rohtas"},
    {"city": "Bikramganj",        "state": "Bihar", "lat": 25.0720, "lon": 84.2520, "river": "Son",          "district": "Rohtas"},
    {"city": "Nokha",             "state": "Bihar", "lat": 24.8920, "lon": 83.9220, "river": "Son",          "district": "Rohtas"},

    # ── 11. Kaimur ────────────────────────────────────────────────────────
    {"city": "Bhabua",            "state": "Bihar", "lat": 25.0392, "lon": 83.6073, "river": "Son",          "district": "Kaimur"},
    {"city": "Mohania",           "state": "Bihar", "lat": 25.1420, "lon": 83.6420, "river": "Son",          "district": "Kaimur"},
    {"city": "Ramgarh",           "state": "Bihar", "lat": 24.9620, "lon": 83.8220, "river": "Son",          "district": "Kaimur"},

    # ── 12. Saran ─────────────────────────────────────────────────────────
    {"city": "Chhapra",           "state": "Bihar", "lat": 25.7837, "lon": 84.7476, "river": "Ghaghra",      "district": "Saran"},
    {"city": "Sonepur",           "state": "Bihar", "lat": 25.7120, "lon": 85.1820, "river": "Gandak",       "district": "Saran"},
    {"city": "Vijay Ghat Bridge", "state": "Bihar", "lat": 25.9400, "lon": 84.7300, "river": "Gandak",       "district": "Saran"},
    {"city": "Revelganj",         "state": "Bihar", "lat": 25.7820, "lon": 84.6420, "river": "Ghaghra",      "district": "Saran"},
    {"city": "Manjhi",            "state": "Bihar", "lat": 25.9120, "lon": 84.8620, "river": "Ghaghra",      "district": "Saran"},

    # ── 13. Siwan ─────────────────────────────────────────────────────────
    {"city": "Siwan",             "state": "Bihar", "lat": 26.2240, "lon": 84.3590, "river": "Ghaghra",      "district": "Siwan"},
    {"city": "Mairwa",            "state": "Bihar", "lat": 26.2120, "lon": 84.1820, "river": "Ghaghra",      "district": "Siwan"},
    {"city": "Maharajganj",       "state": "Bihar", "lat": 26.1020, "lon": 84.5020, "river": "Ghaghra",      "district": "Siwan"},

    # ── 14. Gopalganj ─────────────────────────────────────────────────────
    {"city": "Gopalganj",         "state": "Bihar", "lat": 26.4676, "lon": 84.4372, "river": "Gandak",       "district": "Gopalganj"},
    {"city": "Basantpur",         "state": "Bihar", "lat": 26.1330, "lon": 84.3670, "river": "Gandak",       "district": "Gopalganj"},
    {"city": "Dumri",             "state": "Bihar", "lat": 26.5600, "lon": 84.4800, "river": "Gandak",       "district": "Gopalganj"},
    {"city": "Hathua",            "state": "Bihar", "lat": 26.3620, "lon": 84.4220, "river": "Gandak",       "district": "Gopalganj"},
    {"city": "Kuchaikot",         "state": "Bihar", "lat": 26.5220, "lon": 84.5020, "river": "Gandak",       "district": "Gopalganj"},

    # ── 15. West Champaran ────────────────────────────────────────────────
    {"city": "Bettiah",           "state": "Bihar", "lat": 26.8023, "lon": 84.5034, "river": "Gandak",       "district": "West Champaran"},
    {"city": "Bagaha",            "state": "Bihar", "lat": 27.1022, "lon": 84.0787, "river": "Gandak",       "district": "West Champaran"},
    {"city": "Baluwaha Bridge",   "state": "Bihar", "lat": 27.1000, "lon": 84.3500, "river": "Gandak",       "district": "West Champaran"},
    {"city": "Narkatiaganj",      "state": "Bihar", "lat": 27.0920, "lon": 84.4720, "river": "Gandak",       "district": "West Champaran"},
    {"city": "Ramnagar",          "state": "Bihar", "lat": 27.0320, "lon": 84.3520, "river": "Gandak",       "district": "West Champaran"},
    {"city": "Lauriya",           "state": "Bihar", "lat": 26.9920, "lon": 84.3920, "river": "Gandak",       "district": "West Champaran"},
    {"city": "Gaunaha",           "state": "Bihar", "lat": 27.1720, "lon": 84.5820, "river": "Gandak",       "district": "West Champaran"},

    # ── 16. East Champaran ────────────────────────────────────────────────
    {"city": "Motihari",          "state": "Bihar", "lat": 26.6567, "lon": 84.9130, "river": "Burhi Gandak",  "district": "East Champaran"},
    {"city": "Raxaul",            "state": "Bihar", "lat": 26.9742, "lon": 84.9271, "river": "Lalbakeia",    "district": "East Champaran"},
    {"city": "Chatia",            "state": "Bihar", "lat": 26.3500, "lon": 85.1500, "river": "Burhi Gandak",  "district": "East Champaran"},
    {"city": "Khadda",            "state": "Bihar", "lat": 26.2500, "lon": 84.4200, "river": "Gandak",       "district": "East Champaran"},
    {"city": "Adapur",            "state": "Bihar", "lat": 26.7720, "lon": 84.7720, "river": "Burhi Gandak",  "district": "East Champaran"},
    {"city": "Kesaria",           "state": "Bihar", "lat": 26.3020, "lon": 84.8620, "river": "Burhi Gandak",  "district": "East Champaran"},
    {"city": "Areraj",            "state": "Bihar", "lat": 26.8020, "lon": 84.8820, "river": "Burhi Gandak",  "district": "East Champaran"},
    {"city": "Chakia",            "state": "Bihar", "lat": 26.8820, "lon": 85.0220, "river": "Burhi Gandak",  "district": "East Champaran"},

    # ── 17. Muzaffarpur ───────────────────────────────────────────────────
    {"city": "Muzaffarpur",       "state": "Bihar", "lat": 26.1209, "lon": 85.3647, "river": "Burhi Gandak",  "district": "Muzaffarpur"},
    {"city": "Benibad",           "state": "Bihar", "lat": 26.1110, "lon": 85.8680, "river": "Bagmati",      "district": "Muzaffarpur"},
    {"city": "Ekmighat",          "state": "Bihar", "lat": 26.3800, "lon": 85.7600, "river": "Bagmati",      "district": "Muzaffarpur"},
    {"city": "Kanti",             "state": "Bihar", "lat": 26.3420, "lon": 85.4020, "river": "Burhi Gandak",  "district": "Muzaffarpur"},
    {"city": "Bochaha",           "state": "Bihar", "lat": 26.0120, "lon": 85.6120, "river": "Bagmati",      "district": "Muzaffarpur"},
    {"city": "Minapur",           "state": "Bihar", "lat": 26.2120, "lon": 85.2120, "river": "Burhi Gandak",  "district": "Muzaffarpur"},
    {"city": "Gaighat",           "state": "Bihar", "lat": 26.0620, "lon": 85.7820, "river": "Bagmati",      "district": "Muzaffarpur"},

    # ── 18. Vaishali ──────────────────────────────────────────────────────
    {"city": "Hajipur",           "state": "Bihar", "lat": 25.6868, "lon": 85.2088, "river": "Gandak",       "district": "Vaishali"},
    {"city": "Vaishali",          "state": "Bihar", "lat": 25.6893, "lon": 85.1271, "river": "Gandak",       "district": "Vaishali"},
    {"city": "Lalganj",           "state": "Bihar", "lat": 25.8700, "lon": 85.2200, "river": "Gandak",       "district": "Vaishali"},
    {"city": "Mahua",             "state": "Bihar", "lat": 25.7120, "lon": 85.4620, "river": "Gandak",       "district": "Vaishali"},
    {"city": "Raghopur",          "state": "Bihar", "lat": 25.6220, "lon": 85.2820, "river": "Gandak",       "district": "Vaishali"},

    # ── 19. Sitamarhi ─────────────────────────────────────────────────────
    {"city": "Sitamarhi",         "state": "Bihar", "lat": 26.5922, "lon": 85.4849, "river": "Bagmati",      "district": "Sitamarhi"},
    {"city": "Dheng Bridge",      "state": "Bihar", "lat": 26.0110, "lon": 85.5390, "river": "Bagmati",      "district": "Sitamarhi"},
    {"city": "Sonakhan",          "state": "Bihar", "lat": 26.5500, "lon": 85.4500, "river": "Bagmati",      "district": "Sitamarhi"},
    {"city": "Dubbadhar",         "state": "Bihar", "lat": 26.5200, "lon": 85.0700, "river": "Bagmati",      "district": "Sitamarhi"},
    {"city": "Kansar",            "state": "Bihar", "lat": 26.4700, "lon": 85.5300, "river": "Bagmati",      "district": "Sitamarhi"},
    {"city": "Runisaidpur",       "state": "Bihar", "lat": 26.3950, "lon": 85.6600, "river": "Bagmati",      "district": "Sitamarhi"},
    {"city": "Kothram",           "state": "Bihar", "lat": 26.6500, "lon": 85.7000, "river": "Bagmati",      "district": "Sitamarhi"},
    {"city": "Jhawa",             "state": "Bihar", "lat": 26.6000, "lon": 85.6200, "river": "Bagmati",      "district": "Sitamarhi"},
    {"city": "Belsand",           "state": "Bihar", "lat": 26.4020, "lon": 85.3220, "river": "Bagmati",      "district": "Sitamarhi"},
    {"city": "Pupri",             "state": "Bihar", "lat": 26.4720, "lon": 85.7020, "river": "Bagmati",      "district": "Sitamarhi"},

    # ── 20. Sheohar ───────────────────────────────────────────────────────
    {"city": "Sheohar",           "state": "Bihar", "lat": 26.5178, "lon": 85.2968, "river": "Bagmati",      "district": "Sheohar"},
    {"city": "Piprahi",           "state": "Bihar", "lat": 26.5520, "lon": 85.3520, "river": "Bagmati",      "district": "Sheohar"},

    # ── 21. Darbhanga ─────────────────────────────────────────────────────
    {"city": "Darbhanga",         "state": "Bihar", "lat": 26.1542, "lon": 85.8918, "river": "Bagmati",      "district": "Darbhanga"},
    {"city": "Hayaghat",          "state": "Bihar", "lat": 26.2320, "lon": 86.0810, "river": "Kamla Balan",  "district": "Darbhanga"},
    {"city": "Kamtaul",           "state": "Bihar", "lat": 26.3100, "lon": 86.0500, "river": "Kamla Balan",  "district": "Darbhanga"},
    {"city": "Benipur",           "state": "Bihar", "lat": 26.1020, "lon": 85.9820, "river": "Bagmati",      "district": "Darbhanga"},
    {"city": "Singhwara",         "state": "Bihar", "lat": 26.2620, "lon": 85.7820, "river": "Bagmati",      "district": "Darbhanga"},
    {"city": "Keoti",             "state": "Bihar", "lat": 26.2820, "lon": 86.1220, "river": "Kamla Balan",  "district": "Darbhanga"},

    # ── 22. Madhubani ─────────────────────────────────────────────────────
    {"city": "Madhubani",         "state": "Bihar", "lat": 26.3531, "lon": 86.0715, "river": "Kamla Balan",  "district": "Madhubani"},
    {"city": "Jhanjharpur",       "state": "Bihar", "lat": 26.2638, "lon": 86.2779, "river": "Kamla Balan",  "district": "Madhubani"},
    {"city": "Dagmara",           "state": "Bihar", "lat": 26.4200, "lon": 86.5700, "river": "Kamla Balan",  "district": "Madhubani"},
    {"city": "Laukaha",           "state": "Bihar", "lat": 26.4000, "lon": 86.0900, "river": "Kamla Balan",  "district": "Madhubani"},
    {"city": "Phulparas",         "state": "Bihar", "lat": 26.4500, "lon": 86.3800, "river": "Kamla Balan",  "district": "Madhubani"},
    {"city": "Jainagar",          "state": "Bihar", "lat": 26.5960, "lon": 86.2310, "river": "Kamla Balan",  "district": "Madhubani"},
    {"city": "Benipatti",         "state": "Bihar", "lat": 26.4220, "lon": 86.1820, "river": "Kamla Balan",  "district": "Madhubani"},
    {"city": "Pandaul",           "state": "Bihar", "lat": 26.2120, "lon": 86.0220, "river": "Kamla Balan",  "district": "Madhubani"},

    # ── 23. Supaul ────────────────────────────────────────────────────────
    {"city": "Supaul",            "state": "Bihar", "lat": 26.1233, "lon": 86.6051, "river": "Kosi",         "district": "Supaul"},
    {"city": "Birpur",            "state": "Bihar", "lat": 26.5101, "lon": 87.0301, "river": "Kosi",         "district": "Supaul"},
    {"city": "Dumariaghat",       "state": "Bihar", "lat": 26.5840, "lon": 86.7380, "river": "Kosi",         "district": "Supaul"},
    {"city": "Chatra Bazar",      "state": "Bihar", "lat": 26.7900, "lon": 87.1000, "river": "Kosi",         "district": "Supaul"},
    {"city": "Rajabas",           "state": "Bihar", "lat": 26.6800, "lon": 86.9800, "river": "Kosi",         "district": "Supaul"},
    {"city": "Barahkshetra",      "state": "Bihar", "lat": 26.8300, "lon": 87.1200, "river": "Kosi",         "district": "Supaul"},
    {"city": "Triveniganj",       "state": "Bihar", "lat": 26.1620, "lon": 86.7820, "river": "Kosi",         "district": "Supaul"},
    {"city": "Pipra",             "state": "Bihar", "lat": 26.3120, "lon": 86.8620, "river": "Kosi",         "district": "Supaul"},

    # ── 24. Saharsa ───────────────────────────────────────────────────────
    {"city": "Saharsa",           "state": "Bihar", "lat": 25.8780, "lon": 86.5960, "river": "Kosi",         "district": "Saharsa"},
    {"city": "Kosi Mahasetu",     "state": "Bihar", "lat": 25.9600, "lon": 86.9600, "river": "Kosi",         "district": "Saharsa"},
    {"city": "Basua",             "state": "Bihar", "lat": 25.8000, "lon": 87.0500, "river": "Kosi",         "district": "Saharsa"},
    {"city": "Simri Bakhtiyarpur","state": "Bihar", "lat": 25.7320, "lon": 86.5920, "river": "Kosi",         "district": "Saharsa"},
    {"city": "Sour Bazar",        "state": "Bihar", "lat": 25.8920, "lon": 86.8120, "river": "Kosi",         "district": "Saharsa"},

    # ── 25. Madhepura ─────────────────────────────────────────────────────
    {"city": "Madhepura",         "state": "Bihar", "lat": 25.9189, "lon": 86.7930, "river": "Kosi",         "district": "Madhepura"},
    {"city": "Murliganj",         "state": "Bihar", "lat": 25.9020, "lon": 87.0620, "river": "Kosi",         "district": "Madhepura"},
    {"city": "Udakishanganj",     "state": "Bihar", "lat": 25.9820, "lon": 87.1320, "river": "Kosi",         "district": "Madhepura"},
    {"city": "Bihariganj",        "state": "Bihar", "lat": 25.7320, "lon": 86.9820, "river": "Kosi",         "district": "Madhepura"},
    {"city": "Shankarpur",        "state": "Bihar", "lat": 25.9620, "lon": 86.8620, "river": "Kosi",         "district": "Madhepura"},

    # ── 26. Purnia ────────────────────────────────────────────────────────
    {"city": "Purnia",            "state": "Bihar", "lat": 25.7771, "lon": 87.4753, "river": "Kosi",         "district": "Purnia"},
    {"city": "Dhengraghat",       "state": "Bihar", "lat": 25.7780, "lon": 87.4760, "river": "Mahananda",    "district": "Purnia"},
    {"city": "Banmankhi",         "state": "Bihar", "lat": 25.8820, "lon": 87.1920, "river": "Kosi",         "district": "Purnia"},
    {"city": "Kasba",             "state": "Bihar", "lat": 25.8220, "lon": 87.5020, "river": "Mahananda",    "district": "Purnia"},
    {"city": "Rupauli",           "state": "Bihar", "lat": 25.8520, "lon": 87.3820, "river": "Kosi",         "district": "Purnia"},
    {"city": "Dhamdaha",          "state": "Bihar", "lat": 25.9520, "lon": 87.4120, "river": "Mahananda",    "district": "Purnia"},

    # ── 27. Araria ────────────────────────────────────────────────────────
    {"city": "Araria",            "state": "Bihar", "lat": 26.1495, "lon": 87.4717, "river": "Kosi",         "district": "Araria"},
    {"city": "Forbesganj",        "state": "Bihar", "lat": 26.3020, "lon": 87.2620, "river": "Kosi",         "district": "Araria"},
    {"city": "Jokihat",           "state": "Bihar", "lat": 26.2120, "lon": 87.5620, "river": "Kosi",         "district": "Araria"},
    {"city": "Narpatganj",        "state": "Bihar", "lat": 26.2720, "lon": 87.3820, "river": "Kosi",         "district": "Araria"},
    {"city": "Palasi",            "state": "Bihar", "lat": 26.0720, "lon": 87.3320, "river": "Kosi",         "district": "Araria"},

    # ── 28. Kishanganj ────────────────────────────────────────────────────
    {"city": "Kishanganj",        "state": "Bihar", "lat": 26.0942, "lon": 87.9445, "river": "Mahananda",    "district": "Kishanganj"},
    {"city": "Thakurganj",        "state": "Bihar", "lat": 26.4120, "lon": 88.1920, "river": "Mahananda",    "district": "Kishanganj"},
    {"city": "Bahadurganj",       "state": "Bihar", "lat": 26.2620, "lon": 88.0820, "river": "Mahananda",    "district": "Kishanganj"},
    {"city": "Pothia",            "state": "Bihar", "lat": 26.0520, "lon": 87.8520, "river": "Mahananda",    "district": "Kishanganj"},

    # ── 29. Katihar ───────────────────────────────────────────────────────
    {"city": "Katihar",           "state": "Bihar", "lat": 25.5392, "lon": 87.5752, "river": "Ganga",        "district": "Katihar"},
    {"city": "Kursela",           "state": "Bihar", "lat": 25.4530, "lon": 87.2630, "river": "Kosi",         "district": "Katihar"},
    {"city": "Manihari",          "state": "Bihar", "lat": 25.4060, "lon": 87.6210, "river": "Ganga",        "district": "Katihar"},
    {"city": "Mansi",             "state": "Bihar", "lat": 25.5420, "lon": 86.5720, "river": "Kosi",         "district": "Katihar"},
    {"city": "Barsoi",            "state": "Bihar", "lat": 25.4620, "lon": 87.6620, "river": "Ganga",        "district": "Katihar"},

    # ── 30. Bhagalpur ─────────────────────────────────────────────────────
    {"city": "Bhagalpur",         "state": "Bihar", "lat": 25.2425, "lon": 86.9842, "river": "Ganga",        "district": "Bhagalpur"},
    {"city": "Kahalgaon",         "state": "Bihar", "lat": 25.2410, "lon": 87.2730, "river": "Ganga",        "district": "Bhagalpur"},
    {"city": "Pirpainti",         "state": "Bihar", "lat": 25.2220, "lon": 87.4520, "river": "Ganga",        "district": "Bhagalpur"},
    {"city": "Sultanganj",        "state": "Bihar", "lat": 25.2520, "lon": 86.7320, "river": "Ganga",        "district": "Bhagalpur"},
    {"city": "Sabour",            "state": "Bihar", "lat": 25.2520, "lon": 87.0420, "river": "Ganga",        "district": "Bhagalpur"},
    {"city": "Naugachia",         "state": "Bihar", "lat": 25.3920, "lon": 87.0920, "river": "Ganga",        "district": "Bhagalpur"},

    # ── 31. Banka ─────────────────────────────────────────────────────────
    {"city": "Banka",             "state": "Bihar", "lat": 24.8795, "lon": 86.9218, "river": "Chandan",      "district": "Banka"},
    {"city": "Amarpur",           "state": "Bihar", "lat": 25.0320, "lon": 86.9020, "river": "Chandan",      "district": "Banka"},
    {"city": "Belhar",            "state": "Bihar", "lat": 24.9120, "lon": 87.0820, "river": "Chandan",      "district": "Banka"},
    {"city": "Katoria",           "state": "Bihar", "lat": 24.7620, "lon": 87.0220, "river": "Chandan",      "district": "Banka"},

    # ── 32. Munger ────────────────────────────────────────────────────────
    {"city": "Munger",            "state": "Bihar", "lat": 25.3760, "lon": 86.4730, "river": "Ganga",        "district": "Munger"},
    {"city": "Jamalpur",          "state": "Bihar", "lat": 25.3120, "lon": 86.4920, "river": "Ganga",        "district": "Munger"},
    {"city": "Kharagpur",         "state": "Bihar", "lat": 25.1820, "lon": 86.3320, "river": "Ganga",        "district": "Munger"},
    {"city": "Tarapur",           "state": "Bihar", "lat": 25.2320, "lon": 86.5520, "river": "Ganga",        "district": "Munger"},

    # ── 33. Lakhisarai ────────────────────────────────────────────────────
    {"city": "Lakhisarai",        "state": "Bihar", "lat": 25.1590, "lon": 86.0940, "river": "Ganga",        "district": "Lakhisarai"},
    {"city": "Hathidah",          "state": "Bihar", "lat": 25.3690, "lon": 85.7880, "river": "Ganga",        "district": "Lakhisarai"},
    {"city": "Surajgarha",        "state": "Bihar", "lat": 25.2320, "lon": 86.1820, "river": "Ganga",        "district": "Lakhisarai"},
    {"city": "Barahiya",          "state": "Bihar", "lat": 25.2820, "lon": 85.9520, "river": "Ganga",        "district": "Lakhisarai"},

    # ── 34. Sheikhpura ────────────────────────────────────────────────────
    {"city": "Sheikhpura",        "state": "Bihar", "lat": 25.1396, "lon": 85.8468, "river": "Harohar",      "district": "Sheikhpura"},
    {"city": "Barbigha",          "state": "Bihar", "lat": 25.1920, "lon": 85.7320, "river": "Harohar",      "district": "Sheikhpura"},

    # ── 35. Begusarai ─────────────────────────────────────────────────────
    {"city": "Begusarai",         "state": "Bihar", "lat": 25.4182, "lon": 86.1272, "river": "Ganga",        "district": "Begusarai"},
    {"city": "Baltara",           "state": "Bihar", "lat": 25.7600, "lon": 85.8700, "river": "Burhi Gandak",  "district": "Begusarai"},
    {"city": "Barauni",           "state": "Bihar", "lat": 25.4820, "lon": 85.9720, "river": "Ganga",        "district": "Begusarai"},
    {"city": "Teghra",            "state": "Bihar", "lat": 25.4920, "lon": 85.8420, "river": "Ganga",        "district": "Begusarai"},
    {"city": "Cheriya Bariyarpur","state": "Bihar", "lat": 25.5120, "lon": 86.0820, "river": "Ganga",        "district": "Begusarai"},

    # ── 36. Samastipur ────────────────────────────────────────────────────
    {"city": "Samastipur",        "state": "Bihar", "lat": 25.8593, "lon": 85.7813, "river": "Burhi Gandak",  "district": "Samastipur"},
    {"city": "Rosera",            "state": "Bihar", "lat": 25.8660, "lon": 86.0110, "river": "Burhi Gandak",  "district": "Samastipur"},
    {"city": "Dalsingsarai",      "state": "Bihar", "lat": 25.6720, "lon": 85.8320, "river": "Burhi Gandak",  "district": "Samastipur"},
    {"city": "Morwa",             "state": "Bihar", "lat": 25.7820, "lon": 85.5820, "river": "Burhi Gandak",  "district": "Samastipur"},
    {"city": "Shivajinagar",      "state": "Bihar", "lat": 25.8220, "lon": 85.9220, "river": "Burhi Gandak",  "district": "Samastipur"},
    {"city": "Patori",            "state": "Bihar", "lat": 25.9620, "lon": 85.7820, "river": "Burhi Gandak",  "district": "Samastipur"},

    # ── 37. Khagaria ──────────────────────────────────────────────────────
    {"city": "Khagaria",          "state": "Bihar", "lat": 25.5016, "lon": 86.4614, "river": "Kosi",         "district": "Khagaria"},
    {"city": "Rewaghat",          "state": "Bihar", "lat": 25.6500, "lon": 87.0400, "river": "Kosi",         "district": "Khagaria"},
    {"city": "Mansi",             "state": "Bihar", "lat": 25.5420, "lon": 86.5720, "river": "Kosi",         "district": "Khagaria"},
    {"city": "Gogri",             "state": "Bihar", "lat": 25.4120, "lon": 86.5920, "river": "Kosi",         "district": "Khagaria"},
    {"city": "Alauli",            "state": "Bihar", "lat": 25.4520, "lon": 86.5020, "river": "Kosi",         "district": "Khagaria"},

    # ── 38. Jamui ─────────────────────────────────────────────────────────
    {"city": "Jamui",             "state": "Bihar", "lat": 24.9230, "lon": 86.2230, "river": "Ulai",         "district": "Jamui"},
    {"city": "Jhajha",            "state": "Bihar", "lat": 24.7720, "lon": 86.3720, "river": "Ulai",         "district": "Jamui"},
    {"city": "Sikandra",          "state": "Bihar", "lat": 24.8620, "lon": 86.1820, "river": "Ulai",         "district": "Jamui"},
    {"city": "Chakai",            "state": "Bihar", "lat": 24.7020, "lon": 86.1520, "river": "Ulai",         "district": "Jamui"},

    # ══════════════════════════════════════════════════════════════════════
    # REST OF INDIA
    # ══════════════════════════════════════════════════════════════════════

    # Maharashtra
    {"city": "Kolhapur",           "state": "Maharashtra",       "lat": 16.70, "lon": 74.24, "river": "Panchganga"},
    {"city": "Pune",               "state": "Maharashtra",       "lat": 18.52, "lon": 73.85, "river": "Mutha"},
    {"city": "Nashik",             "state": "Maharashtra",       "lat": 19.99, "lon": 73.79, "river": "Godavari"},
    {"city": "Nagpur",             "state": "Maharashtra",       "lat": 21.15, "lon": 79.09, "river": "Nag"},
    {"city": "Sangli",             "state": "Maharashtra",       "lat": 16.86, "lon": 74.57, "river": "Krishna"},
    {"city": "Satara",             "state": "Maharashtra",       "lat": 17.68, "lon": 74.00, "river": "Krishna"},
    # West Bengal
    {"city": "Kolkata",            "state": "West Bengal",       "lat": 22.57, "lon": 88.36, "river": "Hooghly"},
    {"city": "Howrah",             "state": "West Bengal",       "lat": 22.59, "lon": 88.31, "river": "Hooghly"},
    {"city": "Jalpaiguri",         "state": "West Bengal",       "lat": 26.54, "lon": 88.72, "river": "Teesta"},
    {"city": "Malda",              "state": "West Bengal",       "lat": 25.01, "lon": 88.14, "river": "Ganga"},
    {"city": "Murshidabad",        "state": "West Bengal",       "lat": 24.18, "lon": 88.27, "river": "Bhagirathi"},
    # Assam
    {"city": "Guwahati",           "state": "Assam",             "lat": 26.14, "lon": 91.74, "river": "Brahmaputra"},
    {"city": "Dibrugarh",          "state": "Assam",             "lat": 27.48, "lon": 94.91, "river": "Brahmaputra"},
    {"city": "Tezpur",             "state": "Assam",             "lat": 26.63, "lon": 92.80, "river": "Brahmaputra"},
    {"city": "Dhubri",             "state": "Assam",             "lat": 26.02, "lon": 89.98, "river": "Brahmaputra"},
    {"city": "Barpeta",            "state": "Assam",             "lat": 26.32, "lon": 91.01, "river": "Beki"},
    {"city": "Jorhat",             "state": "Assam",             "lat": 26.75, "lon": 94.21, "river": "Brahmaputra"},
    # Uttar Pradesh
    {"city": "Lucknow",            "state": "Uttar Pradesh",     "lat": 26.85, "lon": 80.95, "river": "Gomti"},
    {"city": "Varanasi",           "state": "Uttar Pradesh",     "lat": 25.32, "lon": 83.01, "river": "Ganga"},
    {"city": "Allahabad",          "state": "Uttar Pradesh",     "lat": 25.44, "lon": 81.84, "river": "Ganga"},
    {"city": "Kanpur",             "state": "Uttar Pradesh",     "lat": 26.46, "lon": 80.33, "river": "Ganga"},
    {"city": "Gorakhpur",          "state": "Uttar Pradesh",     "lat": 26.76, "lon": 83.37, "river": "Rapti"},
    {"city": "Agra",               "state": "Uttar Pradesh",     "lat": 27.18, "lon": 78.01, "river": "Yamuna"},
    # Odisha
    {"city": "Cuttack",            "state": "Odisha",            "lat": 20.46, "lon": 85.88, "river": "Mahanadi"},
    {"city": "Bhubaneswar",        "state": "Odisha",            "lat": 20.30, "lon": 85.82, "river": "Daya"},
    {"city": "Sambalpur",          "state": "Odisha",            "lat": 21.47, "lon": 83.97, "river": "Mahanadi"},
    {"city": "Puri",               "state": "Odisha",            "lat": 19.81, "lon": 85.83, "river": "Bhargavi"},
    {"city": "Kendrapara",         "state": "Odisha",            "lat": 20.50, "lon": 86.42, "river": "Brahmani"},
    # Kerala
    {"city": "Kochi",              "state": "Kerala",            "lat":  9.93, "lon": 76.26, "river": "Periyar"},
    {"city": "Thiruvananthapuram", "state": "Kerala",            "lat":  8.52, "lon": 76.94, "river": "Karamana"},
    {"city": "Thrissur",           "state": "Kerala",            "lat": 10.52, "lon": 76.21, "river": "Chalakudy"},
    {"city": "Kozhikode",          "state": "Kerala",            "lat": 11.25, "lon": 75.78, "river": "Kallai"},
    {"city": "Alappuzha",          "state": "Kerala",            "lat":  9.49, "lon": 76.33, "river": "Pamba"},
    # Andhra Pradesh
    {"city": "Rajahmundry",        "state": "Andhra Pradesh",    "lat": 17.00, "lon": 81.78, "river": "Godavari"},
    {"city": "Vijayawada",         "state": "Andhra Pradesh",    "lat": 16.51, "lon": 80.64, "river": "Krishna"},
    {"city": "Kurnool",            "state": "Andhra Pradesh",    "lat": 15.83, "lon": 78.04, "river": "Tungabhadra"},
    # Telangana
    {"city": "Hyderabad",          "state": "Telangana",         "lat": 17.38, "lon": 78.49, "river": "Musi"},
    {"city": "Khammam",            "state": "Telangana",         "lat": 17.25, "lon": 80.15, "river": "Munneru"},
    {"city": "Warangal",           "state": "Telangana",         "lat": 17.97, "lon": 79.60, "river": "Warangal"},
    # Tamil Nadu
    {"city": "Chennai",            "state": "Tamil Nadu",        "lat": 13.08, "lon": 80.27, "river": "Adyar"},
    {"city": "Madurai",            "state": "Tamil Nadu",        "lat":  9.93, "lon": 78.12, "river": "Vaigai"},
    {"city": "Tiruchirapalli",     "state": "Tamil Nadu",        "lat": 10.79, "lon": 78.70, "river": "Cauvery"},
    {"city": "Cuddalore",          "state": "Tamil Nadu",        "lat": 11.75, "lon": 79.77, "river": "Gadilam"},
    {"city": "Thanjavur",          "state": "Tamil Nadu",        "lat": 10.79, "lon": 79.14, "river": "Cauvery"},
    # Karnataka
    {"city": "Bengaluru",          "state": "Karnataka",         "lat": 12.97, "lon": 77.59, "river": "Arkavathi"},
    {"city": "Belagavi",           "state": "Karnataka",         "lat": 15.86, "lon": 74.50, "river": "Ghataprabha"},
    {"city": "Mysuru",             "state": "Karnataka",         "lat": 12.30, "lon": 76.65, "river": "Kabini"},
    {"city": "Raichur",            "state": "Karnataka",         "lat": 16.20, "lon": 77.36, "river": "Krishna"},
    # Gujarat
    {"city": "Ahmedabad",          "state": "Gujarat",           "lat": 23.03, "lon": 72.57, "river": "Sabarmati"},
    {"city": "Vadodara",           "state": "Gujarat",           "lat": 22.30, "lon": 73.20, "river": "Vishwamitri"},
    {"city": "Surat",              "state": "Gujarat",           "lat": 21.17, "lon": 72.83, "river": "Tapi"},
    # Madhya Pradesh
    {"city": "Jabalpur",           "state": "Madhya Pradesh",    "lat": 23.18, "lon": 79.94, "river": "Narmada"},
    {"city": "Bhopal",             "state": "Madhya Pradesh",    "lat": 23.26, "lon": 77.41, "river": "Betwa"},
    {"city": "Hoshangabad",        "state": "Madhya Pradesh",    "lat": 22.75, "lon": 77.72, "river": "Narmada"},
    # Rajasthan
    {"city": "Jaipur",             "state": "Rajasthan",         "lat": 26.91, "lon": 75.79, "river": "Banas"},
    {"city": "Kota",               "state": "Rajasthan",         "lat": 25.18, "lon": 75.84, "river": "Chambal"},
    # Delhi
    {"city": "Delhi",              "state": "Delhi",             "lat": 28.61, "lon": 77.23, "river": "Yamuna"},
    # Uttarakhand
    {"city": "Dehradun",           "state": "Uttarakhand",       "lat": 30.32, "lon": 78.03, "river": "Rispana"},
    {"city": "Haridwar",           "state": "Uttarakhand",       "lat": 29.95, "lon": 78.16, "river": "Ganga"},
    # Punjab
    {"city": "Jalandhar",          "state": "Punjab",            "lat": 31.33, "lon": 75.58, "river": "Beas"},
    {"city": "Ludhiana",           "state": "Punjab",            "lat": 30.90, "lon": 75.85, "river": "Sutlej"},
    # Haryana
    {"city": "Ambala",             "state": "Haryana",           "lat": 30.38, "lon": 76.78, "river": "Tangri"},
    {"city": "Hisar",              "state": "Haryana",           "lat": 29.15, "lon": 75.72, "river": "Ghaggar"},
    # Chhattisgarh
    {"city": "Raipur",             "state": "Chhattisgarh",      "lat": 21.25, "lon": 81.63, "river": "Kharun"},
    {"city": "Bilaspur",           "state": "Chhattisgarh",      "lat": 22.09, "lon": 82.14, "river": "Arpa"},
    {"city": "Jagdalpur",          "state": "Chhattisgarh",      "lat": 19.07, "lon": 82.03, "river": "Indravati"},
    # Jharkhand
    {"city": "Ranchi",             "state": "Jharkhand",         "lat": 23.34, "lon": 85.31, "river": "Subarnarekha"},
    {"city": "Jamshedpur",         "state": "Jharkhand",         "lat": 22.80, "lon": 86.19, "river": "Subarnarekha"},
    # Northeast
    {"city": "Shillong",           "state": "Meghalaya",         "lat": 25.57, "lon": 91.88, "river": "Umiam"},
    {"city": "Guwahati",           "state": "Assam",             "lat": 26.14, "lon": 91.74, "river": "Brahmaputra"},
    {"city": "Imphal",             "state": "Manipur",           "lat": 24.82, "lon": 93.95, "river": "Imphal"},
    {"city": "Agartala",           "state": "Tripura",           "lat": 23.83, "lon": 91.28, "river": "Haora"},
    {"city": "Gangtok",            "state": "Sikkim",            "lat": 27.33, "lon": 88.62, "river": "Teesta"},
    # J&K / HP
    {"city": "Srinagar",           "state": "Jammu and Kashmir", "lat": 34.08, "lon": 74.80, "river": "Jhelum"},
    {"city": "Jammu",              "state": "Jammu and Kashmir", "lat": 32.73, "lon": 74.87, "river": "Tawi"},
    {"city": "Mandi",              "state": "Himachal Pradesh",  "lat": 31.71, "lon": 76.93, "river": "Beas"},
]


# ─────────────────────────────────────────────────────────────────────────────
# GLOBAL CACHE
# ─────────────────────────────────────────────────────────────────────────────
CACHE_TTL_SECONDS = int(os.getenv("CWC_CACHE_TTL_SECONDS", "1200"))  # 20 min
CWC_PROXY_URL    = os.getenv("CWC_PROXY_URL", "").rstrip("/")

_cache_lock       = threading.Lock()
_cached_stations: List[Dict[str, Any]] = []
_cache_fetched_at: Optional[datetime.datetime] = None
_cache_source: str = "NONE"


def _cache_valid() -> bool:
    if not _cached_stations or _cache_fetched_at is None:
        return False
    return (datetime.datetime.now() - _cache_fetched_at).total_seconds() < CACHE_TTL_SECONDS


def _update_cache(stations: List[Dict[str, Any]], source: str) -> None:
    global _cached_stations, _cache_fetched_at, _cache_source
    with _cache_lock:
        _cached_stations   = stations
        _cache_fetched_at  = datetime.datetime.now()
        _cache_source      = source
    print(f"✅ Cache updated: {len(stations)} stations from {source}")


# ─────────────────────────────────────────────────────────────────────────────
# Open-Meteo GloFAS Flood API — no IP block, works from any server
# ─────────────────────────────────────────────────────────────────────────────
OPEN_METEO_URL = "https://flood-api.open-meteo.com/v1/flood"


def _fetch_city_flood(city_info: Dict[str, Any]) -> Optional[Dict[str, Any]]:
    """Fetch GloFAS river discharge for a single city."""
    try:
        url = (
            f"{OPEN_METEO_URL}?latitude={city_info['lat']}&longitude={city_info['lon']}"
            f"&daily=river_discharge&past_days=2&forecast_days=3"
        )
        resp = requests.get(url, timeout=(5, 12))
        resp.raise_for_status()
        data  = resp.json()
        daily = data.get("daily", {})
        times     = daily.get("time", [])
        discharge = daily.get("river_discharge", [])
        if not discharge:
            return None

        today_str = datetime.date.today().isoformat()
        idx = 0
        for i, t in enumerate(times):
            if t == today_str:
                idx = i
                break

        current_q = discharge[idx] if idx < len(discharge) else discharge[-1]
        if current_q is None:
            return None
        current_q = round(float(current_q), 2)

        trend = "STEADY"
        if idx > 0 and discharge[idx - 1] is not None:
            prev = float(discharge[idx - 1])
            if current_q > prev * 1.05:
                trend = "RISING"
            elif current_q < prev * 0.95:
                trend = "FALLING"

        river_level = round((current_q / 50) ** 0.6, 2)

        state_nm     = city_info["state"]
        state_entry  = get_state_severity_entry(state_nm)
        danger_level = float(state_entry["danger_level_m"])
        warn_level   = round(danger_level * 0.75, 2)

        return {
            "station":             city_info["city"],
            "city":                city_info["city"],
            # ── FIX: always set BOTH state and state_name ──
            "state":               state_nm,
            "state_name":          state_nm,
            "river":               city_info["river"],
            "district":            city_info.get("district", ""),
            "river_level":         river_level,
            "river_discharge_m3s": current_q,
            "warning_level":       warn_level,
            "danger_level":        danger_level,
            "flow_rate":           current_q,
            "rainfall_last_hour":  0.0,
            "status":              _status_from_levels(river_level, warn_level, danger_level),
            "trend":               trend,
            "source":              "OPEN_METEO_GLOFAS",
            "last_update":         datetime.datetime.now().isoformat(),
            "lat":                 city_info["lat"],
            "lon":                 city_info["lon"],
        }
    except Exception as e:
        print(f"⚠️  Open-Meteo failed for {city_info['city']}: {e}")
        return None


def _fetch_open_meteo_all() -> List[Dict[str, Any]]:
    """Fetch GloFAS data for all cities in parallel."""
    stations = []
    with ThreadPoolExecutor(max_workers=20) as ex:
        futures = {ex.submit(_fetch_city_flood, c): c for c in CITY_COORDS}
        for fut in as_completed(futures):
            result = fut.result()
            if result:
                stations.append(result)
    bihar_count = sum(1 for s in stations if s.get("state") == "Bihar")
    print(f"🌏 Open-Meteo GloFAS: {len(stations)}/{len(CITY_COORDS)} cities | Bihar: {bihar_count}")
    return stations


# ─────────────────────────────────────────────────────────────────────────────
# CACHE WARM-UP
# ─────────────────────────────────────────────────────────────────────────────
def warm_cache() -> str:
    stations = _fetch_open_meteo_all()
    if stations:
        _update_cache(stations, "OPEN_METEO_GLOFAS")
        return "OPEN_METEO_GLOFAS"
    print("⚠️  Open-Meteo failed — falling back to TACTICAL_REGISTRY")
    return "TACTICAL"


def _ensure_cache() -> None:
    if _cache_valid():
        return
    if not _cached_stations:
        warm_cache()
    else:
        threading.Thread(target=warm_cache, daemon=True).start()


# ─────────────────────────────────────────────────────────────────────────────
# HELPERS
# ─────────────────────────────────────────────────────────────────────────────
def _safe_float(value, default: float = 0.0) -> float:
    try:
        if value is None or value == "":
            return default
        return float(value)
    except (TypeError, ValueError):
        return default


def _status_from_levels(current: float, warning: float, danger: float) -> str:
    if danger > 0 and current >= danger:
        return "CRITICAL"
    if warning > 0 and current >= warning:
        return "WARNING"
    return "ACTIVE"


def _normalize_key(value) -> str:
    key = (value or "").strip().lower()
    key = " ".join(key.split())
    if key == "orissa":                    return "odisha"
    if key in {"nct of delhi", "new delhi"}: return "delhi"
    if key == "uttaranchal":               return "uttarakhand"
    return key


def _hash_value(s: str) -> int:
    h = 0
    for c in s:
        h = (h << 5) - h + ord(c)
        h |= 0
    return abs(h)


def _seeded_unit(seed: str) -> float:
    return (_hash_value(seed) % 1000) / 1000


# ─────────────────────────────────────────────────────────────────────────────
# TACTICAL FALLBACK
# ─────────────────────────────────────────────────────────────────────────────
def _build_tactical_telemetry(
    state_name: str = "Maharashtra",
    station_name: str = "Kolhapur",
    limit: int = 6,
) -> List[Dict[str, Any]]:
    state_entry = get_state_severity_entry(state_name)
    clean_state = (state_name or "Active Region").strip() or "Active Region"
    preferred_station = (station_name or "").strip() or f"{clean_state} Central Gauge"
    danger_level = float(state_entry["danger_level_m"])
    primary_warning   = round(max(danger_level - 1.4, danger_level * 0.86), 2)
    secondary_danger  = round(max(danger_level - 0.4, primary_warning + 0.7), 2)
    secondary_warning = round(max(primary_warning - 0.6, 0.6), 2)
    tertiary_danger   = round(max(danger_level - 1.1, secondary_warning + 0.8), 2)
    tertiary_warning  = round(max(primary_warning - 1.2, 0.5), 2)
    profiles = [
        {"station": preferred_station,            "river": f"{clean_state} Primary Basin",    "warning_level": primary_warning,   "danger_level": round(danger_level, 2)},
        {"station": f"{clean_state} Downstream", "river": f"{clean_state} Downstream Reach", "warning_level": secondary_warning, "danger_level": secondary_danger},
        {"station": f"{clean_state} Catchment",  "river": f"{clean_state} Catchment Basin",  "warning_level": tertiary_warning,  "danger_level": tertiary_danger},
    ]
    state_key   = _normalize_key(state_name) or "active-region"
    station_key = _normalize_key(station_name)
    time_bucket = int(datetime.datetime.now().timestamp() // (30 * 60))
    telemetry   = []
    for idx, profile in enumerate(profiles[:max(1, limit)]):
        seed    = f"{state_key}|{_normalize_key(profile['station'])}|{time_bucket}|{idx}"
        threat  = _seeded_unit(f"{seed}|threat")
        wl      = float(profile["warning_level"])
        dl      = float(profile["danger_level"])
        current = wl - (0.45 + _seeded_unit(f"{seed}|safe") * 1.55)
        if threat > 0.84:
            current = dl + _seeded_unit(f"{seed}|critical") * 0.45
        elif threat > 0.58:
            current = wl + _seeded_unit(f"{seed}|warning") * max(dl - wl, 0.6)
        current = round(current, 2)
        trend_r = _seeded_unit(f"{seed}|trend")
        trend   = "RISING" if trend_r > 0.66 else "FALLING" if trend_r > 0.33 else "STEADY"
        telemetry.append({
            "station": profile["station"], "state_name": state_name, "state": state_name,
            "river": profile["river"], "river_level": current, "danger_level": dl,
            "warning_level": wl,
            "flow_rate": round(max(current, 0) * (10.8 + _seeded_unit(f"{seed}|flow") * 4.4), 1),
            "rainfall_last_hour": round(_seeded_unit(f"{seed}|rain") * 18, 1),
            "status": _status_from_levels(current, wl, dl), "trend": trend,
            "source": "TACTICAL_REGISTRY",
            "last_update": (datetime.datetime.now() - datetime.timedelta(
                milliseconds=_seeded_unit(f"{seed}|time") * 55 * 60 * 1000)).isoformat(),
        })
    if station_key:
        telemetry.sort(key=lambda s: (
            0 if station_key in _normalize_key(s["station"]) or station_key in _normalize_key(s["river"]) else 1,
            -float(s["river_level"]),
        ))
    return telemetry


# ─────────────────────────────────────────────────────────────────────────────
# CWCRiverScraper — public interface (backward-compatible)
# ─────────────────────────────────────────────────────────────────────────────
class CWCRiverScraper:

    def __init__(self):
        threading.Thread(target=warm_cache, daemon=True).start()

    def get_live_telemetry(
        self,
        state_name:   str = "Maharashtra",
        station_name: str = "Kolhapur",
        limit:        int = 6,
    ) -> Dict[str, Any]:
        _ensure_cache()
        target_state   = _normalize_key(state_name)
        target_station = _normalize_key(station_name)
        with _cache_lock:
            stations = list(_cached_stations)
            source   = _cache_source

        # ── FIX: check BOTH state and state_name fields ──
        matched = [
            s for s in stations
            if target_state in _normalize_key(s.get("state") or "")
            or target_state in _normalize_key(s.get("state_name") or "")
        ]

        if not matched:
            tactical = _build_tactical_telemetry(state_name, station_name, limit)
            return {
                "status": "FALLBACK_MODE", "data_source": "TACTICAL_REGISTRY",
                "error": f"No live data for {state_name} in cache ({source}).",
                "timestamp": datetime.datetime.now().isoformat(), "data": tactical,
            }

        def _rank(s: Dict[str, Any]) -> tuple:
            sn = _normalize_key(s.get("station") or "")
            rv = _normalize_key(s.get("river") or "")
            exact = target_station and (target_station in sn or target_station in rv)
            return (0 if exact else 1, -float(s.get("river_level", 0)))

        matched.sort(key=_rank)
        return {
            "status": "SECURED", "data_source": source,
            "timestamp": datetime.datetime.now().isoformat(),
            "data": matched[:limit],
        }

    def get_live_river_level(self, station_name: str = "Kolhapur") -> Dict[str, Any]:
        _ensure_cache()
        target = _normalize_key(station_name)
        with _cache_lock:
            stations = list(_cached_stations)
        for s in stations:
            sn = _normalize_key(s.get("station") or "")
            if target in sn or sn in target:
                level = s.get("river_level", 0)
                print(f"✅ Live level for {s['station']}: {level}m")
                return {
                    "status": "success", "current_level_m": level,
                    "station": s.get("station"), "river": s.get("river"),
                    "state": s.get("state"), "source": s.get("source", "OPEN_METEO_GLOFAS"),
                }
        return {"status": "error", "error": f"Station '{station_name}' not found in cache"}

    def get_all_stations(self, limit: int = 1000) -> List[Dict[str, Any]]:
        _ensure_cache()
        with _cache_lock:
            return list(_cached_stations)[:limit]

    def get_cache_status(self) -> Dict[str, Any]:
        return {
            "station_count":  len(_cached_stations),
            "source":         _cache_source,
            "fetched_at":     _cache_fetched_at.isoformat() if _cache_fetched_at else None,
            "cache_valid":    _cache_valid(),
            "ttl_seconds":    CACHE_TTL_SECONDS,
            "bihar_count":    sum(1 for s in _cached_stations if s.get("state") == "Bihar"),
            "total_cities":   len(CITY_COORDS),
        }
