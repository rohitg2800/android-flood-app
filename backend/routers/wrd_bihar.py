"""
WRD Bihar Live River Level Router
Scrapes BeFIQR portal (irrigation.befiqr.in) — the official Central Flood
Control Cell, Water Resources Department, Govt of Bihar.

Routes:
  GET /api/wrd-bihar/stations            — all stations (live or fallback)
  GET /api/wrd-bihar/stations/{name}     — single station by name
  GET /api/wrd-bihar/summary             — danger/warning/normal counts + top alerts
  GET /api/wrd-bihar/health              — portal reachability check
  GET /api/wrd-bihar/refresh             — force immediate scrape + cache update
  GET /api/wrd-bihar/scheduler/status    — APScheduler next-run info

AUTO-REFRESH:
  APScheduler runs _scheduled_refresh() every WRD_BIHAR_POLL_INTERVAL_MIN
  minutes (default 15). It only replaces the cache when the portal returns
  fresh data, detected by comparing the newest current_level_m values.

DATA SOURCE: WRD Bihar BeFIQR only.
Live URL: https://irrigation.befiqr.in/state/table/rivers

NOTE on above_below_danger_m:
  BeFIQR scrapes a signed distance column BUT the portal sometimes returns
  unsigned magnitudes. To avoid ambiguity we ALWAYS recompute this field
  as  (current_level_m - danger_level_m)  so the sign is unambiguous:
    negative  → river is BELOW danger level (safe)
    positive  → river is ABOVE danger level (flooding)
"""

from __future__ import annotations

import datetime
import logging
import os
from typing import Any, Dict, List, Optional

import requests
from apscheduler.schedulers.background import BackgroundScheduler
from apscheduler.triggers.interval import IntervalTrigger
from bs4 import BeautifulSoup
from fastapi import APIRouter
from cachetools import TTLCache
try:
    from routers.dependencies import operational_store as _op_store
except Exception:
    _op_store = None

log = logging.getLogger(__name__)

router = APIRouter(prefix="/api/wrd-bihar", tags=["WRD Bihar"])

# ---------------------------------------------------------------------------
# Cache — TTL slightly longer than poll interval so scheduler always owns it
# ---------------------------------------------------------------------------
_POLL_MINUTES: int = int(os.getenv("WRD_BIHAR_POLL_INTERVAL_MIN", "15"))
_CACHE: TTLCache = TTLCache(maxsize=32, ttl=(_POLL_MINUTES + 2) * 60)
_CACHE_KEY = "wrd_bihar_stations_v4"

# Scheduler singleton
_scheduler: Optional[BackgroundScheduler] = None

# ---------------------------------------------------------------------------
# BeFIQR scraper targets
# ---------------------------------------------------------------------------
_WRD_URLS = [
    "https://irrigation.befiqr.in/state/table/rivers",
    "https://irrigation.befiqr.in/state/table/wrd-manual-stations/water-level-obs",
    "http://irrigation.befiqr.in/state/table/rivers",
]

_HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/124.0.0.0 Safari/537.36"
    ),
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
    "Accept-Language": "en-IN,en;q=0.9,hi;q=0.8",
    "Referer": "https://irrigation.befiqr.in/",
}

# ---------------------------------------------------------------------------
# Station registry — WRD Bihar BeFIQR gauge stations
# HFL and danger_level_m are in metres above sea level (ASL).
# ---------------------------------------------------------------------------
_STATION_REGISTRY: List[Dict[str, Any]] = [
    {'station': 'Sundarpur', 'river': 'Adhawara', 'district': 'Sitamarhi/ Sursand', 'danger_level_m': 61.7, 'warning_level_m': 58.3, 'lat': 26.65, 'lon': 85.3513},
    {'station': 'Pupri', 'river': 'Adhawara', 'district': 'Sitamarhi/ Pupri', 'danger_level_m': 55.79, 'warning_level_m': 50.71, 'lat': 26.575, 'lon': 85.4383},
    {'station': 'Mubbi', 'river': 'Adhawara', 'district': 'Darbhanga/ Darbhanga Sadar', 'danger_level_m': 48.0, 'warning_level_m': 45.69, 'lat': 26.1242, 'lon': 85.8288},
    {'station': 'Akbarpur', 'river': 'Awsane', 'district': 'Rohtas/ Rohtas', 'danger_level_m': 103.85, 'warning_level_m': None, 'lat': 25.1343, 'lon': 83.9858},
    {'station': 'Sakhwaghat', 'river': 'Bagmati', 'district': 'Samastipur/ Hasanpur', 'danger_level_m': 40.0, 'warning_level_m': None, 'lat': 26.0064, 'lon': 85.7129},
    {'station': 'Phuhiya Gram', 'river': 'Bagmati', 'district': 'Samastipur/ Bithan', 'danger_level_m': 39.4, 'warning_level_m': 34.85, 'lat': 25.8984, 'lon': 85.6319},
    {'station': 'Phultora Bridge', 'river': 'Bagmati', 'district': 'Samastipur/ Bithan', 'danger_level_m': 39.0, 'warning_level_m': 35.15, 'lat': 25.7424, 'lon': 85.6469},
    {'station': 'Badlaghat South', 'river': 'Bagmati', 'district': 'Khagaria/ Chautham', 'danger_level_m': 37.64, 'warning_level_m': None, 'lat': 25.6104, 'lon': 86.571},
    {'station': 'Badlaghat North', 'river': 'Bagmati', 'district': 'Khagaria/ Chautham', 'danger_level_m': 37.5, 'warning_level_m': None, 'lat': 25.5024, 'lon': 86.568},
    {'station': 'Kataunjha', 'river': 'Bagmati', 'district': 'Muzaffarpur/ Aurai', 'danger_level_m': 56.0, 'warning_level_m': 52.81, 'lat': 26.2109, 'lon': 85.2867},
    {'station': 'Kansar/Chandauli', 'river': 'Bagmati', 'district': 'Sitamarhi/ Belsand', 'danger_level_m': 59.06, 'warning_level_m': 56.18, 'lat': 26.536, 'lon': 85.6243},
    {'station': 'Dubbadhar', 'river': 'Bagmati', 'district': 'Sheohar/ Piprarhi', 'danger_level_m': 61.28, 'warning_level_m': 59.11, 'lat': 26.6271, 'lon': 85.2394},
    {'station': 'Dheng Bridge', 'river': 'Bagmati', 'district': 'Sitamarhi/ Suppi', 'danger_level_m': 71.0, 'warning_level_m': 68.71, 'lat': 26.53, 'lon': 85.3753},
    {'station': 'Sonakhan', 'river': 'Bagmati', 'district': 'Sitamarhi/ Suppi', 'danger_level_m': 68.8, 'warning_level_m': 67.03, 'lat': 26.644, 'lon': 85.4653},
    {'station': 'Taran', 'river': 'Bakra', 'district': 'Araria/ Jokihat', 'danger_level_m': 48.6, 'warning_level_m': 45.4, 'lat': 26.0458, 'lon': 87.3653},
    {'station': 'Chulhai Ghat', 'river': 'Balan', 'district': 'Begusarai/ Bhagwanpur', 'danger_level_m': 38.0, 'warning_level_m': None, 'lat': 25.4872, 'lon': 86.2232},
    {'station': 'Dalsingsarai', 'river': 'Balan', 'district': 'Samastipur/ Dalsingsarai', 'danger_level_m': 41.11, 'warning_level_m': None, 'lat': 26.0004, 'lon': 85.6889},
    {'station': 'Asani', 'river': 'Banas', 'district': 'Bhojpur/ Arrah', 'danger_level_m': 57.0, 'warning_level_m': None, 'lat': 25.4984, 'lon': 84.3502},
    {'station': 'Kathara tand', 'river': 'Barnar', 'district': 'Jamui/ Sono', 'danger_level_m': 156.83, 'warning_level_m': None, 'lat': 24.9283, 'lon': 86.2345},
    {'station': 'Santhua', 'river': 'Batane', 'district': 'Aurangabad/ Aurangabad', 'danger_level_m': 105.95, 'warning_level_m': None, 'lat': 24.8397, 'lon': 84.4853},
    {'station': 'Wazitpur', 'river': 'Baya', 'district': 'Samastipur/ Vidyapati Nagar', 'danger_level_m': 43.3, 'warning_level_m': None, 'lat': 25.7604, 'lon': 85.6619},
    {'station': 'Godia', 'river': 'Baya', 'district': 'Vaishali/ Goraul', 'danger_level_m': 49.0, 'warning_level_m': None, 'lat': 25.6288, 'lon': 85.1704},
    {'station': 'Baya Tatbandh Chain 620', 'river': 'Baya', 'district': 'Samastipur/ Mohiuddinagar', 'danger_level_m': 44.0, 'warning_level_m': 38.52, 'lat': 25.8054, 'lon': 85.8239},
    {'station': 'Diripar', 'river': 'Bhutahi', 'district': 'Nalanda/ Karai Parsurai', 'danger_level_m': 48.75, 'warning_level_m': None, 'lat': 25.238, 'lon': 85.4577},
    {'station': 'Mandakhsa', 'river': 'Bhutahi', 'district': 'Nalanda/ Ekangarsarai', 'danger_level_m': 56.16, 'warning_level_m': None, 'lat': 24.989, 'lon': 85.4457},
    {'station': 'Dumar', 'river': 'Brandi', 'district': 'Katihar/ Korha', 'danger_level_m': 30.61, 'warning_level_m': None, 'lat': 25.428, 'lon': 87.5157},
    {'station': 'Ekma Syphon', 'river': 'Burhi Gandak', 'district': 'Madhubani/ Khutauna', 'danger_level_m': 42.63, 'warning_level_m': 68.59, 'lat': 26.278, 'lon': 86.0296},
    {'station': 'Dadaulghat', 'river': 'Burhi Gandak', 'district': 'Muzaffarpur/ Goraul', 'danger_level_m': 48.25, 'warning_level_m': 42.54, 'lat': 26.1119, 'lon': 85.3737},
    {'station': 'Banka Rail Crosssing (Lakshmipur)', 'river': 'Chandan', 'district': 'Banka/ Banka', 'danger_level_m': 84.01, 'warning_level_m': 80.46, 'lat': 24.9702, 'lon': 86.8306},
    {'station': 'Panjwara', 'river': 'Cheergerua', 'district': 'Banka/ Barahat', 'danger_level_m': 78.32, 'warning_level_m': None, 'lat': 24.9132, 'lon': 87.0106},
    {'station': 'Kariyawa', 'river': 'Chirayn', 'district': 'Nalanda/ Tharthari', 'danger_level_m': 52.67, 'warning_level_m': None, 'lat': 25.223, 'lon': 85.2927},
    {'station': 'Siwan', 'river': 'Daha', 'district': 'Siwan/ Siwan', 'danger_level_m': 63.53, 'warning_level_m': 60.32, 'lat': 26.2894, 'lon': 84.3669},
    {'station': 'Matiyar', 'river': 'Daha', 'district': 'Saran/ Manjhi', 'danger_level_m': 56.0, 'warning_level_m': 51.18, 'lat': 25.841, 'lon': 84.7742},
    {'station': 'Bari bigha', 'river': 'Dardha', 'district': 'Patna/ Dhanarua', 'danger_level_m': 55.02, 'warning_level_m': None, 'lat': 25.6421, 'lon': 85.0416},
    {'station': 'Nimej', 'river': 'Dharmawati', 'district': 'Buxar/ Brahampur', 'danger_level_m': 58.2, 'warning_level_m': 53.77, 'lat': 25.4785, 'lon': 83.9266},
    {'station': 'Kharuara (Harnaut)', 'river': 'Dhoba', 'district': 'Nalanda/ Harnaut', 'danger_level_m': 49.86, 'warning_level_m': None, 'lat': 25.07, 'lon': 85.4817},
    {'station': 'Durgawati Rail Crossing', 'river': 'Durgawati', 'district': 'Kaimur (Bhabua)/ Durgawati', 'danger_level_m': 69.5, 'warning_level_m': None, 'lat': 25.0306, 'lon': 83.5642},
    {'station': 'Chenari', 'river': 'Durgawati', 'district': 'Rohtas/ Chenari', 'danger_level_m': 88.2, 'warning_level_m': 85.1, 'lat': 25.0713, 'lon': 83.9198},
    {'station': 'Mandai', 'river': 'Falgu', 'district': 'Jahanabad/ Modanganj', 'danger_level_m': 61.86, 'warning_level_m': None, 'lat': 25.2213, 'lon': 84.9921},
    {'station': 'Kushaha', 'river': 'Fariyani', 'district': 'Purnia/ Banmankhi', 'danger_level_m': 42.82, 'warning_level_m': 40.48, 'lat': 25.8671, 'lon': 87.5233},
    {'station': 'Hajipur', 'river': 'Gandak', 'district': 'Vaishali/ Hajipur', 'danger_level_m': 50.32, 'warning_level_m': 44.42, 'lat': 25.8448, 'lon': 85.0624},
    {'station': 'Rahimapur', 'river': 'Gandaki', 'district': 'Saran/ Dariapur', 'danger_level_m': 50.95, 'warning_level_m': None, 'lat': 25.91, 'lon': 84.6152},
    {'station': 'Chintamanpur', 'river': 'Gandaki', 'district': 'Saran/ Garkha', 'danger_level_m': 53.0, 'warning_level_m': None, 'lat': 25.829, 'lon': 84.7652},
    {'station': 'Ramayanpur', 'river': 'Ganga', 'district': 'Katihar/ Amdabad', 'danger_level_m': 27.56, 'warning_level_m': 22.75, 'lat': 25.686, 'lon': 87.5487},
    {'station': 'Karhagola ghat', 'river': 'Ganga', 'district': 'Katihar/ Barari', 'danger_level_m': 29.87, 'warning_level_m': 24.9, 'lat': 25.62, 'lon': 87.4587},
    {'station': 'Buxar', 'river': 'Ganga', 'district': 'Buxar/ Buxar', 'danger_level_m': 60.32, 'warning_level_m': 48.88, 'lat': 25.4695, 'lon': 83.8936},
    {'station': 'BKG Embankment 90.52 Km', 'river': 'Ganga', 'district': 'Bhojpur/ Barhara', 'danger_level_m': 53.13, 'warning_level_m': 45.26, 'lat': 25.4444, 'lon': 84.5542},
    {'station': 'Sultanganj', 'river': 'Ganga', 'district': 'Bhagalpur/ Sultanganj', 'danger_level_m': 32.5, 'warning_level_m': 28.09, 'lat': 25.2995, 'lon': 86.8432},
    {'station': 'Dakranala', 'river': 'Ganga', 'district': 'Munger/ Sadar Munger', 'danger_level_m': 37.58, 'warning_level_m': 31.26, 'lat': 25.3316, 'lon': 86.5635},
    {'station': 'Kashtharnighat', 'river': 'Ganga', 'district': 'Munger/ Sadar Munger', 'danger_level_m': 39.33, 'warning_level_m': 30.65, 'lat': 25.3976, 'lon': 86.4495},
    {'station': 'Raghopur', 'river': 'Ganga', 'district': 'Bhagalpur/ Kharik', 'danger_level_m': 32.8, 'warning_level_m': 25.82, 'lat': 25.2965, 'lon': 86.9122},
    {'station': 'Ismailpur Bindtoli', 'river': 'Ganga', 'district': 'Bhagalpur/ Gopalpur', 'danger_level_m': 31.6, 'warning_level_m': 25.13, 'lat': 25.3835, 'lon': 86.8672},
    {'station': 'Jai Chhapra', 'river': 'Ghagra', 'district': 'Saran/ Manjhi', 'danger_level_m': 56.5, 'warning_level_m': None, 'lat': 25.85, 'lon': 84.6992},
    {'station': 'Manjhi Bridge', 'river': 'Ghagra', 'district': 'Saran/ Manjhi', 'danger_level_m': 52.4, 'warning_level_m': None, 'lat': 25.817, 'lon': 84.6122},
    {'station': 'Ghogha Kahalgaon Road Crossing', 'river': 'Ghogha  (Sundar)', 'district': 'Bhagalpur/ Kahalgaon', 'danger_level_m': 28.52, 'warning_level_m': 25.51, 'lat': 25.2005, 'lon': 87.0142},
    {'station': 'Bakrachausua', 'river': 'Goithawa', 'district': 'Nalanda/ Giriyak', 'danger_level_m': 65.86, 'warning_level_m': None, 'lat': 25.028, 'lon': 85.5807},
    {'station': 'Balgudar', 'river': 'Harohar', 'district': 'Lakhisarai/ Lakhisarai', 'danger_level_m': 40.0, 'warning_level_m': 32.71, 'lat': 25.2216, 'lon': 86.076},
    {'station': 'Jamune Bajar', 'river': 'Jamune', 'district': 'Gaya/ Gaya', 'danger_level_m': 94.41, 'warning_level_m': None, 'lat': 24.6594, 'lon': 85.1142},
    {'station': 'Konighat', 'river': 'Jeewachh/ Kamla', 'district': 'Darbhanga/ Biraul', 'danger_level_m': 38.21, 'warning_level_m': None, 'lat': 26.2532, 'lon': 85.8918},
    {'station': 'Derwa', 'river': 'Jharahi', 'district': 'Gopalganj/ Kuchaikot', 'danger_level_m': 70.4, 'warning_level_m': 67.85, 'lat': 26.3851, 'lon': 84.3358},
    {'station': 'Kachahripur', 'river': 'Jhim', 'district': '', 'danger_level_m': 74.5, 'warning_level_m': None, 'lat': 25.6631, 'lon': 85.0926},
    {'station': 'Darjia', 'river': 'Kamala Balan', 'district': 'Darbhanga/ Ghanshyampur', 'danger_level_m': 46.8, 'warning_level_m': 45.8, 'lat': 26.2352, 'lon': 85.7538},
    {'station': 'Rasiyari Pul', 'river': 'Kamala Balan', 'district': 'Darbhanga/ Ghanshyampur', 'danger_level_m': 45.5, 'warning_level_m': 42.84, 'lat': 26.1062, 'lon': 85.8498},
    {'station': 'Kothram', 'river': 'Kamla', 'district': 'Darbhanga/ Gaura Bauram', 'danger_level_m': 44.0, 'warning_level_m': None, 'lat': 26.2682, 'lon': 85.8858},
    {'station': 'Gausaghat', 'river': 'Kamla Dhar', 'district': 'Darbhanga/ Darbhanga Sadar', 'danger_level_m': 49.0, 'warning_level_m': 46.18, 'lat': 26.0492, 'lon': 85.8378},
    {'station': 'Tarabari', 'river': 'Kankai', 'district': 'Kishanganj/ Thakurganj', 'danger_level_m': 48.2, 'warning_level_m': 47.3, 'lat': 26.0832, 'lon': 87.8626},
    {'station': 'Vikramganj Rail Crossing', 'river': 'Kao', 'district': 'Rohtas/ Bikramganj', 'danger_level_m': 86.2, 'warning_level_m': 83.34, 'lat': 25.0653, 'lon': 84.1718},
    {'station': 'Karbandia', 'river': 'Kao', 'district': 'Rohtas/ Sasaram', 'danger_level_m': 106.8, 'warning_level_m': None, 'lat': 24.9543, 'lon': 83.9498},
    {'station': 'Pabheri', 'river': 'Kararua', 'district': 'Patna/ Dhanarua', 'danger_level_m': 52.67, 'warning_level_m': None, 'lat': 25.4891, 'lon': 85.2636},
    {'station': 'Kolhuaghat', 'river': 'Kareh Bagmati', 'district': 'Samastipur/ Shivaji Nagar', 'danger_level_m': 42.2, 'warning_level_m': 37.0, 'lat': 25.9104, 'lon': 85.7489},
    {'station': 'Sonmankhi', 'river': 'Kareh Bagmati', 'district': 'Khagaria/ Khagaria', 'danger_level_m': 36.5, 'warning_level_m': 32.74, 'lat': 25.4844, 'lon': 86.514},
    {'station': 'Kari Kosi Chain 389', 'river': 'Kari Kosi', 'district': 'Katihar/ Mansahi', 'danger_level_m': 28.52, 'warning_level_m': None, 'lat': 25.548, 'lon': 87.4317},
    {'station': 'Kakrait Ghat', 'river': 'Karmnasha', 'district': 'Kaimur (Bhabua)/ Durgawati', 'danger_level_m': 62.3, 'warning_level_m': None, 'lat': 25.1956, 'lon': 83.6662},
    {'station': 'Phulwaria', 'river': 'Khalkhalia', 'district': 'Bhagalpur/ Jagdishpur', 'danger_level_m': 35.6, 'warning_level_m': None, 'lat': 25.2545, 'lon': 86.8402},
    {'station': 'Mohani', 'river': 'Khiroi', 'district': 'Darbhanga/ Bahadurpur', 'danger_level_m': 46.0, 'warning_level_m': None, 'lat': 26.2262, 'lon': 85.8978},
    {'station': 'Agropatti', 'river': 'Khiroi', 'district': 'Sitamarhi/ Pupri', 'danger_level_m': 52.75, 'warning_level_m': 48.93, 'lat': 26.578, 'lon': 85.3423},
    {'station': 'Lakhisarai', 'river': 'Kiul', 'district': 'Lakhisarai/ Lakhisarai', 'danger_level_m': 41.1, 'warning_level_m': 35.7, 'lat': 25.2786, 'lon': 86.031},
    {'station': 'Sahora', 'river': 'Kosi', 'district': 'Bhagalpur/ Rangra Chowk', 'danger_level_m': 31.48, 'warning_level_m': 26.26, 'lat': 25.2545, 'lon': 86.8852},
    {'station': 'Dhamaraghat', 'river': 'Kosi', 'district': 'Khagaria/ Chautham', 'danger_level_m': 38.55, 'warning_level_m': None, 'lat': 25.4094, 'lon': 86.418},
    {'station': 'Dumri Bridge', 'river': 'Kosi', 'district': 'Khagaria/ Beldaur', 'danger_level_m': 33.85, 'warning_level_m': None, 'lat': 25.4634, 'lon': 86.412},
    {'station': 'Ghoghepur', 'river': 'Kosi', 'district': 'Saharsa/ Mahishi', 'danger_level_m': 42.28, 'warning_level_m': None, 'lat': 25.8232, 'lon': 86.5356},
    {'station': 'Kursela', 'river': 'Kosi', 'district': 'Katihar/ Kursela', 'danger_level_m': 30.0, 'warning_level_m': 24.6, 'lat': 25.53, 'lon': 87.5757},
    {'station': 'Khurmabad', 'river': 'Kudra', 'district': 'Kaimur (Bhabua)/ Kudra', 'danger_level_m': 84.0, 'warning_level_m': None, 'lat': 24.9616, 'lon': 83.7142},
    {'station': 'Bahuara', 'river': 'Kudra', 'district': 'Kaimur (Bhabua)/ Kudra', 'danger_level_m': 72.7, 'warning_level_m': 68.9, 'lat': 24.9256, 'lon': 83.4622},
    {'station': 'Borabari', 'river': 'Lakhandei', 'district': 'Muzaffarpur/ Gaighat', 'danger_level_m': 42.0, 'warning_level_m': None, 'lat': 26.0069, 'lon': 85.2207},
    {'station': 'Sitamarhi', 'river': 'Lakhandei', 'district': 'Sitamarhi/ Dumra', 'danger_level_m': 61.0, 'warning_level_m': None, 'lat': 26.503, 'lon': 85.4533},
    {'station': 'Gowabari', 'river': 'Lal Bakeya', 'district': 'Purvi Champaran/ Dhaka', 'danger_level_m': 71.15, 'warning_level_m': 69.0, 'lat': 26.771, 'lon': 84.8608},
    {'station': 'Sohrapur', 'river': 'Lokayin', 'district': 'Nalanda/ Hilsa', 'danger_level_m': 58.1, 'warning_level_m': None, 'lat': 25.193, 'lon': 85.4127},
    {'station': 'Kursail', 'river': 'Mahananda', 'district': 'Katihar/ Kadwa', 'danger_level_m': 31.4, 'warning_level_m': 28.65, 'lat': 25.665, 'lon': 87.4677},
    {'station': 'Baharkhal', 'river': 'Mahananda', 'district': 'Katihar/ Azamnagar', 'danger_level_m': 31.09, 'warning_level_m': 28.0, 'lat': 25.422, 'lon': 87.5427},
    {'station': 'Azamnagar', 'river': 'Mahananda', 'district': 'Katihar/ Azamnagar', 'danger_level_m': 29.87, 'warning_level_m': 26.83, 'lat': 25.635, 'lon': 87.5037},
    {'station': 'Dhabol', 'river': 'Mahananda', 'district': 'Katihar/ Azamnagar', 'danger_level_m': 29.26, 'warning_level_m': 26.09, 'lat': 25.674, 'lon': 87.5577},
    {'station': 'Durgapur', 'river': 'Mahananda', 'district': 'Katihar/ Pranpur', 'danger_level_m': 28.05, 'warning_level_m': 25.63, 'lat': 25.461, 'lon': 87.4407},
    {'station': 'Govindpur', 'river': 'Mahananda', 'district': 'Katihar/ Amdabad', 'danger_level_m': 27.18, 'warning_level_m': 23.18, 'lat': 25.491, 'lon': 87.5547},
    {'station': 'Sheetalpur', 'river': 'Mahi', 'district': 'Saran/ Dariapur', 'danger_level_m': 49.87, 'warning_level_m': None, 'lat': 26.0, 'lon': 84.8552},
    {'station': 'Pirokhar', 'river': 'Maraha', 'district': 'Sitamarhi/ Pupri', 'danger_level_m': 51.2, 'warning_level_m': None, 'lat': 26.728, 'lon': 85.5943},
    {'station': 'Gardankatta East', 'river': 'Mechi East', 'district': 'Kishanganj/ Thakurganj', 'danger_level_m': 59.6, 'warning_level_m': 58.18, 'lat': 25.9842, 'lon': 87.8746},
    {'station': 'Gardankatta West', 'river': 'Mechi West/ Jamuna', 'district': 'Kishanganj/ Thakurganj', 'danger_level_m': 58.4, 'warning_level_m': 55.8, 'lat': 26.0142, 'lon': 87.8416},
    {'station': 'Sirnama', 'river': 'Mohane', 'district': 'Nalanda/ Harnaut', 'danger_level_m': 45.09, 'warning_level_m': None, 'lat': 25.07, 'lon': 85.3137},
    {'station': 'Chandi', 'river': 'Mohane', 'district': 'Nalanda/ Chandi', 'danger_level_m': 52.15, 'warning_level_m': None, 'lat': 25.079, 'lon': 85.5867},
    {'station': 'Belchhi', 'river': 'Mohane', 'district': 'Nalanda/ Chandi', 'danger_level_m': 45.83, 'warning_level_m': None, 'lat': 25.241, 'lon': 85.5027},
    {'station': 'Chhoti Chhariyari', 'river': 'Mohane', 'district': 'Nalanda/ Tharthari', 'danger_level_m': 50.31, 'warning_level_m': None, 'lat': 25.25, 'lon': 85.3887},
    {'station': 'Panchanpur', 'river': 'Morahar', 'district': 'Gaya/ Tekari', 'danger_level_m': 94.4, 'warning_level_m': None, 'lat': 24.6654, 'lon': 85.0512},
    {'station': 'Mahakola (Basa)', 'river': 'Muhani', 'district': 'Munger/ Haveli Kharagpur', 'danger_level_m': 51.1, 'warning_level_m': None, 'lat': 25.4156, 'lon': 86.5335},
    {'station': 'Babhandeeha', 'river': 'Nonai', 'district': 'Nalanda/ Hilsa', 'danger_level_m': 53.98, 'warning_level_m': None, 'lat': 25.238, 'lon': 85.2987},
    {'station': 'Gangmohan Gram', 'river': 'Noon', 'district': 'Samastipur/ Sarairanjan', 'danger_level_m': 40.2, 'warning_level_m': 39.92, 'lat': 25.8804, 'lon': 85.8359},
    {'station': 'Pothiya Pul', 'river': 'Noon Kathane', 'district': 'Samastipur/ Tajpur', 'danger_level_m': 44.0, 'warning_level_m': None, 'lat': 25.8084, 'lon': 85.6859},
    {'station': 'Shahpur-Maricha', 'river': 'Noona', 'district': 'Muzaffarpur/ Kurhani', 'danger_level_m': 50.25, 'warning_level_m': None, 'lat': 25.9859, 'lon': 85.4907},
    {'station': 'Saidabad', 'river': 'Noona', 'district': 'Araria/ Sikti', 'danger_level_m': 58.74, 'warning_level_m': None, 'lat': 26.2798, 'lon': 87.3053},
    {'station': 'Pariyari', 'river': 'Noona', 'district': 'Araria/ Sikti', 'danger_level_m': 57.26, 'warning_level_m': None, 'lat': 26.1748, 'lon': 87.3353},
    {'station': 'Malisadha/ Chhabilapur', 'river': 'Paimar', 'district': 'Nalanda/ Rajgir', 'danger_level_m': 65.86, 'warning_level_m': None, 'lat': 24.998, 'lon': 85.2927},
    {'station': 'Giriyak', 'river': 'Panchane', 'district': 'Nalanda/ Giriyak', 'danger_level_m': 60.5, 'warning_level_m': None, 'lat': 25.241, 'lon': 85.3287},
    {'station': 'Rahimpurganj', 'river': 'Panchane', 'district': 'Nalanda/ Rahui', 'danger_level_m': 51.54, 'warning_level_m': None, 'lat': 25.001, 'lon': 85.5387},
    {'station': 'Rajgir Biharsharif Road Crossing', 'river': 'Panchane', 'district': 'Nalanda/ Biharsharif', 'danger_level_m': 53.9, 'warning_level_m': None, 'lat': 25.115, 'lon': 85.5357},
    {'station': 'Shikarpur', 'river': 'Pandai Nadi', 'district': 'Paschim Champaran/ Narkatiyaganj', 'danger_level_m': 81.7, 'warning_level_m': None, 'lat': 26.612, 'lon': 84.7768},
    {'station': 'Baisi', 'river': 'Parman', 'district': 'Purnia/ Baisi', 'danger_level_m': 36.45, 'warning_level_m': 34.35, 'lat': 25.6751, 'lon': 87.3643},
    {'station': 'Araria', 'river': 'Parman', 'district': 'Araria/ Araria', 'danger_level_m': 47.68, 'warning_level_m': 45.14, 'lat': 26.0488, 'lon': 87.4643},
    {'station': 'Hamidnagar', 'river': 'Punpun', 'district': 'Aurangabad/ Goh', 'danger_level_m': 74.17, 'warning_level_m': None, 'lat': 24.7377, 'lon': 84.4343},
    {'station': 'Kadirganj', 'river': 'Sakri', 'district': 'Nawada/ Nawada', 'danger_level_m': 85.8, 'warning_level_m': None, 'lat': 24.9624, 'lon': 85.436},
    {'station': 'Puara', 'river': 'Sakri', 'district': 'Nawada/ Nawada', 'danger_level_m': 75.98, 'warning_level_m': None, 'lat': 25.0344, 'lon': 85.43},
    {'station': 'Baksoti (Kutarichak)', 'river': 'Sakri', 'district': 'Nawada/ Gobindpur', 'danger_level_m': 109.49, 'warning_level_m': None, 'lat': 24.9624, 'lon': 85.622},
    {'station': 'Jiyarkulti', 'river': 'Sakri', 'district': 'Nalanda/ Asthawan', 'danger_level_m': 56.45, 'warning_level_m': None, 'lat': 25.037, 'lon': 85.4487},
    {'station': 'Shivaghat', 'river': 'Sikrahna', 'district': 'Paschim Champaran/ Chanpatiya', 'danger_level_m': 73.33, 'warning_level_m': None, 'lat': 26.732, 'lon': 84.8038},
    {'station': 'Arwal Sahar Pul', 'river': 'Sone', 'district': 'Bhojpur/ Sahar', 'danger_level_m': 75.87, 'warning_level_m': 65.77, 'lat': 25.6784, 'lon': 84.3682},
    {'station': 'Kadwan/ Matianwa', 'river': 'Sone', 'district': 'Rohtas/ Nauhatta', 'danger_level_m': 140.85, 'warning_level_m': 137.0, 'lat': 24.9393, 'lon': 83.8868},
    {'station': 'Bhagwanpur', 'river': 'Suawara', 'district': 'Kaimur (Bhabua)/ Bhagwanpur', 'danger_level_m': 89.3, 'warning_level_m': 85.6, 'lat': 25.0936, 'lon': 83.5432},
    {'station': 'Sursar', 'river': 'Sursar Dhar', 'district': 'Araria/ Narpatganj', 'danger_level_m': 67.4, 'warning_level_m': 65.35, 'lat': 26.2348, 'lon': 87.5483},
    {'station': 'Uchait', 'river': 'Thomane', 'district': 'Madhubani/ Benipatti', 'danger_level_m': 49.0, 'warning_level_m': None, 'lat': 26.431, 'lon': 85.9276},
    {'station': 'Tilaiya', 'river': 'Tilaiya', 'district': 'Nawada/ Hisua', 'danger_level_m': 91.5, 'warning_level_m': None, 'lat': 24.7374, 'lon': 85.406},
    {'station': 'Litiahi', 'river': 'Tilawe', 'district': 'Supaul/ Pipra', 'danger_level_m': 52.45, 'warning_level_m': 48.75, 'lat': 26.0394, 'lon': 86.6945},
    {'station': 'Tisbhawra Pul', 'river': 'Tisbhawra/ Kamla', 'district': 'Darbhanga/ Darbhanga Sadar', 'danger_level_m': 47.0, 'warning_level_m': None, 'lat': 26.0792, 'lon': 85.9308},
    {'station': 'Garhi', 'river': 'Upper Kiul', 'district': 'Jamui/ Khaira', 'danger_level_m': 167.56, 'warning_level_m': 164.02, 'lat': 24.7903, 'lon': 86.1505},
    {'station': 'Thelwa', 'river': 'Upperbadua', 'district': 'Jamui/ Jhajha', 'danger_level_m': 103.0, 'warning_level_m': 100.2, 'lat': 24.8323, 'lon': 86.1985},
    {'station': 'Bibiganj', 'river': 'West Kankai', 'district': 'Kishanganj/ Terhagachh', 'danger_level_m': 48.8, 'warning_level_m': 47.42, 'lat': 26.2362, 'lon': 87.8056},
    {'station': 'Gosaipur', 'river': 'West Kankai', 'district': 'Kishanganj/ Kochadhaman', 'danger_level_m': 46.94, 'warning_level_m': 44.25, 'lat': 25.9812, 'lon': 88.0276},
    {'station': 'Ekmighat', 'river': 'Adhwara', 'district': 'Darbhanga / Bahadurpur', 'danger_level_m': 46.94, 'warning_level_m': 40.88, 'lat': 26.2292, 'lon': 85.9218},
    {'station': 'Kamtaul', 'river': 'Adhwara', 'district': 'Darbhanga / Jale', 'danger_level_m': 50.0, 'warning_level_m': 46.64, 'lat': 26.2352, 'lon': 85.8078},
    {'station': 'Sonbarsa', 'river': 'Adhwara', 'district': 'Sitamarhi / Sonbarsa', 'danger_level_m': 81.85, 'warning_level_m': 78.71, 'lat': 26.608, 'lon': 85.6303},
    {'station': 'Benibad', 'river': 'Bagmati', 'district': 'Muzaffarpur / Gaighat', 'danger_level_m': 48.68, 'warning_level_m': 46.96, 'lat': 26.1629, 'lon': 85.2687},
    {'station': 'Hayaghat', 'river': 'Bagmati', 'district': 'Darbhanga / Hayaghat', 'danger_level_m': 45.72, 'warning_level_m': 39.77, 'lat': 26.2922, 'lon': 85.8318},
    {'station': 'Khagaria', 'river': 'Burhi Gandak', 'district': 'Khagaria / Khagaria', 'danger_level_m': 36.58, 'warning_level_m': 29.94, 'lat': 25.5984, 'lon': 86.346},
    {'station': 'Rosera', 'river': 'Burhi Gandak', 'district': 'Samastipur / Rosera', 'danger_level_m': 42.63, 'warning_level_m': 36.32, 'lat': 25.9584, 'lon': 85.7279},
    {'station': 'Samastipur', 'river': 'Burhi Gandak', 'district': 'Samastipur / Samastipur', 'danger_level_m': 46.0, 'warning_level_m': 39.34, 'lat': 25.8894, 'lon': 85.7459},
    {'station': 'Sikandarpur (Muzzafarpur)', 'river': 'Burhi Gandak', 'district': 'Muzaffarpur / Musahari', 'danger_level_m': 52.53, 'warning_level_m': 45.39, 'lat': 26.1599, 'lon': 85.3497},
    {'station': 'Chatia', 'river': 'Gandak', 'district': 'East Champaran / Areraj', 'danger_level_m': 69.15, 'warning_level_m': 64.96, 'lat': 26.786, 'lon': 84.8998},
    {'station': 'Dumariaghat', 'river': 'Gandak', 'district': 'Gopalganj / Sidhwalia', 'danger_level_m': 62.22, 'warning_level_m': 60.35, 'lat': 26.5771, 'lon': 84.2998},
    {'station': 'Rewaghat', 'river': 'Gandak', 'district': 'Muzaffarpur / Saraiya', 'danger_level_m': 54.41, 'warning_level_m': 50.98, 'lat': 26.1359, 'lon': 85.2987},
    {'station': 'Bhagalpur', 'river': 'Ganga', 'district': 'Bhagalpur / Nathnagar', 'danger_level_m': 33.68, 'warning_level_m': 25.66, 'lat': 25.1105, 'lon': 86.9602},
    {'station': 'Dighaghat', 'river': 'Ganga', 'district': 'Patna / Patna Rural', 'danger_level_m': 50.45, 'warning_level_m': 42.9, 'lat': 25.6871, 'lon': 85.0866},
    {'station': 'Gandhighat', 'river': 'Ganga', 'district': 'Patna / Patna Rural', 'danger_level_m': 48.6, 'warning_level_m': 42.45, 'lat': 25.6001, 'lon': 85.2846},
    {'station': 'Hathidah', 'river': 'Ganga', 'district': 'Patna / Mokameh', 'danger_level_m': 41.76, 'warning_level_m': 34.87, 'lat': 25.5701, 'lon': 85.1916},
    {'station': 'Kahalgaon', 'river': 'Ganga', 'district': 'Bhagalpur / Gopalpur', 'danger_level_m': 31.09, 'warning_level_m': 24.72, 'lat': 25.1255, 'lon': 86.9362},
    {'station': 'Munger', 'river': 'Ganga', 'district': 'Munger / Sadar Munger', 'danger_level_m': 39.33, 'warning_level_m': 30.65, 'lat': 25.4306, 'lon': 86.4495},
    {'station': 'Darauli', 'river': 'Ghaghra', 'district': 'Siwan / Darauli', 'danger_level_m': 60.82, 'warning_level_m': 56.17, 'lat': 26.0794, 'lon': 84.2919},
    {'station': 'Gangpur Siswan', 'river': 'Ghaghra', 'district': 'Siwan / Siswan', 'danger_level_m': 57.04, 'warning_level_m': 51.91, 'lat': 26.2594, 'lon': 84.3339},
    {'station': 'Jhanjharpur', 'river': 'Kamalabalan', 'district': 'Madhubani / Jhanjharpur', 'danger_level_m': 50.0, 'warning_level_m': 48.9, 'lat': 26.395, 'lon': 85.9546},
    {'station': 'Jainagar', 'river': 'Kamla', 'district': 'Madhubani / Jainagar', 'danger_level_m': 67.75, 'warning_level_m': 66.62, 'lat': 26.257, 'lon': 86.0716},
    {'station': 'Baltara', 'river': 'Kosi', 'district': 'Khagaria / Beldaur', 'danger_level_m': 33.85, 'warning_level_m': 32.07, 'lat': 25.5144, 'lon': 86.388},
    {'station': 'Basua', 'river': 'Kosi', 'district': 'Supaul / Supaul', 'danger_level_m': 47.75, 'warning_level_m': 46.43, 'lat': 26.2254, 'lon': 86.6255},
    {'station': 'Dhengraghat', 'river': 'Mahananda', 'district': 'Purnia / Baisi', 'danger_level_m': 35.65, 'warning_level_m': 34.07, 'lat': 25.6571, 'lon': 87.4333},
    {'station': 'Taibpur', 'river': 'Mahananda', 'district': 'Kishanganj / Thakurganj', 'danger_level_m': 66.0, 'warning_level_m': 64.29, 'lat': 26.1582, 'lon': 87.9436},
    {'station': 'Sripalpur', 'river': 'Punpun', 'district': 'Patna / Phulwari', 'danger_level_m': 50.6, 'warning_level_m': 44.87, 'lat': 25.4771, 'lon': 85.0446},
    {'station': 'Birpur', 'river': 'Kosi', 'district': 'Supaul / Birpur', 'danger_level_m': 58.32, 'warning_level_m': 55.52, 'lat': 26.51, 'lon': 86.91},
]

_REGISTRY_MAP: Dict[str, Dict[str, Any]] = {
    " ".join(s["station"].lower().split()): s for s in _STATION_REGISTRY
}


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _now_iso() -> str:
    return datetime.datetime.now(datetime.timezone.utc).isoformat()


def _normalize(value: str) -> str:
    return " ".join((value or "").strip().lower().split())


def _safe_float(value: Any) -> Optional[float]:
    """Parse float from scraped cell. Returns None for missing/invalid."""
    try:
        v = str(value).strip().replace(",", "")
        if v in ("", "--", "N/A", "NA", "-", ".", "nil", "NIL"):
            return None
        return round(float(v), 3)
    except (ValueError, TypeError):
        return None


def _enrich(station_name: str) -> Dict[str, Any]:
    key = _normalize(station_name)
    if key in _REGISTRY_MAP:
        return _REGISTRY_MAP[key]
    for rk, rv in _REGISTRY_MAP.items():
        if rk in key or key in rk:
            return rv
    # No match — warn so new BeFIQR stations surface immediately in logs
    log.warning(
        "[WRD Bihar] Unmatched station '%s' — not in _STATION_REGISTRY. "
        "Add it with correct lat/lon/hfl/danger_level_m to get accurate data.",
        station_name,
    )
    return {"station": station_name, "river": "Unknown", "district": "Bihar",
            "hfl": None, "danger_level_m": None, "lat": 25.8, "lon": 85.4}


def _status_label(
    current: Optional[float],
    danger: Optional[float],
    hfl: Optional[float],
    above_dl: Optional[float],
) -> str:
    """
    Status derived from signed above_dl (current - danger level):
      CRITICAL  — above danger AND near/above HFL
      DANGER    — at or above danger level
      WARNING   — within 3 m below danger level
      NORMAL    — more than 3 m below danger level
      UNKNOWN   — no current reading
    """
    if current is None or above_dl is None:
        return "UNKNOWN"
    if above_dl >= 0:
        return "CRITICAL" if (hfl and current >= hfl * 0.97) else "DANGER"
    if above_dl >= -3.0:
        return "WARNING"
    if current > 0:
        return "NORMAL"
    return "UNKNOWN"


# ---------------------------------------------------------------------------
# BeFIQR table parser
# Column order (0-indexed): 0=SL 1=River 2=Site 3=HFL 4=DL 5=Yest
#                           6=Current 7=Diff24h 8=AboveBelowDL 9=Trend 10=District
# ---------------------------------------------------------------------------
_BEFIQR_COL = {"river": 1, "site": 2, "hfl": 3, "dl": 4, "yest": 5,
               "current": 6, "diff": 7, "above": 8, "trend": 9, "dist": 10}


def _parse_befiqr_table(soup: BeautifulSoup) -> List[Dict[str, Any]]:
    stations: List[Dict[str, Any]] = []
    now = _now_iso()

    for table in soup.find_all("table"):
        rows = table.find_all("tr")
        if len(rows) < 3:
            continue
        all_text = table.get_text(" ", strip=True).lower()
        if not any(k in all_text for k in ["river", "site", "hfl", "danger"]):
            continue

        header_cells: List[str] = []
        for hr in rows[:3]:
            cells = [c.get_text(" ", strip=True).lower() for c in hr.find_all(["th", "td"])]
            if len(cells) > len(header_cells):
                header_cells = cells

        def col_idx(keywords: List[str], default: int) -> int:
            for kw in keywords:
                for i, h in enumerate(header_cells):
                    if kw in h:
                        return i
            return default

        i_river   = col_idx(["river", "nadi"],                       _BEFIQR_COL["river"])
        i_site    = col_idx(["site", "station", "gauge"],            _BEFIQR_COL["site"])
        i_hfl     = col_idx(["hfl"],                                 _BEFIQR_COL["hfl"])
        i_dl      = col_idx(["dl", "danger level", "danger"],       _BEFIQR_COL["dl"])
        i_yest    = col_idx(["yesterday", "previous", "yest"],       _BEFIQR_COL["yest"])
        i_current = col_idx(["current observed", "current wl",
                             "current level", "observed wl"],        _BEFIQR_COL["current"])
        i_diff    = col_idx(["diff", "24", "change"],                _BEFIQR_COL["diff"])
        i_trend   = col_idx(["trend", "today"],                      _BEFIQR_COL["trend"])
        i_dist    = col_idx(["district", "block"],                   _BEFIQR_COL["dist"])

        for row in rows[1:]:
            cells = [td.get_text(" ", strip=True) for td in row.find_all("td")]
            if len(cells) < 5:
                continue

            def c(idx: int) -> str:
                return cells[idx].strip() if 0 <= idx < len(cells) else ""

            site = c(i_site)
            if not site or site.lower() in ("site", "station", "sl", "#", "(3)", "",
                                            "river", "hfl (mts)", "dl (mts)"):
                continue

            river    = c(i_river)
            hfl      = _safe_float(c(i_hfl))
            dl       = _safe_float(c(i_dl))
            yest     = _safe_float(c(i_yest))
            current  = _safe_float(c(i_current))
            diff_24h = _safe_float(c(i_diff))
            trend    = c(i_trend) or "—"
            district = c(i_dist)

            meta = _enrich(site)
            if not river:    river    = meta.get("river", "Unknown")
            if not district: district = meta.get("district", "Bihar")
            if hfl is None:  hfl      = meta.get("hfl")
            if dl is None:   dl       = meta.get("danger_level_m")

            # ----------------------------------------------------------------
            # above_below_danger_m: ALWAYS computed as (current - danger_level)
            # negative = river BELOW danger level (safe)
            # positive = river ABOVE danger level (flooding!)
            # ----------------------------------------------------------------
            above_dl: Optional[float] = None
            if current is not None and dl is not None and dl > 0:
                above_dl = round(current - dl, 3)

            stations.append({
                "station":              site,
                "river":                river,
                "district":             district,
                "lat":                  meta.get("lat", 25.8),
                "lon":                  meta.get("lon", 85.4),
                "hfl_m":                hfl,
                "danger_level_m":       dl,
                "yesterday_level_m":    yest,
                "current_level_m":      current,
                "change_24h_m":         diff_24h,
                "above_below_danger_m": above_dl,
                "trend":                trend,
                "status":               _status_label(current, dl, hfl, above_dl),
                "source":               "WRD_BIHAR_BEFIQR",
                "last_update":          now,
            })

        if stations:
            break

    return stations


# ---------------------------------------------------------------------------
# Live fetch
# ---------------------------------------------------------------------------

def _fetch_befiqr_live() -> Dict[str, Any]:
    errors: List[str] = []
    timeout = (
        max(3.0, float(os.getenv("WRD_BIHAR_CONNECT_TIMEOUT", "6"))),
        max(8.0, float(os.getenv("WRD_BIHAR_READ_TIMEOUT", "20"))),
    )
    for url in _WRD_URLS:
        try:
            resp = requests.get(url, headers=_HEADERS, timeout=timeout)
            resp.raise_for_status()
            soup = BeautifulSoup(resp.text, "html.parser")
            stations = _parse_befiqr_table(soup)
            if stations:
                return {
                    "status": "LIVE",
                    "data_source": "WRD_BIHAR_BEFIQR",
                    "source_url": url,
                    "station_count": len(stations),
                    "timestamp": _now_iso(),
                    "stations": stations,
                }
            errors.append(f"{url}: page loaded (HTTP {resp.status_code}) but no table rows extracted")
        except requests.Timeout:
            errors.append(f"{url}: timeout")
        except requests.RequestException as exc:
            errors.append(f"{url}: {exc.__class__.__name__} — {str(exc)[:140]}")
    raise RuntimeError(" | ".join(errors))


# ---------------------------------------------------------------------------
# Fallback
# ---------------------------------------------------------------------------

def _tactical_fallback(scrape_error: str = "") -> Dict[str, Any]:
    now = _now_iso()
    stations = [{
        "station":              s["station"],
        "river":                s["river"],
        "district":             s["district"],
        "lat":                  s["lat"],
        "lon":                  s["lon"],
        "hfl_m":                s["hfl"],
        "danger_level_m":       s["danger_level_m"],
        "yesterday_level_m":    None,
        "current_level_m":      None,
        "change_24h_m":         None,
        "above_below_danger_m": None,
        "trend":                "—",
        "status":               "UNKNOWN",
        "source":               "WRD_BIHAR_FALLBACK",
        "last_update":          now,
    } for s in _STATION_REGISTRY]
    result = {
        "status": "FALLBACK",
        "data_source": "WRD_BIHAR_FALLBACK",
        "source_url": None,
        "station_count": len(stations),
        "timestamp": now,
        "stations": stations,
    }
    if scrape_error:
        result["_scrape_error"] = scrape_error[:500]
    return result


# ---------------------------------------------------------------------------
# Shared getter (used by all route handlers)
# ---------------------------------------------------------------------------

async def _get_stations(force_refresh: bool = False) -> Dict[str, Any]:
    if not force_refresh and _CACHE_KEY in _CACHE:
        cached = dict(_CACHE[_CACHE_KEY])
        cached["_cache_hit"] = True
        return cached
    try:
        result = _fetch_befiqr_live()
        _CACHE[_CACHE_KEY] = result
        result = dict(result)
        result["_cache_hit"] = False
        return result
    except RuntimeError as exc:
        fallback = _tactical_fallback(str(exc))
        fallback["_cache_hit"] = False
        return fallback


# ---------------------------------------------------------------------------
# APScheduler — background auto-refresh
# ---------------------------------------------------------------------------

def _scheduled_refresh() -> None:
    log.info("[WRD Bihar] Scheduled refresh started")
    try:
        fresh = _fetch_befiqr_live()
        new_levels = {s["station"]: s["current_level_m"] for s in fresh["stations"]}
        old_result = _CACHE.get(_CACHE_KEY)
        if old_result:
            old_levels = {s["station"]: s["current_level_m"] for s in old_result["stations"]}
            if new_levels == old_levels:
                log.info("[WRD Bihar] Portal not yet updated — cache kept (levels unchanged)")
                return
            log.info("[WRD Bihar] Portal data changed — updating cache")
        else:
            log.info("[WRD Bihar] Cache was empty — populating")
        _CACHE[_CACHE_KEY] = fresh
        log.info(f"[WRD Bihar] Cache refreshed: {fresh['station_count']} stations at {fresh['timestamp']}")
        # Save to Neon DB
        try:
            if _op_store and hasattr(_op_store, 'save_station_snapshot'):
                saved = _op_store.save_station_snapshot(fresh.get('stations', []))
                log.info(f"[WRD Bihar] Saved {saved} station snapshots to DB")
                # Save flood alerts for elevated stations
                for s in fresh.get('stations', []):
                    if s.get('status') in ('WARNING', 'DANGER', 'CRITICAL'):
                        _op_store.save_flood_alert({
                            'station':       s.get('station'),
                            'river':         s.get('river'),
                            'district':      s.get('district'),
                            'severity':      s.get('status'),
                            'level_m':       s.get('current_level_m'),
                            'danger_level_m': s.get('danger_level_m'),
                            'alert_type':    'THRESHOLD',
                            'message':       f"{s.get('station')} at {s.get('current_level_m')}m — {s.get('status')}",
                        })
        except Exception as db_exc:
            log.warning(f"[WRD Bihar] DB save failed (non-fatal): {db_exc}")
    except RuntimeError as exc:
        log.warning(f"[WRD Bihar] Scheduled refresh failed: {exc}")


@router.get("/api/wrd-bihar/history/{station}")
async def get_station_history(station: str, limit: int = 100):
    """GET station level history from Neon DB."""
    try:
        from routers.dependencies import operational_store
        rows = operational_store.list_station_snapshots(station=station, limit=limit)
        return {"station": station, "count": len(rows), "history": rows}
    except Exception as e:
        return {"error": str(e), "history": []}


@router.get("/api/wrd-bihar/flood-alerts")
async def get_flood_alerts(active_only: bool = True):
    """GET flood alerts from Neon DB."""
    try:
        from routers.dependencies import operational_store
        rows = operational_store.list_flood_alerts(active_only=active_only)
        return {"count": len(rows), "alerts": rows}
    except Exception as e:
        return {"error": str(e), "alerts": []}


def start_scheduler() -> None:
    global _scheduler
    if _scheduler and _scheduler.running:
        return
    _scheduler = BackgroundScheduler(timezone="Asia/Kolkata", daemon=True)
    _scheduler.add_job(
        _scheduled_refresh,
        trigger=IntervalTrigger(minutes=_POLL_MINUTES),
        id="wrd_bihar_refresh",
        name=f"WRD Bihar BeFIQR scrape every {_POLL_MINUTES} min",
        replace_existing=True,
        max_instances=1,
        misfire_grace_time=120,
    )
    _scheduler.start()
    log.info(f"[WRD Bihar] Scheduler started — polling every {_POLL_MINUTES} min (IST)")


def stop_scheduler() -> None:
    global _scheduler
    if _scheduler and _scheduler.running:
        _scheduler.shutdown(wait=False)
        log.info("[WRD Bihar] Scheduler stopped")


# ---------------------------------------------------------------------------
# Routes
# ---------------------------------------------------------------------------

@router.get("/stations")
async def get_wrd_bihar_stations(
    force_refresh: bool = False,
    river: Optional[str] = None,
    district: Optional[str] = None,
) -> Dict[str, Any]:
    """All WRD Bihar stations. Filters: ?river=Ganga ?district=Patna ?force_refresh=true"""
    result = await _get_stations(force_refresh=force_refresh)
    stations = result.get("stations", [])
    if river:
        rk = _normalize(river)
        stations = [s for s in stations if rk in _normalize(s.get("river", ""))]
    if district:
        dk = _normalize(district)
        stations = [s for s in stations if dk in _normalize(s.get("district", ""))]
    return {**result, "station_count": len(stations), "stations": stations}


@router.get("/stations/{station_name}")
async def get_wrd_bihar_station(station_name: str, force_refresh: bool = False) -> Dict[str, Any]:
    """Single station by name (case-insensitive partial match)."""
    all_data = await _get_stations(force_refresh=force_refresh)
    key = _normalize(station_name)
    matches = [
        s for s in all_data.get("stations", [])
        if key in _normalize(s.get("station", "")) or _normalize(s.get("station", "")) in key
    ]
    if not matches:
        return {"status": "NOT_FOUND", "data_source": all_data["data_source"],
                "timestamp": all_data["timestamp"], "query": station_name, "station": None}
    return {"status": all_data["status"], "data_source": all_data["data_source"],
            "timestamp": all_data["timestamp"], "station": matches[0]}


@router.get("/summary")
async def get_wrd_bihar_summary(force_refresh: bool = False) -> Dict[str, Any]:
    """Bihar flood summary — alert level, counts, top 5 alerts."""
    all_data = await _get_stations(force_refresh=force_refresh)
    stations = all_data.get("stations", [])

    counts: Dict[str, int] = {"CRITICAL": 0, "DANGER": 0, "WARNING": 0, "NORMAL": 0, "UNKNOWN": 0}
    alert_stations: List[Dict[str, Any]] = []

    for s in stations:
        status = s.get("status", "UNKNOWN")
        counts[status] = counts.get(status, 0) + 1
        current = s.get("current_level_m")
        dl = s.get("danger_level_m")
        if current is not None and dl and dl > 0:
            alert_stations.append({**s, "_pct": round(current / dl * 100, 1)})

    alert_stations.sort(key=lambda x: x["_pct"], reverse=True)

    if counts["CRITICAL"] > 0:  state_alert = "RED"
    elif counts["DANGER"] > 0:  state_alert = "ORANGE"
    elif counts["WARNING"] > 0: state_alert = "YELLOW"
    elif counts["NORMAL"] > 0:  state_alert = "GREEN"
    else:                        state_alert = "GREY"

    return {
        "status":            all_data["status"],
        "data_source":       all_data["data_source"],
        "timestamp":         all_data["timestamp"],
        "state":             "Bihar",
        "total_stations":    len(stations),
        "state_alert_level": state_alert,
        "station_counts":    counts,
        "top_alerts": [
            {"station": s["station"], "river": s["river"], "district": s["district"],
             "current_level_m": s["current_level_m"], "danger_level_m": s["danger_level_m"],
             "above_below_danger_m": s.get("above_below_danger_m"),
             "status": s["status"]}
            for s in alert_stations[:5]
        ],
    }


@router.get("/refresh")
async def force_refresh_wrd_bihar() -> Dict[str, Any]:
    """Force immediate scrape of BeFIQR and update the cache."""
    log.info("[WRD Bihar] Manual /refresh triggered")
    result = await _get_stations(force_refresh=True)
    return {
        "refreshed":     True,
        "status":        result["status"],
        "data_source":   result["data_source"],
        "timestamp":     result["timestamp"],
        "station_count": result["station_count"],
        "_cache_hit":    result.get("_cache_hit", False),
    }


@router.get("/scheduler/status")
async def scheduler_status() -> Dict[str, Any]:
    """APScheduler job info — next run time, poll interval, running state."""
    global _scheduler
    if not _scheduler or not _scheduler.running:
        return {"running": False, "message": "Scheduler not started."}
    job = _scheduler.get_job("wrd_bihar_refresh")
    next_run = job.next_run_time.isoformat() if (job and job.next_run_time) else None
    cached = _CACHE.get(_CACHE_KEY)
    return {
        "running":            True,
        "poll_interval_min":  _POLL_MINUTES,
        "next_run_ist":       next_run,
        "last_cached_at_utc": cached["timestamp"] if cached else None,
        "cache_has_data":     cached is not None,
        "job_id":             "wrd_bihar_refresh",
    }


@router.get("/health")
async def wrd_bihar_health() -> Dict[str, Any]:
    """Check if BeFIQR portal is reachable."""
    primary_url = _WRD_URLS[0]
    try:
        resp = requests.get(primary_url, headers=_HEADERS, timeout=(4, 10))
        return {"reachable": resp.ok, "status_code": resp.status_code,
                "url": primary_url, "timestamp": _now_iso()}
    except requests.RequestException as exc:
        return {"reachable": False, "error": str(exc)[:250],
                "url": primary_url, "timestamp": _now_iso()}


# ── /api/v1/stations/all  (Flutter IndiaStationsService endpoint) ────────────
@router.get("/stations/all", summary="All Bihar stations (Flutter app format)")
async def stations_all_v1():
    """
    Flat list of all Bihar stations in the shape expected by
    IndiaStationsService (lib/services/india_stations_service.dart).
    """
    data = await _get_stations()          # existing cached fetch
    stations = data.get("stations", [])
    result = []
    for s in stations:
        result.append({
            "station_id":    s.get("station", ""),
            "city":          s.get("station", ""),
            "state":         "Bihar",
            "district":      s.get("district", ""),
            "river_name":    s.get("river", ""),
            "latitude":      s.get("lat"),
            "longitude":     s.get("lon"),
            "current_level": s.get("current_level_m"),
            "danger_level":  s.get("danger_level_m"),
            "warning_level": s.get("warning_level_m"),
            "flow_rate":     s.get("discharge"),
            "rainfall_24h":  s.get("rainfall_24h"),
        })
    return result
