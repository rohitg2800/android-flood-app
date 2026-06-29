"""
Weather service utilities including location resolution, fallback data generation,
and OpenWeatherMap API integration.
"""

import os
import datetime
import requests
import copy
from typing import Dict, Any
from fastapi import HTTPException

from .dependencies import (
    WEATHER_CACHE_TTL_SECONDS,
    WEATHER_TIMEZONE_OFFSET,
    WEATHER_TIMEZONE_NAME,
    normalize_weather_lookup,
    title_case_location_label,
    _weather_hash_unit,
    get_cached_weather_response,
    store_weather_response,
    get_openweather_api_key,
    refresh_backend_env,
)

# Weather location hints - predefined database of Indian flood-prone locations
WEATHER_LOCATION_HINTS = [
    {
        "name": "Kolhapur",
        "state": "Bihar",
        "lat": 16.705,
        "lon": 74.2433,
        "aliases": [
            "kolhapur", "maharashtra", "shirol", "shirol sector",
            "irwin bridge", "kagal", "kagal high ground", "kurundwad",
            "rajaram barrage", "panchganga",
        ],
    },
    {
        "name": "Patna",
        "state": "Bihar",
        "lat": 25.5941,
        "lon": 85.1376,
        "aliases": [
            "patna", "bihar", "patna lowlands", "darbhanga", "darbhanga sector",
            "koshi barrage", "dumariaghat", "basantpur",
        ],
    },
    {
        "name": "Kochi",
        "state": "Kerala",
        "lat": 9.9312,
        "lon": 76.2673,
        "aliases": [
            "kochi", "kerala", "kuttanad", "kuttanad region",
            "vembanad", "vembanad lowlands", "periyar", "periyar banks", "aranmula",
        ],
    },
    {
        "name": "Guwahati",
        "state": "Assam",
        "lat": 26.1445,
        "lon": 91.7362,
        "aliases": [
            "guwahati", "assam", "majuli island", "kaziranga sector", "brahmaputra banks",
        ],
    },
    {
        "name": "Dehradun",
        "state": "Uttarakhand",
        "lat": 30.3165,
        "lon": 78.0322,
        "aliases": [
            "dehradun", "uttarakhand", "joshimath sector", "rishikesh ghats", "mandakini basin",
        ],
    },
    {
        "name": "Surat",
        "state": "Gujarat",
        "lat": 21.1702,
        "lon": 72.8311,
        "aliases": [
            "surat", "gujarat", "surat lowlands", "ukai dam sector",
            "tapi river banks", "ukai", "tapi",
        ],
    },
    {
        "name": "Bhubaneswar",
        "state": "Odisha",
        "lat": 20.2961,
        "lon": 85.8245,
        "aliases": [
            "bhubaneswar", "odisha", "orissa", "mahanadi delta", "cuttack sector",
            "cuttack", "puri coastal", "puri",
        ],
    },
    {
        "name": "Kolkata",
        "state": "West Bengal",
        "lat": 22.5726,
        "lon": 88.3639,
        "aliases": [
            "kolkata", "west bengal", "sundarbans delta", "hooghly banks",
            "siliguri sector", "hooghly", "sundarbans", "siliguri",
        ],
    },
    {
        "name": "Lucknow",
        "state": "Uttar Pradesh",
        "lat": 26.8467,
        "lon": 80.9462,
        "aliases": [
            "lucknow", "uttar pradesh", "varanasi ghats", "prayagraj lowlands",
            "ghaghara basin", "varanasi", "prayagraj", "ghaghara",
        ],
    },
    {
        "name": "Chandigarh",
        "state": "Punjab",
        "lat": 30.7333,
        "lon": 76.7794,
        "aliases": [
            "punjab", "sutlej banks", "ludhiana sector", "ludhiana", "ravi basin", "ravi", "sutlej",
        ],
    },
    {
        "name": "Chennai",
        "state": "Tamil Nadu",
        "lat": 13.0827,
        "lon": 80.2707,
        "aliases": [
            "chennai", "tamil nadu", "chennai lowlands", "kaveri delta",
            "madurai sector", "kaveri", "madurai",
        ],
    },
]

# ============= WEATHER API =============
def request_openweather(path: str, params: Dict[str, Any], base_url: str = "https://api.openweathermap.org") -> requests.Response:
    """Request data from OpenWeatherMap API."""
    api_key = get_openweather_api_key()
    if not api_key:
        raise HTTPException(status_code=503, detail="Missing server weather API key")

    merged_params = dict(params)
    merged_params["appid"] = api_key

    try:
        return requests.get(f"{base_url}{path}", params=merged_params, timeout=10)
    except requests.RequestException as exc:
        raise HTTPException(status_code=502, detail=f"Weather upstream request failed: {exc}") from exc

def proxy_openweather(path: str, params: Dict[str, Any], base_url: str = "https://api.openweathermap.org"):
    """Proxy OpenWeatherMap request and cache response."""
    response = request_openweather(path, params, base_url=base_url)
    if not response.ok:
        detail = response.text[:200] if response.text else "Unknown weather service error"
        raise HTTPException(status_code=response.status_code, detail=detail)

    data = response.json()
    store_weather_response(path, params, data)
    return data

def resilient_openweather(
    path: str,
    params: Dict[str, Any],
    fallback_factory=None,
    cache_ttl: int = WEATHER_CACHE_TTL_SECONDS,
):
    """Request with fallback to cache and fallback factory."""
    try:
        return proxy_openweather(path, params)
    except HTTPException as exc:
        cached_payload = get_cached_weather_response(path, params, max_age=cache_ttl)
        if cached_payload is not None:
            return cached_payload
        if fallback_factory is not None:
            return fallback_factory(exc)
        raise

# ============= WEATHER LOCATION RESOLUTION =============
def get_weather_location_hint(query: str) -> Dict[str, Any] | None:
    """Get location hint from predefined weather locations."""
    normalized_query = normalize_weather_lookup(query)
    if not normalized_query:
        return None

    for entry in WEATHER_LOCATION_HINTS:
        for alias in entry["aliases"]:
            normalized_alias = normalize_weather_lookup(alias)
            if (
                normalized_query == normalized_alias
                or normalized_query in normalized_alias
                or normalized_alias in normalized_query
            ):
                return {
                    "name": entry["name"],
                    "state": entry["state"],
                    "lat": entry["lat"],
                    "lon": entry["lon"],
                }

    return None

def synthetic_coords_from_query(query: str) -> tuple[float, float]:
    """Generate synthetic coordinates from query string."""
    normalized_query = normalize_weather_lookup(query) or "india"
    lat = 8.0 + _weather_hash_unit(f"{normalized_query}|lat") * 28.0
    lon = 68.0 + _weather_hash_unit(f"{normalized_query}|lon") * 29.0
    return round(lat, 4), round(lon, 4)

def nearest_weather_hint(lat: float, lon: float) -> Dict[str, Any]:
    """Find nearest weather location hint to coordinates."""
    return min(
        WEATHER_LOCATION_HINTS,
        key=lambda entry: (float(entry["lat"]) - lat) ** 2 + (float(entry["lon"]) - lon) ** 2,
    )

def build_local_weather_location(
    query: str | None = None,
    lat: float | None = None,
    lon: float | None = None,
) -> Dict[str, Any]:
    """Build location info from query or coordinates."""
    if lat is not None and lon is not None:
        nearest_hint = nearest_weather_hint(lat, lon)
        return {
            "name": nearest_hint["name"],
            "state": nearest_hint["state"],
            "country": "IN",
            "lat": round(float(lat), 4),
            "lon": round(float(lon), 4),
        }

    cleaned_query = (query or "").strip()
    if cleaned_query:
        hinted_location = get_weather_location_hint(cleaned_query)
        if hinted_location:
            return {
                "name": hinted_location["name"],
                "state": hinted_location["state"],
                "country": "IN",
                "lat": round(float(hinted_location["lat"]), 4),
                "lon": round(float(hinted_location["lon"]), 4),
            }

        fallback_label = next(iter(build_weather_lookup_candidates(cleaned_query)), cleaned_query)
        pseudo_lat, pseudo_lon = synthetic_coords_from_query(fallback_label)
        return {
            "name": title_case_location_label(fallback_label),
            "state": None,
            "country": "IN",
            "lat": pseudo_lat,
            "lon": pseudo_lon,
        }

    default_hint = WEATHER_LOCATION_HINTS[0]
    return {
        "name": default_hint["name"],
        "state": default_hint["state"],
        "country": "IN",
        "lat": round(float(default_hint["lat"]), 4),
        "lon": round(float(default_hint["lon"]), 4),
    }

def build_weather_lookup_candidates(query: str) -> list[str]:
    """Build list of candidate queries for weather lookup."""
    import re
    
    trimmed = (query or "").strip()
    if not trimmed:
        return []

    candidates: list[str] = []
    seen: set[str] = set()
    WEATHER_QUERY_NOISE_PATTERN = re.compile(
        r"\b(sector|region|lowlands?|basin|banks?|bridge|barrage|ghats?|control|command|high[-\s]?ground|coastal|delta|island|catchment|console)\b",
        re.IGNORECASE,
    )

    def add_candidate(value: str):
        next_value = value.strip()
        next_key = normalize_weather_lookup(next_value)
        if next_value and next_key and next_key not in seen:
            seen.add(next_key)
            candidates.append(next_value)

    add_candidate(trimmed)
    for part in trimmed.split(","):
        add_candidate(part)

    stripped = WEATHER_QUERY_NOISE_PATTERN.sub(" ", trimmed)
    stripped = re.sub(r"\s+", " ", stripped).strip(" ,")
    if stripped and stripped != trimmed:
        add_candidate(stripped)
        for part in stripped.split(","):
            add_candidate(part)

    hint = get_weather_location_hint(trimmed)
    if hint:
        add_candidate(hint["name"])
        add_candidate(f'{hint["name"]}, {hint["state"]}')

    return candidates[:8]

def resolve_weather_location(query: str) -> Dict[str, Any] | None:
    """Resolve weather location using API or fallback."""
    hint = get_weather_location_hint(query)
    if hint:
        return {
            "name": hint["name"],
            "state": hint["state"],
            "country": "IN",
            "lat": hint["lat"],
            "lon": hint["lon"],
        }

    for candidate in build_weather_lookup_candidates(query):
        try:
            results = proxy_openweather(
                "/geo/1.0/direct",
                {"q": candidate, "limit": 1},
            )
        except HTTPException:
            results = get_cached_weather_response("/geo/1.0/direct", {"q": candidate, "limit": 1}) or []

        if results:
            return results[0]

    return build_local_weather_location(query=query)

# ============= FALLBACK WEATHER DATA GENERATION =============
def build_weather_descriptor(
    rainfall_mm: float,
    cloud_cover: int,
    humidity: int,
    is_daytime: bool,
) -> Dict[str, str]:
    """Build weather descriptor based on conditions."""
    if rainfall_mm >= 6:
        return {"main": "Rain", "description": "steady monsoon rain", "icon": "10d" if is_daytime else "10n"}
    if rainfall_mm >= 1.5:
        return {"main": "Drizzle", "description": "light rain bands", "icon": "09d" if is_daytime else "09n"}
    if humidity >= 88 and cloud_cover >= 68:
        return {"main": "Mist", "description": "humid mist", "icon": "50d" if is_daytime else "50n"}
    if cloud_cover >= 55:
        return {"main": "Clouds", "description": "broken clouds", "icon": "03d" if is_daytime else "03n"}
    return {"main": "Clear", "description": "clear sky", "icon": "01d" if is_daytime else "01n"}

def build_fallback_current_weather(
    city: str | None = None,
    lat: float | None = None,
    lon: float | None = None,
    reason: str = "LOCAL_FALLBACK",
) -> Dict[str, Any]:
    """Generate fallback current weather data."""
    location = build_local_weather_location(query=city, lat=lat, lon=lon)
    local_now = datetime.datetime.now(datetime.timezone(datetime.timedelta(seconds=WEATHER_TIMEZONE_OFFSET)))
    seed_base = f"{location['name']}|{location['lat']}|{location['lon']}|{local_now.date().isoformat()}"
    cloud_cover = int(18 + _weather_hash_unit(f"{seed_base}|clouds") * 75)
    humidity = int(54 + _weather_hash_unit(f"{seed_base}|humidity") * 42)
    rainfall_mm = round(max(0.0, (cloud_cover - 58) / 14 + _weather_hash_unit(f"{seed_base}|rain") * 3.4 - 1.2), 1)
    temperature = round(21 + _weather_hash_unit(f"{seed_base}|temp") * 15 - abs(float(location["lat"]) - 20) * 0.06, 1)
    feels_like = round(temperature + humidity / 100 * 2.8 + rainfall_mm * 0.15, 1)
    pressure = int(1002 + _weather_hash_unit(f"{seed_base}|pressure") * 16)
    wind_speed = round(3 + _weather_hash_unit(f"{seed_base}|wind_speed") * 16, 1)
    wind_direction = int(_weather_hash_unit(f"{seed_base}|wind_deg") * 360)
    visibility = int(max(3200, 10000 - cloud_cover * 48 - rainfall_mm * 420))
    sunrise = int(local_now.replace(hour=6, minute=7, second=0, microsecond=0).timestamp())
    sunset = int(local_now.replace(hour=18, minute=36, second=0, microsecond=0).timestamp())
    is_daytime = sunrise <= int(local_now.timestamp()) <= sunset
    descriptor = build_weather_descriptor(rainfall_mm, cloud_cover, humidity, is_daytime)

    payload: Dict[str, Any] = {
        "coord": {"lon": location["lon"], "lat": location["lat"]},
        "weather": [
            {
                "id": 800 if descriptor["main"] == "Clear" else 801 if descriptor["main"] == "Clouds" else 701 if descriptor["main"] == "Mist" else 500,
                "main": descriptor["main"],
                "description": descriptor["description"],
                "icon": descriptor["icon"],
            }
        ],
        "base": "fallback",
        "main": {
            "temp": temperature,
            "feels_like": feels_like,
            "temp_min": round(temperature - 1.8, 1),
            "temp_max": round(temperature + 2.4, 1),
            "pressure": pressure,
            "humidity": humidity,
        },
        "visibility": visibility,
        "wind": {"speed": wind_speed, "deg": wind_direction},
        "clouds": {"all": cloud_cover},
        "dt": int(local_now.timestamp()),
        "sys": {
            "country": location["country"],
            "sunrise": sunrise,
            "sunset": sunset,
        },
        "timezone": WEATHER_TIMEZONE_OFFSET,
        "id": int(_weather_hash_unit(f"{seed_base}|id") * 100000),
        "name": location["name"],
        "cod": 200,
        "_weather_meta": {
            "source": "LOCAL_FALLBACK",
            "reason": reason,
            "state": location.get("state"),
        },
    }

    if rainfall_mm > 0:
        payload["rain"] = {
            "1h": rainfall_mm,
            "3h": round(rainfall_mm * (1.7 + _weather_hash_unit(f"{seed_base}|rain_3h") * 0.6), 1),
        }

    return payload

def build_fallback_forecast(city: str | None = None, lat: float | None = None, lon: float | None = None) -> Dict[str, Any]:
    """Generate fallback forecast data."""
    location = build_local_weather_location(query=city, lat=lat, lon=lon)
    base_weather = build_fallback_current_weather(city=location["name"], lat=location["lat"], lon=location["lon"])
    local_now = datetime.datetime.now(datetime.timezone(datetime.timedelta(seconds=WEATHER_TIMEZONE_OFFSET)))
    forecast_rows = []

    for day_index in range(5):
        day_seed = f"{location['name']}|forecast|{local_now.date().isoformat()}|{day_index}"
        midday = (local_now + datetime.timedelta(days=day_index)).replace(hour=12, minute=0, second=0, microsecond=0)
        temp_base = float(base_weather["main"]["temp"]) + (day_index - 1.5) * 0.5 + (_weather_hash_unit(f"{day_seed}|temp") - 0.5) * 3.2
        temp_min = round(temp_base - (1.4 + _weather_hash_unit(f"{day_seed}|temp_min") * 1.8), 1)
        temp_max = round(temp_base + (1.8 + _weather_hash_unit(f"{day_seed}|temp_max") * 2.2), 1)
        humidity = int(52 + _weather_hash_unit(f"{day_seed}|humidity") * 40)
        cloud_cover = int(20 + _weather_hash_unit(f"{day_seed}|clouds") * 70)
        rainfall_mm = round(max(0.0, (cloud_cover - 55) / 12 + _weather_hash_unit(f"{day_seed}|rain") * 4.2 - 1.5), 1)
        descriptor = build_weather_descriptor(rainfall_mm, cloud_cover, humidity, True)

        forecast_rows.append(
            {
                "dt": int(midday.timestamp()),
                "main": {
                    "temp_min": temp_min,
                    "temp_max": temp_max,
                    "humidity": humidity,
                    "pressure": int(1001 + _weather_hash_unit(f"{day_seed}|pressure") * 18),
                },
                "weather": [
                    {
                        "main": descriptor["main"],
                        "description": descriptor["description"],
                        "icon": descriptor["icon"],
                    }
                ],
                "wind": {"speed": round(3 + _weather_hash_unit(f"{day_seed}|wind") * 14, 1)},
                "pop": min(1.0, round(rainfall_mm / 12, 2)),
                "rain": {"3h": rainfall_mm},
            }
        )

    return {
        "cod": "200",
        "list": forecast_rows,
        "city": {
            "name": location["name"],
            "country": location["country"],
            "timezone": WEATHER_TIMEZONE_OFFSET,
            "coord": {"lat": location["lat"], "lon": location["lon"]},
        },
        "_weather_meta": {
            "source": "LOCAL_FALLBACK",
            "state": location.get("state"),
        },
    }

def build_fallback_search_results(query: str, limit: int = 5) -> list[Dict[str, Any]]:
    """Generate fallback search results."""
    results: list[Dict[str, Any]] = []
    seen: set[tuple[str, float, float]] = set()

    for candidate in build_weather_lookup_candidates(query):
        location = build_local_weather_location(query=candidate)
        identity = (location["name"], location["lat"], location["lon"])
        if identity in seen:
            continue
        seen.add(identity)
        results.append(
            {
                "name": location["name"],
                "lat": location["lat"],
                "lon": location["lon"],
                "country": location["country"],
                "state": location.get("state"),
                "_weather_meta": {"source": "LOCAL_FALLBACK"},
            }
        )
        if len(results) >= limit:
            break

    if not results:
        location = build_local_weather_location(query=query)
        results.append(
            {
                "name": location["name"],
                "lat": location["lat"],
                "lon": location["lon"],
                "country": location["country"],
                "state": location.get("state"),
                "_weather_meta": {"source": "LOCAL_FALLBACK"},
            }
        )

    return results[:limit]

def build_fallback_reverse_geocode(lat: float, lon: float, limit: int = 1) -> list[Dict[str, Any]]:
    """Generate fallback reverse geocode results."""
    location = build_local_weather_location(lat=lat, lon=lon)
    return [
        {
            "name": location["name"],
            "lat": round(float(lat), 4),
            "lon": round(float(lon), 4),
            "country": location["country"],
            "state": location.get("state"),
            "_weather_meta": {"source": "LOCAL_FALLBACK"},
        }
    ][:limit]

def build_fallback_air_quality(lat: float, lon: float) -> Dict[str, Any]:
    """Generate fallback air quality data."""
    seed_base = f"{round(lat, 3)}|{round(lon, 3)}|air"
    aqi = min(5, max(1, int(1 + _weather_hash_unit(f"{seed_base}|aqi") * 3.4)))
    pm25 = round(18 + _weather_hash_unit(f"{seed_base}|pm25") * 46, 1)
    pm10 = round(pm25 + 12 + _weather_hash_unit(f"{seed_base}|pm10") * 35, 1)
    return {
        "coord": {"lat": lat, "lon": lon},
        "list": [
            {
                "main": {"aqi": aqi},
                "components": {
                    "pm2_5": pm25,
                    "pm10": pm10,
                    "no2": round(9 + _weather_hash_unit(f"{seed_base}|no2") * 28, 1),
                    "so2": round(4 + _weather_hash_unit(f"{seed_base}|so2") * 14, 1),
                    "o3": round(24 + _weather_hash_unit(f"{seed_base}|o3") * 52, 1),
                    "co": round(180 + _weather_hash_unit(f"{seed_base}|co") * 420, 1),
                },
                "dt": int(datetime.datetime.utcnow().timestamp()),
            }
        ],
        "_weather_meta": {"source": "LOCAL_FALLBACK"},
    }

def build_fallback_uv_index(lat: float, lon: float) -> float:
    """Generate fallback UV index."""
    base = 4.2 + _weather_hash_unit(f"{round(lat, 3)}|{round(lon, 3)}|uv") * 5.4
    return round(min(11.0, max(0.8, base)), 1)

def build_fallback_historical_weather(lat: float, lon: float, timestamp: int) -> Dict[str, Any]:
    """Generate fallback historical weather data."""
    local_weather = build_fallback_current_weather(lat=lat, lon=lon, reason="LOCAL_HISTORY")
    return {
        "lat": lat,
        "lon": lon,
        "timezone": WEATHER_TIMEZONE_NAME,
        "timezone_offset": WEATHER_TIMEZONE_OFFSET,
        "data": [
            {
                "dt": timestamp,
                "sunrise": local_weather["sys"]["sunrise"],
                "sunset": local_weather["sys"]["sunset"],
                "temp": local_weather["main"]["temp"],
                "feels_like": local_weather["main"]["feels_like"],
                "pressure": local_weather["main"]["pressure"],
                "humidity": local_weather["main"]["humidity"],
                "dew_point": round(local_weather["main"]["temp"] - 3.2, 1),
                "clouds": local_weather["clouds"]["all"],
                "visibility": local_weather["visibility"],
                "wind_speed": local_weather["wind"]["speed"],
                "wind_deg": local_weather["wind"]["deg"],
                "weather": local_weather["weather"],
                "rain": local_weather.get("rain", {}),
            }
        ],
        "_weather_meta": {"source": "LOCAL_FALLBACK"},
    }
