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
    {'station': 'Sundarpur', 'river': 'Adhawara', 'district': 'Sitamarhi/ Sursand', 'danger_level_m': 61.7, 'warning_level_m': 58.3, 'lat': None, 'lon': None},
    {'station': 'Pupri', 'river': 'Adhawara', 'district': 'Sitamarhi/ Pupri', 'danger_level_m': 55.79, 'warning_level_m': 50.71, 'lat': None, 'lon': None},
    {'station': 'Mubbi', 'river': 'Adhawara', 'district': 'Darbhanga/ Darbhanga Sadar', 'danger_level_m': 48.0, 'warning_level_m': 45.69, 'lat': None, 'lon': None},
    {'station': 'Akbarpur', 'river': 'Awsane', 'district': 'Rohtas/ Rohtas', 'danger_level_m': 103.85, 'warning_level_m': None, 'lat': None, 'lon': None},
    {'station': 'Sakhwaghat', 'river': 'Bagmati', 'district': 'Samastipur/ Hasanpur', 'danger_level_m': 40.0, 'warning_level_m': None, 'lat': None, 'lon': None},
    {'station': 'Phuhiya Gram', 'river': 'Bagmati', 'district': 'Samastipur/ Bithan', 'danger_level_m': 39.4, 'warning_level_m': 34.85, 'lat': None, 'lon': None},
    {'station': 'Phultora Bridge', 'river': 'Bagmati', 'district': 'Samastipur/ Bithan', 'danger_level_m': 39.0, 'warning_level_m': 35.15, 'lat': None, 'lon': None},
    {'station': 'Badlaghat South', 'river': 'Bagmati', 'district': 'Khagaria/ Chautham', 'danger_level_m': 37.64, 'warning_level_m': None, 'lat': None, 'lon': None},
    {'station': 'Badlaghat North', 'river': 'Bagmati', 'district': 'Khagaria/ Chautham', 'danger_level_m': 37.5, 'warning_level_m': None, 'lat': None, 'lon': None},
    {'station': 'Kataunjha', 'river': 'Bagmati', 'district': 'Muzaffarpur/ Aurai', 'danger_level_m': 56.0, 'warning_level_m': 52.81, 'lat': None, 'lon': None},
    {'station': 'Kansar/Chandauli', 'river': 'Bagmati', 'district': 'Sitamarhi/ Belsand', 'danger_level_m': 59.06, 'warning_level_m': 56.18, 'lat': None, 'lon': None},
    {'station': 'Dubbadhar', 'river': 'Bagmati', 'district': 'Sheohar/ Piprarhi', 'danger_level_m': 61.28, 'warning_level_m': 59.11, 'lat': None, 'lon': None},
    {'station': 'Dheng Bridge', 'river': 'Bagmati', 'district': 'Sitamarhi/ Suppi', 'danger_level_m': 71.0, 'warning_level_m': 68.71, 'lat': None, 'lon': None},
    {'station': 'Sonakhan', 'river': 'Bagmati', 'district': 'Sitamarhi/ Suppi', 'danger_level_m': 68.8, 'warning_level_m': 67.03, 'lat': None, 'lon': None},
    {'station': 'Taran', 'river': 'Bakra', 'district': 'Araria/ Jokihat', 'danger_level_m': 48.6, 'warning_level_m': 45.4, 'lat': None, 'lon': None},
    {'station': 'Chulhai Ghat', 'river': 'Balan', 'district': 'Begusarai/ Bhagwanpur', 'danger_level_m': 38.0, 'warning_level_m': None, 'lat': None, 'lon': None},
    {'station': 'Dalsingsarai', 'river': 'Balan', 'district': 'Samastipur/ Dalsingsarai', 'danger_level_m': 41.11, 'warning_level_m': None, 'lat': None, 'lon': None},
    {'station': 'Asani', 'river': 'Banas', 'district': 'Bhojpur/ Arrah', 'danger_level_m': 57.0, 'warning_level_m': None, 'lat': None, 'lon': None},
    {'station': 'Kathara tand', 'river': 'Barnar', 'district': 'Jamui/ Sono', 'danger_level_m': 156.83, 'warning_level_m': None, 'lat': None, 'lon': None},
    {'station': 'Santhua', 'river': 'Batane', 'district': 'Aurangabad/ Aurangabad', 'danger_level_m': 105.95, 'warning_level_m': None, 'lat': None, 'lon': None},
    {'station': 'Wazitpur', 'river': 'Baya', 'district': 'Samastipur/ Vidyapati Nagar', 'danger_level_m': 43.3, 'warning_level_m': None, 'lat': None, 'lon': None},
    {'station': 'Godia', 'river': 'Baya', 'district': 'Vaishali/ Goraul', 'danger_level_m': 49.0, 'warning_level_m': None, 'lat': None, 'lon': None},
    {'station': 'Baya Tatbandh Chain 620', 'river': 'Baya', 'district': 'Samastipur/ Mohiuddinagar', 'danger_level_m': 44.0, 'warning_level_m': 38.52, 'lat': None, 'lon': None},
    {'station': 'Diripar', 'river': 'Bhutahi', 'district': 'Nalanda/ Karai Parsurai', 'danger_level_m': 48.75, 'warning_level_m': None, 'lat': None, 'lon': None},
    {'station': 'Mandakhsa', 'river': 'Bhutahi', 'district': 'Nalanda/ Ekangarsarai', 'danger_level_m': 56.16, 'warning_level_m': None, 'lat': None, 'lon': None},
    {'station': 'Dumar', 'river': 'Brandi', 'district': 'Katihar/ Korha', 'danger_level_m': 30.61, 'warning_level_m': None, 'lat': None, 'lon': None},
    {'station': 'Ekma Syphon', 'river': 'Burhi Gandak', 'district': 'Madhubani/ Khutauna', 'danger_level_m': 42.63, 'warning_level_m': 68.59, 'lat': None, 'lon': None},
    {'station': 'Samastipur road bridge', 'river': 'Burhi Gandak', 'district': 'Samastipur/ Samastipur', 'danger_level_m': 46.02, 'warning_level_m': None, 'lat': None, 'lon': None},
    {'station': 'Samastipur Railpul-1', 'river': 'Burhi Gandak', 'district': 'Samastipur/ Samastipur', 'danger_level_m': 45.73, 'warning_level_m': 39.35, 'lat': None, 'lon': None},
    {'station': 'Dadaulghat', 'river': 'Burhi Gandak', 'district': 'Muzaffarpur/ Goraul', 'danger_level_m': 48.25, 'warning_level_m': 42.54, 'lat': None, 'lon': None},
    {'station': 'Rosera Rail pul', 'river': 'Burhi Gandak', 'district': 'Samastipur/ Rosera', 'danger_level_m': 42.63, 'warning_level_m': 36.32, 'lat': None, 'lon': None},
    {'station': 'Banka Rail Crosssing (Lakshmipur)', 'river': 'Chandan', 'district': 'Banka/ Banka', 'danger_level_m': 84.01, 'warning_level_m': 80.46, 'lat': None, 'lon': None},
    {'station': 'Panjwara', 'river': 'Cheergerua', 'district': 'Banka/ Barahat', 'danger_level_m': 78.32, 'warning_level_m': None, 'lat': None, 'lon': None},
    {'station': 'Kariyawa', 'river': 'Chirayn', 'district': 'Nalanda/ Tharthari', 'danger_level_m': 52.67, 'warning_level_m': None, 'lat': None, 'lon': None},
    {'station': 'Siwan', 'river': 'Daha', 'district': 'Siwan/ Siwan', 'danger_level_m': 63.53, 'warning_level_m': 60.32, 'lat': None, 'lon': None},
    {'station': 'Matiyar', 'river': 'Daha', 'district': 'Saran/ Manjhi', 'danger_level_m': 56.0, 'warning_level_m': 51.18, 'lat': None, 'lon': None},
    {'station': 'Bari bigha', 'river': 'Dardha', 'district': 'Patna/ Dhanarua', 'danger_level_m': 55.02, 'warning_level_m': None, 'lat': None, 'lon': None},
    {'station': 'Nimej', 'river': 'Dharmawati', 'district': 'Buxar/ Brahampur', 'danger_level_m': 58.2, 'warning_level_m': 53.77, 'lat': None, 'lon': None},
    {'station': 'Kharuara (Harnaut)', 'river': 'Dhoba', 'district': 'Nalanda/ Harnaut', 'danger_level_m': 49.86, 'warning_level_m': None, 'lat': None, 'lon': None},
    {'station': 'Durgawati Rail Crossing', 'river': 'Durgawati', 'district': 'Kaimur (Bhabua)/ Durgawati', 'danger_level_m': 69.5, 'warning_level_m': None, 'lat': None, 'lon': None},
    {'station': 'Chenari', 'river': 'Durgawati', 'district': 'Rohtas/ Chenari', 'danger_level_m': 88.2, 'warning_level_m': 85.1, 'lat': None, 'lon': None},
    {'station': 'Mandai', 'river': 'Falgu', 'district': 'Jahanabad/ Modanganj', 'danger_level_m': 61.86, 'warning_level_m': None, 'lat': None, 'lon': None},
    {'station': 'Kushaha', 'river': 'Fariyani', 'district': 'Purnia/ Banmankhi', 'danger_level_m': 42.82, 'warning_level_m': 40.48, 'lat': None, 'lon': None},
    {'station': 'Dumariya Ghat', 'river': 'Gandak', 'district': 'Gopalganj/ Sidhwalia', 'danger_level_m': 62.22, 'warning_level_m': 60.38, 'lat': None, 'lon': None},
    {'station': 'Hajipur', 'river': 'Gandak', 'district': 'Vaishali/ Hajipur', 'danger_level_m': 50.32, 'warning_level_m': 44.42, 'lat': None, 'lon': None},
    {'station': 'Rahimapur', 'river': 'Gandaki', 'district': 'Saran/ Dariapur', 'danger_level_m': 50.95, 'warning_level_m': None, 'lat': None, 'lon': None},
    {'station': 'Chintamanpur', 'river': 'Gandaki', 'district': 'Saran/ Garkha', 'danger_level_m': 53.0, 'warning_level_m': None, 'lat': None, 'lon': None},
    {'station': 'Ramayanpur', 'river': 'Ganga', 'district': 'Katihar/ Amdabad', 'danger_level_m': 27.56, 'warning_level_m': 22.75, 'lat': None, 'lon': None},
    {'station': 'Karhagola ghat', 'river': 'Ganga', 'district': 'Katihar/ Barari', 'danger_level_m': 29.87, 'warning_level_m': 24.9, 'lat': None, 'lon': None},
    {'station': 'Buxar', 'river': 'Ganga', 'district': 'Buxar/ Buxar', 'danger_level_m': 60.32, 'warning_level_m': 48.88, 'lat': None, 'lon': None},
    {'station': 'BKG Embankment 90.52 Km', 'river': 'Ganga', 'district': 'Bhojpur/ Barhara', 'danger_level_m': 53.13, 'warning_level_m': 45.26, 'lat': None, 'lon': None},
    {'station': 'Sultanganj', 'river': 'Ganga', 'district': 'Bhagalpur/ Sultanganj', 'danger_level_m': 32.5, 'warning_level_m': 28.09, 'lat': None, 'lon': None},
    {'station': 'Dakranala', 'river': 'Ganga', 'district': 'Munger/ Sadar Munger', 'danger_level_m': 37.58, 'warning_level_m': 31.26, 'lat': None, 'lon': None},
    {'station': 'Kashtharnighat', 'river': 'Ganga', 'district': 'Munger/ Sadar Munger', 'danger_level_m': 39.33, 'warning_level_m': 30.65, 'lat': None, 'lon': None},
    {'station': 'Raghopur', 'river': 'Ganga', 'district': 'Bhagalpur/ Kharik', 'danger_level_m': 32.8, 'warning_level_m': 25.82, 'lat': None, 'lon': None},
    {'station': 'Ismailpur Bindtoli', 'river': 'Ganga', 'district': 'Bhagalpur/ Gopalpur', 'danger_level_m': 31.6, 'warning_level_m': 25.13, 'lat': None, 'lon': None},
    {'station': 'Jai Chhapra', 'river': 'Ghagra', 'district': 'Saran/ Manjhi', 'danger_level_m': 56.5, 'warning_level_m': None, 'lat': None, 'lon': None},
    {'station': 'Manjhi Bridge', 'river': 'Ghagra', 'district': 'Saran/ Manjhi', 'danger_level_m': 52.4, 'warning_level_m': None, 'lat': None, 'lon': None},
    {'station': 'Ghogha Kahalgaon Road Crossing', 'river': 'Ghogha  (Sundar)', 'district': 'Bhagalpur/ Kahalgaon', 'danger_level_m': 28.52, 'warning_level_m': 25.51, 'lat': None, 'lon': None},
    {'station': 'Bakrachausua', 'river': 'Goithawa', 'district': 'Nalanda/ Giriyak', 'danger_level_m': 65.86, 'warning_level_m': None, 'lat': None, 'lon': None},
    {'station': 'Balgudar', 'river': 'Harohar', 'district': 'Lakhisarai/ Lakhisarai', 'danger_level_m': 40.0, 'warning_level_m': 32.71, 'lat': None, 'lon': None},
    {'station': 'Jamune Bajar', 'river': 'Jamune', 'district': 'Gaya/ Gaya', 'danger_level_m': 94.41, 'warning_level_m': None, 'lat': None, 'lon': None},
    {'station': 'Konighat', 'river': 'Jeewachh/ Kamla', 'district': 'Darbhanga/ Biraul', 'danger_level_m': 38.21, 'warning_level_m': None, 'lat': None, 'lon': None},
    {'station': 'Derwa', 'river': 'Jharahi', 'district': 'Gopalganj/ Kuchaikot', 'danger_level_m': 70.4, 'warning_level_m': 67.85, 'lat': None, 'lon': None},
    {'station': 'Kachahripur', 'river': 'Jhim', 'district': '', 'danger_level_m': 74.5, 'warning_level_m': None, 'lat': None, 'lon': None},
    {'station': 'Darjia', 'river': 'Kamala Balan', 'district': 'Darbhanga/ Ghanshyampur', 'danger_level_m': 46.8, 'warning_level_m': 45.8, 'lat': None, 'lon': None},
    {'station': 'Rasiyari Pul', 'river': 'Kamala Balan', 'district': 'Darbhanga/ Ghanshyampur', 'danger_level_m': 45.5, 'warning_level_m': 42.84, 'lat': None, 'lon': None},
    {'station': 'Kothram', 'river': 'Kamla', 'district': 'Darbhanga/ Gaura Bauram', 'danger_level_m': 44.0, 'warning_level_m': None, 'lat': None, 'lon': None},
    {'station': 'Jhanjharpur Rail pul-88', 'river': 'Kamla', 'district': 'Madhubani/ Jhanjharpur', 'danger_level_m': 50.0, 'warning_level_m': 48.93, 'lat': None, 'lon': None},
    {'station': 'Jainagar Weir site (Manual)', 'river': 'Kamla', 'district': 'Madhubani/ Jainagar', 'danger_level_m': 65.75, 'warning_level_m': 67.0, 'lat': None, 'lon': None},
    {'station': 'Gausaghat', 'river': 'Kamla Dhar', 'district': 'Darbhanga/ Darbhanga Sadar', 'danger_level_m': 49.0, 'warning_level_m': 46.18, 'lat': None, 'lon': None},
    {'station': 'Tarabari', 'river': 'Kankai', 'district': 'Kishanganj/ Thakurganj', 'danger_level_m': 48.2, 'warning_level_m': 47.3, 'lat': None, 'lon': None},
    {'station': 'Vikramganj Rail Crossing', 'river': 'Kao', 'district': 'Rohtas/ Bikramganj', 'danger_level_m': 86.2, 'warning_level_m': 83.34, 'lat': None, 'lon': None},
    {'station': 'Karbandia', 'river': 'Kao', 'district': 'Rohtas/ Sasaram', 'danger_level_m': 106.8, 'warning_level_m': None, 'lat': None, 'lon': None},
    {'station': 'Pabheri', 'river': 'Kararua', 'district': 'Patna/ Dhanarua', 'danger_level_m': 52.67, 'warning_level_m': None, 'lat': None, 'lon': None},
    {'station': 'Kolhuaghat', 'river': 'Kareh Bagmati', 'district': 'Samastipur/ Shivaji Nagar', 'danger_level_m': 42.2, 'warning_level_m': 37.0, 'lat': None, 'lon': None},
    {'station': 'Sonmankhi', 'river': 'Kareh Bagmati', 'district': 'Khagaria/ Khagaria', 'danger_level_m': 36.5, 'warning_level_m': 32.74, 'lat': None, 'lon': None},
    {'station': 'Kari Kosi Chain 389', 'river': 'Kari Kosi', 'district': 'Katihar/ Mansahi', 'danger_level_m': 28.52, 'warning_level_m': None, 'lat': None, 'lon': None},
    {'station': 'Kakrait Ghat', 'river': 'Karmnasha', 'district': 'Kaimur (Bhabua)/ Durgawati', 'danger_level_m': 62.3, 'warning_level_m': None, 'lat': None, 'lon': None},
    {'station': 'Phulwaria', 'river': 'Khalkhalia', 'district': 'Bhagalpur/ Jagdishpur', 'danger_level_m': 35.6, 'warning_level_m': None, 'lat': None, 'lon': None},
    {'station': 'Mohani', 'river': 'Khiroi', 'district': 'Darbhanga/ Bahadurpur', 'danger_level_m': 46.0, 'warning_level_m': None, 'lat': None, 'lon': None},
    {'station': 'Agropatti', 'river': 'Khiroi', 'district': 'Sitamarhi/ Pupri', 'danger_level_m': 52.75, 'warning_level_m': 48.93, 'lat': None, 'lon': None},
    {'station': 'Lakhisarai', 'river': 'Kiul', 'district': 'Lakhisarai/ Lakhisarai', 'danger_level_m': 41.1, 'warning_level_m': 35.7, 'lat': None, 'lon': None},
    {'station': 'Sahora', 'river': 'Kosi', 'district': 'Bhagalpur/ Rangra Chowk', 'danger_level_m': 31.48, 'warning_level_m': 26.26, 'lat': None, 'lon': None},
    {'station': 'Dhamaraghat', 'river': 'Kosi', 'district': 'Khagaria/ Chautham', 'danger_level_m': 38.55, 'warning_level_m': None, 'lat': None, 'lon': None},
    {'station': 'Dumri Bridge', 'river': 'Kosi', 'district': 'Khagaria/ Beldaur', 'danger_level_m': 33.85, 'warning_level_m': None, 'lat': None, 'lon': None},
    {'station': 'Ghoghepur', 'river': 'Kosi', 'district': 'Saharsa/ Mahishi', 'danger_level_m': 42.28, 'warning_level_m': None, 'lat': None, 'lon': None},
    {'station': 'Kursela', 'river': 'Kosi', 'district': 'Katihar/ Kursela', 'danger_level_m': 30.0, 'warning_level_m': 24.6, 'lat': None, 'lon': None},
    {'station': 'Khurmabad', 'river': 'Kudra', 'district': 'Kaimur (Bhabua)/ Kudra', 'danger_level_m': 84.0, 'warning_level_m': None, 'lat': None, 'lon': None},
    {'station': 'Bahuara', 'river': 'Kudra', 'district': 'Kaimur (Bhabua)/ Kudra', 'danger_level_m': 72.7, 'warning_level_m': 68.9, 'lat': None, 'lon': None},
    {'station': 'Borabari', 'river': 'Lakhandei', 'district': 'Muzaffarpur/ Gaighat', 'danger_level_m': 42.0, 'warning_level_m': None, 'lat': None, 'lon': None},
    {'station': 'Sitamarhi', 'river': 'Lakhandei', 'district': 'Sitamarhi/ Dumra', 'danger_level_m': 61.0, 'warning_level_m': None, 'lat': None, 'lon': None},
    {'station': 'Gowabari', 'river': 'Lal Bakeya', 'district': 'Purvi Champaran/ Dhaka', 'danger_level_m': 71.15, 'warning_level_m': 69.0, 'lat': None, 'lon': None},
    {'station': 'Sohrapur', 'river': 'Lokayin', 'district': 'Nalanda/ Hilsa', 'danger_level_m': 58.1, 'warning_level_m': None, 'lat': None, 'lon': None},
    {'station': 'Kursail', 'river': 'Mahananda', 'district': 'Katihar/ Kadwa', 'danger_level_m': 31.4, 'warning_level_m': 28.65, 'lat': None, 'lon': None},
    {'station': 'Baharkhal', 'river': 'Mahananda', 'district': 'Katihar/ Azamnagar', 'danger_level_m': 31.09, 'warning_level_m': 28.0, 'lat': None, 'lon': None},
    {'station': 'Azamnagar', 'river': 'Mahananda', 'district': 'Katihar/ Azamnagar', 'danger_level_m': 29.87, 'warning_level_m': 26.83, 'lat': None, 'lon': None},
    {'station': 'Dhabol', 'river': 'Mahananda', 'district': 'Katihar/ Azamnagar', 'danger_level_m': 29.26, 'warning_level_m': 26.09, 'lat': None, 'lon': None},
    {'station': 'Durgapur', 'river': 'Mahananda', 'district': 'Katihar/ Pranpur', 'danger_level_m': 28.05, 'warning_level_m': 25.63, 'lat': None, 'lon': None},
    {'station': 'Govindpur', 'river': 'Mahananda', 'district': 'Katihar/ Amdabad', 'danger_level_m': 27.18, 'warning_level_m': 23.18, 'lat': None, 'lon': None},
    {'station': 'Sheetalpur', 'river': 'Mahi', 'district': 'Saran/ Dariapur', 'danger_level_m': 49.87, 'warning_level_m': None, 'lat': None, 'lon': None},
    {'station': 'Pirokhar', 'river': 'Maraha', 'district': 'Sitamarhi/ Pupri', 'danger_level_m': 51.2, 'warning_level_m': None, 'lat': None, 'lon': None},
    {'station': 'Gardankatta East', 'river': 'Mechi East', 'district': 'Kishanganj/ Thakurganj', 'danger_level_m': 59.6, 'warning_level_m': 58.18, 'lat': None, 'lon': None},
    {'station': 'Gardankatta West', 'river': 'Mechi West/ Jamuna', 'district': 'Kishanganj/ Thakurganj', 'danger_level_m': 58.4, 'warning_level_m': 55.8, 'lat': None, 'lon': None},
    {'station': 'Sirnama', 'river': 'Mohane', 'district': 'Nalanda/ Harnaut', 'danger_level_m': 45.09, 'warning_level_m': None, 'lat': None, 'lon': None},
    {'station': 'Chandi', 'river': 'Mohane', 'district': 'Nalanda/ Chandi', 'danger_level_m': 52.15, 'warning_level_m': None, 'lat': None, 'lon': None},
    {'station': 'Belchhi', 'river': 'Mohane', 'district': 'Nalanda/ Chandi', 'danger_level_m': 45.83, 'warning_level_m': None, 'lat': None, 'lon': None},
    {'station': 'Chhoti Chhariyari', 'river': 'Mohane', 'district': 'Nalanda/ Tharthari', 'danger_level_m': 50.31, 'warning_level_m': None, 'lat': None, 'lon': None},
    {'station': 'Panchanpur', 'river': 'Morahar', 'district': 'Gaya/ Tekari', 'danger_level_m': 94.4, 'warning_level_m': None, 'lat': None, 'lon': None},
    {'station': 'Mahakola (Basa)', 'river': 'Muhani', 'district': 'Munger/ Haveli Kharagpur', 'danger_level_m': 51.1, 'warning_level_m': None, 'lat': None, 'lon': None},
    {'station': 'Babhandeeha', 'river': 'Nonai', 'district': 'Nalanda/ Hilsa', 'danger_level_m': 53.98, 'warning_level_m': None, 'lat': None, 'lon': None},
    {'station': 'Gangmohan Gram', 'river': 'Noon', 'district': 'Samastipur/ Sarairanjan', 'danger_level_m': 40.2, 'warning_level_m': 39.92, 'lat': None, 'lon': None},
    {'station': 'Pothiya Pul', 'river': 'Noon Kathane', 'district': 'Samastipur/ Tajpur', 'danger_level_m': 44.0, 'warning_level_m': None, 'lat': None, 'lon': None},
    {'station': 'Shahpur-Maricha', 'river': 'Noona', 'district': 'Muzaffarpur/ Kurhani', 'danger_level_m': 50.25, 'warning_level_m': None, 'lat': None, 'lon': None},
    {'station': 'Saidabad', 'river': 'Noona', 'district': 'Araria/ Sikti', 'danger_level_m': 58.74, 'warning_level_m': None, 'lat': None, 'lon': None},
    {'station': 'Pariyari', 'river': 'Noona', 'district': 'Araria/ Sikti', 'danger_level_m': 57.26, 'warning_level_m': None, 'lat': None, 'lon': None},
    {'station': 'Malisadha/ Chhabilapur', 'river': 'Paimar', 'district': 'Nalanda/ Rajgir', 'danger_level_m': 65.86, 'warning_level_m': None, 'lat': None, 'lon': None},
    {'station': 'Giriyak', 'river': 'Panchane', 'district': 'Nalanda/ Giriyak', 'danger_level_m': 60.5, 'warning_level_m': None, 'lat': None, 'lon': None},
    {'station': 'Rahimpurganj', 'river': 'Panchane', 'district': 'Nalanda/ Rahui', 'danger_level_m': 51.54, 'warning_level_m': None, 'lat': None, 'lon': None},
    {'station': 'Rajgir Biharsharif Road Crossing', 'river': 'Panchane', 'district': 'Nalanda/ Biharsharif', 'danger_level_m': 53.9, 'warning_level_m': None, 'lat': None, 'lon': None},
    {'station': 'Shikarpur', 'river': 'Pandai Nadi', 'district': 'Paschim Champaran/ Narkatiyaganj', 'danger_level_m': 81.7, 'warning_level_m': None, 'lat': None, 'lon': None},
    {'station': 'Baisi', 'river': 'Parman', 'district': 'Purnia/ Baisi', 'danger_level_m': 36.45, 'warning_level_m': 34.35, 'lat': None, 'lon': None},
    {'station': 'Araria', 'river': 'Parman', 'district': 'Araria/ Araria', 'danger_level_m': 47.68, 'warning_level_m': 45.14, 'lat': None, 'lon': None},
    {'station': 'Hamidnagar', 'river': 'Punpun', 'district': 'Aurangabad/ Goh', 'danger_level_m': 74.17, 'warning_level_m': None, 'lat': None, 'lon': None},
    {'station': 'Kadirganj', 'river': 'Sakri', 'district': 'Nawada/ Nawada', 'danger_level_m': 85.8, 'warning_level_m': None, 'lat': None, 'lon': None},
    {'station': 'Puara', 'river': 'Sakri', 'district': 'Nawada/ Nawada', 'danger_level_m': 75.98, 'warning_level_m': None, 'lat': None, 'lon': None},
    {'station': 'Baksoti (Kutarichak)', 'river': 'Sakri', 'district': 'Nawada/ Gobindpur', 'danger_level_m': 109.49, 'warning_level_m': None, 'lat': None, 'lon': None},
    {'station': 'Jiyarkulti', 'river': 'Sakri', 'district': 'Nalanda/ Asthawan', 'danger_level_m': 56.45, 'warning_level_m': None, 'lat': None, 'lon': None},
    {'station': 'Shivaghat', 'river': 'Sikrahna', 'district': 'Paschim Champaran/ Chanpatiya', 'danger_level_m': 73.33, 'warning_level_m': None, 'lat': None, 'lon': None},
    {'station': 'Arwal Sahar Pul', 'river': 'Sone', 'district': 'Bhojpur/ Sahar', 'danger_level_m': 75.87, 'warning_level_m': 65.77, 'lat': None, 'lon': None},
    {'station': 'Kadwan/ Matianwa', 'river': 'Sone', 'district': 'Rohtas/ Nauhatta', 'danger_level_m': 140.85, 'warning_level_m': 137.0, 'lat': None, 'lon': None},
    {'station': 'Bhagwanpur', 'river': 'Suawara', 'district': 'Kaimur (Bhabua)/ Bhagwanpur', 'danger_level_m': 89.3, 'warning_level_m': 85.6, 'lat': None, 'lon': None},
    {'station': 'Sursar', 'river': 'Sursar Dhar', 'district': 'Araria/ Narpatganj', 'danger_level_m': 67.4, 'warning_level_m': 65.35, 'lat': None, 'lon': None},
    {'station': 'Uchait', 'river': 'Thomane', 'district': 'Madhubani/ Benipatti', 'danger_level_m': 49.0, 'warning_level_m': None, 'lat': None, 'lon': None},
    {'station': 'Tilaiya', 'river': 'Tilaiya', 'district': 'Nawada/ Hisua', 'danger_level_m': 91.5, 'warning_level_m': None, 'lat': None, 'lon': None},
    {'station': 'Litiahi', 'river': 'Tilawe', 'district': 'Supaul/ Pipra', 'danger_level_m': 52.45, 'warning_level_m': 48.75, 'lat': None, 'lon': None},
    {'station': 'Tisbhawra Pul', 'river': 'Tisbhawra/ Kamla', 'district': 'Darbhanga/ Darbhanga Sadar', 'danger_level_m': 47.0, 'warning_level_m': None, 'lat': None, 'lon': None},
    {'station': 'Garhi', 'river': 'Upper Kiul', 'district': 'Jamui/ Khaira', 'danger_level_m': 167.56, 'warning_level_m': 164.02, 'lat': None, 'lon': None},
    {'station': 'Thelwa', 'river': 'Upperbadua', 'district': 'Jamui/ Jhajha', 'danger_level_m': 103.0, 'warning_level_m': 100.2, 'lat': None, 'lon': None},
    {'station': 'Bibiganj', 'river': 'West Kankai', 'district': 'Kishanganj/ Terhagachh', 'danger_level_m': 48.8, 'warning_level_m': 47.42, 'lat': None, 'lon': None},
    {'station': 'Gosaipur', 'river': 'West Kankai', 'district': 'Kishanganj/ Kochadhaman', 'danger_level_m': 46.94, 'warning_level_m': 44.25, 'lat': None, 'lon': None},
    {'station': 'Ekmighat', 'river': 'Adhwara', 'district': 'Darbhanga / Bahadurpur', 'danger_level_m': 46.94, 'warning_level_m': 40.88, 'lat': None, 'lon': None},
    {'station': 'Kamtaul', 'river': 'Adhwara', 'district': 'Darbhanga / Jale', 'danger_level_m': 50.0, 'warning_level_m': 46.64, 'lat': None, 'lon': None},
    {'station': 'Sonbarsa', 'river': 'Adhwara', 'district': 'Sitamarhi / Sonbarsa', 'danger_level_m': 81.85, 'warning_level_m': 78.71, 'lat': None, 'lon': None},
    {'station': 'Benibad', 'river': 'Bagmati', 'district': 'Muzaffarpur / Gaighat', 'danger_level_m': 48.68, 'warning_level_m': 46.96, 'lat': None, 'lon': None},
    {'station': 'Hayaghat', 'river': 'Bagmati', 'district': 'Darbhanga / Hayaghat', 'danger_level_m': 45.72, 'warning_level_m': 39.77, 'lat': None, 'lon': None},
    {'station': 'Khagaria', 'river': 'Burhi Gandak', 'district': 'Khagaria / Khagaria', 'danger_level_m': 36.58, 'warning_level_m': 29.94, 'lat': None, 'lon': None},
    {'station': 'Rosera', 'river': 'Burhi Gandak', 'district': 'Samastipur / Rosera', 'danger_level_m': 42.63, 'warning_level_m': 36.32, 'lat': None, 'lon': None},
    {'station': 'Samastipur', 'river': 'Burhi Gandak', 'district': 'Samastipur / Samastipur', 'danger_level_m': 46.0, 'warning_level_m': 39.34, 'lat': None, 'lon': None},
    {'station': 'Sikandarpur (Muzzafarpur)', 'river': 'Burhi Gandak', 'district': 'Muzaffarpur / Musahari', 'danger_level_m': 52.53, 'warning_level_m': 45.39, 'lat': None, 'lon': None},
    {'station': 'Chatia', 'river': 'Gandak', 'district': 'East Champaran / Areraj', 'danger_level_m': 69.15, 'warning_level_m': 64.96, 'lat': None, 'lon': None},
    {'station': 'Dumariaghat', 'river': 'Gandak', 'district': 'Gopalganj / Sidhwalia', 'danger_level_m': 62.22, 'warning_level_m': 60.35, 'lat': None, 'lon': None},
    {'station': 'Rewaghat', 'river': 'Gandak', 'district': 'Muzaffarpur / Saraiya', 'danger_level_m': 54.41, 'warning_level_m': 50.98, 'lat': None, 'lon': None},
    {'station': 'Bhagalpur', 'river': 'Ganga', 'district': 'Bhagalpur / Nathnagar', 'danger_level_m': 33.68, 'warning_level_m': 25.66, 'lat': None, 'lon': None},
    {'station': 'Dighaghat', 'river': 'Ganga', 'district': 'Patna / Patna Rural', 'danger_level_m': 50.45, 'warning_level_m': 42.9, 'lat': None, 'lon': None},
    {'station': 'Gandhighat', 'river': 'Ganga', 'district': 'Patna / Patna Rural', 'danger_level_m': 48.6, 'warning_level_m': 42.45, 'lat': None, 'lon': None},
    {'station': 'Hathidah', 'river': 'Ganga', 'district': 'Patna / Mokameh', 'danger_level_m': 41.76, 'warning_level_m': 34.87, 'lat': None, 'lon': None},
    {'station': 'Kahalgaon', 'river': 'Ganga', 'district': 'Bhagalpur / Gopalpur', 'danger_level_m': 31.09, 'warning_level_m': 24.72, 'lat': None, 'lon': None},
    {'station': 'Munger', 'river': 'Ganga', 'district': 'Munger / Sadar Munger', 'danger_level_m': 39.33, 'warning_level_m': 30.65, 'lat': None, 'lon': None},
    {'station': 'Darauli', 'river': 'Ghaghra', 'district': 'Siwan / Darauli', 'danger_level_m': 60.82, 'warning_level_m': 56.17, 'lat': None, 'lon': None},
    {'station': 'Gangpur Siswan', 'river': 'Ghaghra', 'district': 'Siwan / Siswan', 'danger_level_m': 57.04, 'warning_level_m': 51.91, 'lat': None, 'lon': None},
    {'station': 'Jhanjharpur', 'river': 'Kamalabalan', 'district': 'Madhubani / Jhanjharpur', 'danger_level_m': 50.0, 'warning_level_m': 48.9, 'lat': None, 'lon': None},
    {'station': 'Jainagar', 'river': 'Kamla', 'district': 'Madhubani / Jainagar', 'danger_level_m': 67.75, 'warning_level_m': 66.62, 'lat': None, 'lon': None},
    {'station': 'Baltara', 'river': 'Kosi', 'district': 'Khagaria / Beldaur', 'danger_level_m': 33.85, 'warning_level_m': 32.07, 'lat': None, 'lon': None},
    {'station': 'Basua', 'river': 'Kosi', 'district': 'Supaul / Supaul', 'danger_level_m': 47.75, 'warning_level_m': 46.43, 'lat': None, 'lon': None},
    {'station': 'Dhengraghat', 'river': 'Mahananda', 'district': 'Purnia / Baisi', 'danger_level_m': 35.65, 'warning_level_m': 34.07, 'lat': None, 'lon': None},
    {'station': 'Taibpur', 'river': 'Mahananda', 'district': 'Kishanganj / Thakurganj', 'danger_level_m': 66.0, 'warning_level_m': 64.29, 'lat': None, 'lon': None},
    {'station': 'Sripalpur', 'river': 'Punpun', 'district': 'Patna / Phulwari', 'danger_level_m': 50.6, 'warning_level_m': 44.87, 'lat': None, 'lon': None},
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
    except RuntimeError as exc:
        log.warning(f"[WRD Bihar] Scheduled refresh failed: {exc}")


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
