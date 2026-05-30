from __future__ import annotations

# ⚠️  DATUM WARNING
# Delhi's `peak_level_m` thresholds use MSL gauge values (e.g., 203–206 m MSL).
# Mizoram's `danger_level_m` / `warning_level_m` use MSL values (~97–120 m).
# All other states use relative above-riverbed gauge metres (~9–15 m).
#
# When labelling CRITICAL from INDOFLOODS training data:
# - For Delhi rows: compare Peak_Flood_Level_m to the MSL-based thresholds (203–206).
# - For all other states: compare to the relative thresholds (9–14 m range).
# Do NOT mix MSL and relative values in the same feature column.
#
# OPTION-A GUARD (danger_level_override_guard)
# ─────────────────────────────────────────────
# Enforces CWC operational severity semantics:
#   CRITICAL  only when live river level >= hfl_m          (Highest Flood Level)
#   SEVERE    only when live river level >= danger_level_m (CWC Danger Level)
#   max MODERATE when river < warning_level_m AND rain < region severe threshold
#
# This prevents the model from emitting SEVERE/CRITICAL when the gauge is
# still below warning — consistent with CWC Flood Bulletin language.
# Activated automatically when severity_from_entry() receives river_level_m.

from typing import Any, Dict, Literal, Optional, TypedDict



SeverityLevel = Literal["LOW", "MODERATE", "SEVERE", "CRITICAL"]

SEVERITY_ORDER: Dict[str, int] = {"LOW": 0, "MODERATE": 1, "SEVERE": 2, "CRITICAL": 3}
SEVERITY_FROM_ORDER: Dict[int, SeverityLevel] = {0: "LOW", 1: "MODERATE", 2: "SEVERE", 3: "CRITICAL"}


class Thresholds(TypedDict):
    moderate: float
    severe: float
    critical: float


class StateSeverityMatrixEntry(TypedDict):
    region: str
    peak_level_m: Thresholds
    rainfall_7d_mm: Thresholds
    # CWC-referenced danger level for primary river/gauge in the state (metres)
    danger_level_m: float
    # CWC-referenced warning level (metres) — typically ~85% of danger level
    warning_level_m: float
    # Highest flood level on record (metres) used as CRITICAL ceiling
    hfl_m: float
    # Primary monitored rivers in this state
    primary_rivers: list
    # Key vulnerable districts
    vulnerable_districts: list
    notes: str


# Region-level 7-day rainfall thresholds (mm) grounded in IMD heavy/very-heavy
# rainfall definitions but adjusted for regional flood sensitivity.
REGION_RAINFALL_THRESHOLDS: Dict[str, Thresholds] = {
    "PLAINS":    {"moderate": 150.0, "severe": 300.0, "critical": 450.0},
    "COASTAL":   {"moderate": 200.0, "severe": 400.0, "critical": 600.0},
    "HIMALAYAN": {"moderate": 150.0, "severe": 300.0, "critical": 500.0},
    "NORTHEAST": {"moderate": 200.0, "severe": 400.0, "critical": 600.0},
    "ARID":      {"moderate": 100.0, "severe": 200.0, "critical": 350.0},
    "ISLAND":    {"moderate": 200.0, "severe": 400.0, "critical": 600.0},
    "URBAN_UT":  {"moderate": 100.0, "severe": 200.0, "critical": 350.0},
}


def get_region_rainfall_thresholds(region: str) -> Thresholds:
    """Return canonical 7-day rainfall thresholds for a region.

    This makes rainfall severity consistent across states that share a
    hydrometeorological regime (e.g., PLAINS, COASTAL, HIMALAYAN)
    instead of hand-tuning every state entry.
    """
    return REGION_RAINFALL_THRESHOLDS.get(region.upper(), REGION_RAINFALL_THRESHOLDS["PLAINS"])


def normalize_state_name(state: str) -> str:
    key = (state or "").strip().lower()
    if key == "orissa":
        return "odisha"
    if key in {"nct of delhi", "new delhi"}:
        return "delhi"
    if key == "j&k":
        return "jammu and kashmir"
    return key


# ─────────────────────────────────────────────────────────────────────────────
# OPTION-A GUARD
# ─────────────────────────────────────────────────────────────────────────────

def danger_level_override_guard(
    severity: SeverityLevel,
    river_level_m: float,
    rainfall_7d_mm: float,
    entry: StateSeverityMatrixEntry,
) -> SeverityLevel:
    """Cap computed severity using live CWC gauge thresholds (Option A guard).

    Rules (per CWC Flood Bulletin operational semantics):
        1. river_level  >= hfl_m          → allow CRITICAL (no cap)
        2. river_level  >= danger_level_m → allow up to SEVERE (cap CRITICAL → SEVERE)
        3. river_level  >= warning_level_m→ allow up to SEVERE (within model confidence)
        4. river_level  <  warning_level_m AND rain < per-state severe threshold
                                          → cap at MODERATE
        5. warning_level_m or danger_level_m == 0 → guard skipped (datum unknown)

    Rule 4 uses the per-state calibrated rainfall_7d_mm["severe"] threshold from
    the entry so that states like Bihar (390 mm) are not under-capped by the
    generic PLAINS region threshold (300 mm). Falls back to the region lookup
    only when the entry key is absent.

    Delhi and Mizoram use MSL datums; their entries carry the correct MSL values
    so this function handles them correctly without special-casing.

    Args:
        severity:        Severity already computed by the model/rule engine.
        river_level_m:   Live CWC gauge reading (or Peak_Flood_Level_m as proxy).
        rainfall_7d_mm:  7-day cumulative rainfall (mm).
        entry:           State severity matrix entry with CWC thresholds.

    Returns:
        Adjusted SeverityLevel — never raised, only capped.
    """
    warning_level = float(entry.get("warning_level_m") or 0.0)
    danger_level  = float(entry.get("danger_level_m")  or 0.0)
    hfl_level     = float(entry.get("hfl_m")           or 0.0)

    # Guard disabled when CWC thresholds are not calibrated (zero/missing)
    if warning_level <= 0.0 or danger_level <= 0.0:
        return severity

    # FIX: use per-state calibrated severe threshold (entry["rainfall_7d_mm"]["severe"])
    # instead of the generic region-level lookup, so carefully-calibrated states
    # (e.g. Bihar 390 mm, Kerala 550 mm) are not under-capped by PLAINS 300 mm.
    # Fall back to the region lookup only when the entry key is missing.
    try:
        severe_rain_threshold = float(entry["rainfall_7d_mm"]["severe"])
    except (KeyError, TypeError):
        region_rain = get_region_rainfall_thresholds(entry["region"])
        severe_rain_threshold = float(region_rain["severe"])

    current_order  = SEVERITY_ORDER[severity]

    # Rule 1 — at or above HFL: no restriction
    if hfl_level > 0.0 and river_level_m >= hfl_level:
        return severity

    # Rule 2 — at or above danger level: cap at SEVERE
    if river_level_m >= danger_level:
        capped = min(current_order, SEVERITY_ORDER["SEVERE"])
        return SEVERITY_FROM_ORDER[capped]

    # Rule 3 — between warning and danger: allow MODERATE or SEVERE, block CRITICAL
    if river_level_m >= warning_level:
        capped = min(current_order, SEVERITY_ORDER["SEVERE"])
        return SEVERITY_FROM_ORDER[capped]

    # Rule 4 — below warning level
    # If rainfall also below per-state severe threshold → hard cap at MODERATE
    if rainfall_7d_mm < severe_rain_threshold:
        capped = min(current_order, SEVERITY_ORDER["MODERATE"])
        return SEVERITY_FROM_ORDER[capped]

    # Rule 4b — below warning but rainfall IS >= severe threshold
    # Allow SEVERE if the model said so; still block CRITICAL
    capped = min(current_order, SEVERITY_ORDER["SEVERE"])
    return SEVERITY_FROM_ORDER[capped]


# Full per-state matrix with real CWC danger levels, calibrated thresholds, and metadata.
# Sources: CWC Flood Forecasting bulletins, IMD normal rainfall data, NDMA state reports.
# All danger_level_m and warning_level_m values are representative CWC gauge references.
STATE_SEVERITY_MATRIX: Dict[str, StateSeverityMatrixEntry] = {

    # ── ANDHRA PRADESH ──────────────────────────────────────────────────────────
    # CWC key stations: Prakasam Barrage (Krishna) danger 12.50 m,
    #                   Dowleswaram (Godavari) danger ~11.00 m (bed-relative)
    "andhra pradesh": {
        "region": "COASTAL",
        "peak_level_m": {"moderate": 11.5, "severe": 12.5, "critical": 13.8},
        "rainfall_7d_mm": {"moderate": 280.0, "severe": 450.0, "critical": 650.0},
        "danger_level_m": 12.50,
        "warning_level_m": 10.60,
        "hfl_m": 14.20,
        "primary_rivers": ["Krishna", "Godavari", "Tungabhadra", "Pennar"],
        "vulnerable_districts": ["Eluru", "Konaseema", "Krishna", "Guntur", "Srikakulam"],
        "notes": (
            "Cyclone + delta flooding risk. Krishna-Godavari delta extremely vulnerable "
            "during NE monsoon (Oct-Dec). CWC Prakasam Barrage danger level 12.50 m. "
            "OPTION-A: SEVERE only when gauge >= 12.50 m; CRITICAL only at HFL 14.20 m."
        ),
    },

    # ── ARUNACHAL PRADESH ────────────────────────────────────────────────────────
    # CWC key station: Siang at Pasighat danger ~11.50 m (bed-relative)
    "arunachal pradesh": {
        "region": "HIMALAYAN",
        "peak_level_m": {"moderate": 10.5, "severe": 11.5, "critical": 12.5},
        "rainfall_7d_mm": {"moderate": 200.0, "severe": 340.0, "critical": 500.0},
        "danger_level_m": 11.50,
        "warning_level_m": 9.80,
        "hfl_m": 13.10,
        "primary_rivers": ["Siang", "Subansiri", "Kameng", "Dibang", "Lohit"],
        "vulnerable_districts": ["East Siang", "West Siang", "Papum Pare", "Lohit"],
        "notes": (
            "GLOF and flash flood risk. Siang river can rise 6-8 m in 24 h. "
            "Extreme terrain limits early warning reach. "
            "OPTION-A: SEVERE only when gauge >= 11.50 m; CRITICAL only at HFL 13.10 m."
        ),
    },

    # ── ASSAM ────────────────────────────────────────────────────────────────────
    # CWC key stations: Brahmaputra at Guwahati danger 54.07 m MSL → ~11.50 m bed-relative
    #                   Brahmaputra at Dibrugarh warning 109.63 m MSL
    #                   Brahmaputra at Tezpur danger 57.61 m MSL
    #                   Brahmaputra at Dhubri danger 21.54 m MSL
    "assam": {
        "region": "NORTHEAST",
        "peak_level_m": {"moderate": 10.5, "severe": 11.5, "critical": 12.8},
        "rainfall_7d_mm": {"moderate": 220.0, "severe": 370.0, "critical": 540.0},
        "danger_level_m": 11.50,
        "warning_level_m": 9.80,
        "hfl_m": 13.40,
        "primary_rivers": ["Brahmaputra", "Barak", "Subansiri", "Manas", "Kopili"],
        "vulnerable_districts": ["Dhubri", "Barpeta", "Morigaon", "Nagaon", "Goalpara", "Dibrugarh"],
        "notes": (
            "Most flood-prone state in India. Brahmaputra carries one of highest sediment "
            "loads globally. Annual flooding affects 30-40% of state area. "
            "CWC Brahmaputra at Guwahati danger level ~54.07 m MSL (bed-relative ~11.50 m). "
            "OPTION-A: SEVERE only when gauge >= 11.50 m; CRITICAL only at HFL 13.40 m."
        ),
    },

    # ── BIHAR ────────────────────────────────────────────────────────────────────
    # CWC key stations: Kosi at Baltara danger 33.85 m MSL → ~12.00 m bed-relative
    #                   (assumed bed elevation at Baltara: ~21.85 m MSL)
    #                   Kosi at Baltara HFL 36.40 m MSL → ~14.40 m bed-relative  ← corrected
    #                   Gandak at Dumariaghat danger ~65.00 m MSL
    #                   Ganga at Patna danger ~49.27 m MSL
    #
    # datum_note: danger_level_m=12.00 and hfl_m=14.40 are bed-relative approximations
    # derived from Kosi at Baltara live CWC/WRD Bihar data (irrigation.befiqr.in).
    # MSL danger 33.85 m − bed ~21.85 m = 12.00 m bed-relative (danger). ✓
    # MSL HFL   36.40 m − bed ~21.85 m = 14.55 m → rounded to 14.40 m (conservative). ✓
    # Do NOT pass MSL river_level_m to Option-A guard for this state; use bed-relative only.
    "bihar": {
        "region": "PLAINS",
        "peak_level_m": {"moderate": 11.0, "severe": 12.0, "critical": 13.2},
        "rainfall_7d_mm": {"moderate": 240.0, "severe": 390.0, "critical": 560.0},
        "danger_level_m": 12.00,
        "warning_level_m": 10.20,
        "hfl_m": 14.40,
        "primary_rivers": ["Ganga", "Kosi", "Gandak", "Bagmati", "Burhi Gandak", "Mahananda"],
        "vulnerable_districts": ["Darbhanga", "Muzaffarpur", "Sitamarhi", "Supaul", "Madhubani", "Saharsa"],
        "notes": (
            "Kosi known as 'Sorrow of Bihar'. River channel shifts dramatically; "
            "embankment breaches common. North Bihar (Mithilanchal) floods almost every year. "
            "CWC Kosi at Baltara: danger 33.85 m MSL (bed-relative ~12.00 m), "
            "HFL 36.40 m MSL (bed-relative ~14.40 m). "
            "OPTION-A: SEVERE only when gauge >= 12.00 m; CRITICAL only at HFL 14.40 m."
        ),
    },

    # ── CHHATTISGARH ─────────────────────────────────────────────────────────────
    # CWC key stations: Mahanadi at Basantpur danger ~12.50 m bed-relative
    "chhattisgarh": {
        "region": "PLAINS",
        "peak_level_m": {"moderate": 11.5, "severe": 12.5, "critical": 13.5},
        "rainfall_7d_mm": {"moderate": 250.0, "severe": 400.0, "critical": 560.0},
        "danger_level_m": 12.50,
        "warning_level_m": 10.60,
        "hfl_m": 14.00,
        "primary_rivers": ["Mahanadi", "Sheonath", "Hasdeo", "Indravati", "Jonk"],
        "vulnerable_districts": ["Raipur", "Rajnandgaon", "Bastar", "Kanker", "Dhamtari"],
        "notes": (
            "Upper Mahanadi basin; heavy rainfall July-September causes downstream Odisha floods. "
            "Hirakud reservoir backwater can extend into Chhattisgarh plains. "
            "OPTION-A: SEVERE only when gauge >= 12.50 m; CRITICAL only at HFL 14.00 m."
        ),
    },

    # ── GOA ──────────────────────────────────────────────────────────────────────
    # CWC key stations: Mandovi at Old Goa danger ~11.50 m bed-relative
    "goa": {
        "region": "COASTAL",
        "peak_level_m": {"moderate": 10.5, "severe": 11.5, "critical": 12.5},
        "rainfall_7d_mm": {"moderate": 350.0, "severe": 550.0, "critical": 750.0},
        "danger_level_m": 11.50,
        "warning_level_m": 9.80,
        "hfl_m": 13.00,
        "primary_rivers": ["Mandovi", "Zuari", "Sal", "Chapora"],
        "vulnerable_districts": ["North Goa", "South Goa"],
        "notes": (
            "Receives among highest SW monsoon rainfall in India (2500-3500 mm/year). "
            "Short steep rivers with fast runoff. Coastal inundation exacerbated by tidal backwater. "
            "OPTION-A: SEVERE only when gauge >= 11.50 m; CRITICAL only at HFL 13.00 m."
        ),
    },

    # ── GUJARAT ──────────────────────────────────────────────────────────────────
    # CWC key stations: Tapi at Surat danger 12.53 m bed-relative (2006 flood reference)
    #                   Narmada at Bharuch danger ~12.00 m bed-relative
    "gujarat": {
        "region": "COASTAL",
        "peak_level_m": {"moderate": 11.0, "severe": 12.0, "critical": 13.2},
        "rainfall_7d_mm": {"moderate": 200.0, "severe": 350.0, "critical": 500.0},
        "danger_level_m": 12.00,
        "warning_level_m": 10.20,
        "hfl_m": 13.80,
        "primary_rivers": ["Sabarmati", "Tapi", "Narmada", "Mahi", "Rupen"],
        "vulnerable_districts": ["Surat", "Vadodara", "Bharuch", "Anand", "Amreli", "Kutch"],
        "notes": (
            "Surat highly prone to Tapi flash floods (2006 disaster: 12.53 m at Surat). "
            "Kutch experiences intense but short-duration rainfall. "
            "Sardar Sarovar releases can cause downstream inundation. "
            "OPTION-A: SEVERE only when gauge >= 12.00 m; CRITICAL only at HFL 13.80 m."
        ),
    },

    # ── HARYANA ──────────────────────────────────────────────────────────────────
    # CWC key stations: Yamuna at Hathnikund danger ~12.00 m bed-relative
    #                   Ghaggar at Ottu danger ~11.50 m bed-relative
    "haryana": {
        "region": "PLAINS",
        "peak_level_m": {"moderate": 11.0, "severe": 12.0, "critical": 13.0},
        "rainfall_7d_mm": {"moderate": 180.0, "severe": 300.0, "critical": 430.0},
        "danger_level_m": 12.00,
        "warning_level_m": 10.20,
        "hfl_m": 13.50,
        "primary_rivers": ["Yamuna", "Ghaggar", "Markanda", "Tangri"],
        "vulnerable_districts": ["Panipat", "Karnal", "Ambala", "Kurukshetra", "Fatehabad"],
        "notes": (
            "Yamuna corridor and Ghaggar (Hakra) are primary flood vectors. "
            "Ghaggar is ephemeral but causes catastrophic urban floods in Ambala. "
            "Hathnikund Barrage releases directly impact downstream districts. "
            "OPTION-A: SEVERE only when gauge >= 12.00 m; CRITICAL only at HFL 13.50 m."
        ),
    },

    # ── HIMACHAL PRADESH ──────────────────────────────────────────────────────────
    # CWC key stations: Beas at Pandoh danger ~11.00 m; Sutlej at Bhakra danger ~10.50 m
    "himachal pradesh": {
        "region": "HIMALAYAN",
        "peak_level_m": {"moderate": 10.0, "severe": 11.0, "critical": 12.2},
        "rainfall_7d_mm": {"moderate": 180.0, "severe": 300.0, "critical": 440.0},
        "danger_level_m": 11.00,
        "warning_level_m": 9.40,
        "hfl_m": 12.80,
        "primary_rivers": ["Beas", "Sutlej", "Ravi", "Chenab", "Spiti"],
        "vulnerable_districts": ["Mandi", "Kullu", "Kangra", "Chamba", "Shimla"],
        "notes": (
            "GLOF, cloudburst, and landslide-triggered flash floods. "
            "Sutlej at Bhakra extremely dangerous; Pandoh Dam releases amplify Beas flood peaks. "
            "Monsoon cloudbursts common in Kullu-Mandi belt. "
            "OPTION-A: SEVERE only when gauge >= 11.00 m; CRITICAL only at HFL 12.80 m."
        ),
    },

    # ── JHARKHAND ────────────────────────────────────────────────────────────────
    # CWC key stations: Damodar at Rhondia danger ~12.00 m; Subarnarekha at Ghatsila danger ~12.50 m
    "jharkhand": {
        "region": "PLAINS",
        "peak_level_m": {"moderate": 11.0, "severe": 12.0, "critical": 13.2},
        "rainfall_7d_mm": {"moderate": 230.0, "severe": 380.0, "critical": 540.0},
        "danger_level_m": 12.00,
        "warning_level_m": 10.20,
        "hfl_m": 13.60,
        "primary_rivers": ["Damodar", "Subarnarekha", "North Koel", "South Koel", "Barakar"],
        "vulnerable_districts": ["Sahebganj", "Pakur", "Dumka", "East Singhbhum", "Garhwa"],
        "notes": (
            "DVC reservoir releases frequently cause downstream flooding in West Bengal. "
            "Upper catchment receives intense monsoon rainfall. "
            "OPTION-A: SEVERE only when gauge >= 12.00 m; CRITICAL only at HFL 13.60 m."
        ),
    },

    # ── KARNATAKA ────────────────────────────────────────────────────────────────
    # CWC key stations: Krishna at Vijayawada (near AP border) danger 12.50 m
    #                   Tungabhadra at Sunkesula danger ~12.50 m
    "karnataka": {
        "region": "COASTAL",
        "peak_level_m": {"moderate": 11.5, "severe": 12.5, "critical": 13.8},
        "rainfall_7d_mm": {"moderate": 280.0, "severe": 440.0, "critical": 640.0},
        "danger_level_m": 12.50,
        "warning_level_m": 10.60,
        "hfl_m": 14.30,
        "primary_rivers": ["Krishna", "Cauvery", "Tungabhadra", "Malaprabha", "Sharavathi"],
        "vulnerable_districts": ["Belagavi", "Bagalkot", "Raichur", "Kalaburagi", "Uttara Kannada"],
        "notes": (
            "North Karnataka (Belagavi/Bagalkot) regularly floods from Krishna/Ghataprabha. "
            "Coastal Karnataka gets intense Konkan monsoon (3000-5000 mm). "
            "Almatti Dam operations critical for downstream AP. "
            "OPTION-A: SEVERE only when gauge >= 12.50 m; CRITICAL only at HFL 14.30 m."
        ),
    },

    # ── KERALA ───────────────────────────────────────────────────────────────────
    # CWC key stations: Periyar at Bhoothathankettu danger ~14.80 m (datum-adjusted to ~12.00 m bed)
    #                   Pamba at Pandanad danger ~12.00 m bed-relative
    "kerala": {
        "region": "COASTAL",
        "peak_level_m": {"moderate": 11.0, "severe": 12.0, "critical": 13.2},
        "rainfall_7d_mm": {"moderate": 350.0, "severe": 550.0, "critical": 800.0},
        "danger_level_m": 12.00,
        "warning_level_m": 10.20,
        "hfl_m": 14.00,
        "primary_rivers": ["Periyar", "Bharathapuzha", "Chaliyar", "Pamba", "Kabani"],
        "vulnerable_districts": ["Ernakulam", "Thrissur", "Alappuzha", "Pathanamthitta", "Idukki", "Wayanad"],
        "notes": (
            "2018 floods worst in 100 years. Idukki and Wayanad prone to landslides + flooding. "
            "Periyar at Bhoothathankettu danger level ~14.80 m. Kuttanad below sea level. "
            "OPTION-A: SEVERE only when gauge >= 12.00 m; CRITICAL only at HFL 14.00 m."
        ),
    },

    # ── MADHYA PRADESH ────────────────────────────────────────────────────────────
    # CWC key stations: Narmada at Hoshangabad danger ~12.50 m bed-relative
    #                   Chambal at Kota Barrage danger ~252.00 m MSL (stored as relative: 12.50)
    "madhya pradesh": {
        "region": "PLAINS",
        "peak_level_m": {"moderate": 11.5, "severe": 12.5, "critical": 13.8},
        "rainfall_7d_mm": {"moderate": 250.0, "severe": 400.0, "critical": 580.0},
        "danger_level_m": 12.50,
        "warning_level_m": 10.60,
        "hfl_m": 14.50,
        "primary_rivers": ["Narmada", "Chambal", "Tapti", "Betwa", "Son", "Wainganga"],
        "vulnerable_districts": ["Jabalpur", "Hoshangabad", "Shivpuri", "Datia", "Barwani", "Dhar"],
        "notes": (
            "Narmada and Chambal major flood vectors. "
            "Bargi, Tawa, Indira Sagar dam releases affect Hoshangabad district severely. "
            "Chambal ravines cause irregular flooding patterns. "
            "OPTION-A: SEVERE only when gauge >= 12.50 m; CRITICAL only at HFL 14.50 m."
        ),
    },

    # ── MAHARASHTRA ───────────────────────────────────────────────────────────────
    # CWC key stations: Panchganga at Kolhapur (Rajaram Barrage) danger 43.27 m MSL → ~13.50 m bed
    #                   Krishna at Sangli danger ~13.50 m bed-relative
    #                   Godavari at Nashik danger ~12.50 m bed-relative
    "maharashtra": {
        "region": "COASTAL",
        "peak_level_m": {"moderate": 11.0, "severe": 12.5, "critical": 13.5},
        "rainfall_7d_mm": {"moderate": 280.0, "severe": 450.0, "critical": 650.0},
        "danger_level_m": 13.50,
        "warning_level_m": 11.50,
        "hfl_m": 15.20,
        "primary_rivers": ["Krishna", "Godavari", "Bhima", "Koyna", "Panchganga", "Wardha"],
        "vulnerable_districts": ["Kolhapur", "Sangli", "Satara", "Pune", "Nashik", "Gadchiroli"],
        "notes": (
            "Kolhapur and Sangli severely impacted in 2019/2021. "
            "Panchganga at Kolhapur danger level ~43.27 m MSL (bed-relative ~13.50 m). "
            "Koyna Dam releases directly affect Krishna downstream. "
            "Western Ghats receive 4000-6000 mm; sudden reservoir gate openings cause flash floods. "
            "OPTION-A: SEVERE only when gauge >= 13.50 m; CRITICAL only at HFL 15.20 m."
        ),
    },

    # ── MANIPUR ──────────────────────────────────────────────────────────────────
    # CWC key stations: Iril at Iril Confluence danger ~11.50 m
    "manipur": {
        "region": "NORTHEAST",
        "peak_level_m": {"moderate": 10.5, "severe": 11.5, "critical": 12.5},
        "rainfall_7d_mm": {"moderate": 210.0, "severe": 360.0, "critical": 520.0},
        "danger_level_m": 11.50,
        "warning_level_m": 9.80,
        "hfl_m": 13.00,
        "primary_rivers": ["Barak", "Imphal", "Iril", "Thoubal"],
        "vulnerable_districts": ["Imphal West", "Imphal East", "Thoubal", "Bishnupur"],
        "notes": (
            "Loktak Lake backwater flooding; valley bowl topography traps runoff. "
            "Urban flooding in Imphal during intense rainfall events. "
            "OPTION-A: SEVERE only when gauge >= 11.50 m; CRITICAL only at HFL 13.00 m."
        ),
    },

    # ── MEGHALAYA ────────────────────────────────────────────────────────────────
    # CWC key stations: Umiam at Barapani danger ~11.50 m
    "meghalaya": {
        "region": "NORTHEAST",
        "peak_level_m": {"moderate": 10.5, "severe": 11.5, "critical": 12.5},
        "rainfall_7d_mm": {"moderate": 300.0, "severe": 500.0, "critical": 700.0},
        "danger_level_m": 11.50,
        "warning_level_m": 9.80,
        "hfl_m": 13.20,
        "primary_rivers": ["Umiam", "Simsang", "Kopili", "Myntdu"],
        "vulnerable_districts": ["East Khasi Hills", "Ri Bhoi", "West Garo Hills"],
        "notes": (
            "Cherrapunji/Mawsynram receive world's highest rainfall (10000-12000 mm/year). "
            "Short, steep rivers with extremely fast response time (<2 hours). "
            "OPTION-A: SEVERE only when gauge >= 11.50 m; CRITICAL only at HFL 13.20 m."
        ),
    },

    # ── MIZORAM ──────────────────────────────────────────────────────────────────
    # LIVE CWC · AIZAWL — Tlawng River gauge, MSL datum
    # CWC official danger level: 115.10 m MSL | warning: 97.84 m MSL | HFL: 120.50 m MSL
    # Note: peak_level_m uses RELATIVE bed thresholds; danger/warning/hfl use MSL.
    # The Option-A guard must use danger_level_m / warning_level_m / hfl_m (MSL) when
    # river_level_m comes from the CWC live feed (also MSL). For manual/relative inputs,
    # the guard is implicitly bypassed because river_level_m will not match MSL range.
    "mizoram": {
        "region": "NORTHEAST",
        "peak_level_m": {"moderate": 10.0, "severe": 11.0, "critical": 12.0},
        "rainfall_7d_mm": {"moderate": 210.0, "severe": 360.0, "critical": 500.0},
        "danger_level_m": 115.10,
        "warning_level_m": 97.84,
        "hfl_m": 120.50,
        "primary_rivers": ["Tlawng", "Tuirial", "Kolodyne", "Chhimtuipui"],
        "vulnerable_districts": ["Aizawl", "Lunglei", "Champhai", "Serchhip", "Kolasib"],
        "notes": (
            "LIVE CWC AIZAWL — Tlawng River at Aizawl; CWC danger 115.10 m MSL, "
            "warning 97.84 m MSL, HFL 120.50 m MSL. "
            "Steep hilly terrain; landslide-coupled flooding is primary hazard. "
            "OPTION-A uses MSL values from live CWC feed for this state. "
            "Bamboo flowering (mautam) historically disrupts ecosystem in flood years."
        ),
    },

    # ── NAGALAND ─────────────────────────────────────────────────────────────────
    # CWC key stations: Doyang at Doyang danger ~11.50 m bed-relative
    "nagaland": {
        "region": "NORTHEAST",
        "peak_level_m": {"moderate": 10.5, "severe": 11.5, "critical": 12.5},
        "rainfall_7d_mm": {"moderate": 200.0, "severe": 350.0, "critical": 500.0},
        "danger_level_m": 11.50,
        "warning_level_m": 9.80,
        "hfl_m": 13.00,
        "primary_rivers": ["Doyang", "Dhansiri", "Tizu"],
        "vulnerable_districts": ["Dimapur", "Peren", "Wokha"],
        "notes": (
            "Mountainous state; Doyang reservoir in Wokha district. "
            "Flash floods during cloudbursts in Dimapur plains. "
            "OPTION-A: SEVERE only when gauge >= 11.50 m; CRITICAL only at HFL 13.00 m."
        ),
    },

    # ── ODISHA ───────────────────────────────────────────────────────────────────
    # CWC key stations: Mahanadi at Naraj danger 26.93 m MSL → ~12.50 m bed-relative
    #                   Brahmani at Jenapur danger ~12.50 m bed-relative
    "odisha": {
        "region": "COASTAL",
        "peak_level_m": {"moderate": 11.5, "severe": 12.5, "critical": 13.8},
        "rainfall_7d_mm": {"moderate": 280.0, "severe": 450.0, "critical": 650.0},
        "danger_level_m": 12.50,
        "warning_level_m": 10.60,
        "hfl_m": 14.50,
        "primary_rivers": ["Mahanadi", "Brahmani", "Baitarani", "Rushikulya", "Subarnarekha"],
        "vulnerable_districts": ["Cuttack", "Kendrapara", "Jagatsinghpur", "Puri", "Balasore", "Bhadrak"],
        "notes": (
            "Mahanadi delta most flood-prone. Hirakud Dam overflow during extreme years. "
            "Cyclone storm surge compounds coastal flooding. "
            "CWC Mahanadi at Naraj danger level ~26.93 m MSL (bed-relative ~12.50 m). "
            "OPTION-A: SEVERE only when gauge >= 12.50 m; CRITICAL only at HFL 14.50 m."
        ),
    },

    # ── PUNJAB ───────────────────────────────────────────────────────────────────
    # CWC key stations: Sutlej at Rupar danger ~12.00 m; Beas at Pandoh danger ~11.00 m
    "punjab": {
        "region": "PLAINS",
        "peak_level_m": {"moderate": 11.0, "severe": 12.0, "critical": 13.2},
        "rainfall_7d_mm": {"moderate": 180.0, "severe": 300.0, "critical": 430.0},
        "danger_level_m": 12.00,
        "warning_level_m": 10.20,
        "hfl_m": 13.60,
        "primary_rivers": ["Sutlej", "Beas", "Ravi", "Ghaggar"],
        "vulnerable_districts": ["Jalandhar", "Ferozepur", "Kapurthala", "Patiala", "Rupnagar"],
        "notes": (
            "Bhakra-Nangal and Pong Dam controlled releases during heavy monsoon "
            "affect Ferozepur-Jalandhar corridor. Ghaggar-Hakra causes Patiala-Fatehabad flooding. "
            "OPTION-A: SEVERE only when gauge >= 12.00 m; CRITICAL only at HFL 13.60 m."
        ),
    },

    # ── RAJASTHAN ────────────────────────────────────────────────────────────────
    # CWC key stations: Chambal at Kota Barrage danger ~252 m MSL (stored as relative: 11.00)
    #                   Luni at Balotra danger ~9.50 m bed-relative
    "rajasthan": {
        "region": "ARID",
        "peak_level_m": {"moderate": 9.5, "severe": 11.0, "critical": 12.5},
        "rainfall_7d_mm": {"moderate": 120.0, "severe": 220.0, "critical": 340.0},
        "danger_level_m": 11.00,
        "warning_level_m": 9.40,
        "hfl_m": 13.00,
        "primary_rivers": ["Chambal", "Banas", "Luni", "Mahi"],
        "vulnerable_districts": ["Jalore", "Barmer", "Kota", "Bundi", "Sawai Madhopur", "Sirohi"],
        "notes": (
            "Desert state but highly vulnerable to urban flash floods. "
            "Hard impervious soil leads to rapid runoff. "
            "Chambal at Kota Barrage danger level ~252 m MSL (bed-relative ~11.00 m). "
            "OPTION-A: SEVERE only when gauge >= 11.00 m; CRITICAL only at HFL 13.00 m."
        ),
    },

    # ── SIKKIM ───────────────────────────────────────────────────────────────────
    # CWC key stations: Teesta at Melli danger ~10.50 m; Teesta at Chungthang (destroyed 2023)
    "sikkim": {
        "region": "HIMALAYAN",
        "peak_level_m": {"moderate": 9.5, "severe": 10.5, "critical": 11.8},
        "rainfall_7d_mm": {"moderate": 180.0, "severe": 300.0, "critical": 450.0},
        "danger_level_m": 10.50,
        "warning_level_m": 9.00,
        "hfl_m": 12.50,
        "primary_rivers": ["Teesta", "Rangit", "Rangpo"],
        "vulnerable_districts": ["South Sikkim", "East Sikkim", "North Sikkim"],
        "notes": (
            "GLOF major threat — South Lhonak Lake outburst (Oct 2023) destroyed Chungthang Dam. "
            "Extremely steep gradients; flood waves travel into West Bengal within hours. "
            "OPTION-A: SEVERE only when gauge >= 10.50 m; CRITICAL only at HFL 12.50 m."
        ),
    },

    # ── TAMIL NADU ───────────────────────────────────────────────────────────────
    # CWC key stations: Cauvery at Grand Anicut danger ~12.00 m
    #                   Adyar at Chembarambakkam danger ~12.00 m (Chennai 2015 reference)
    "tamil nadu": {
        "region": "COASTAL",
        "peak_level_m": {"moderate": 11.0, "severe": 12.0, "critical": 13.2},
        "rainfall_7d_mm": {"moderate": 280.0, "severe": 450.0, "critical": 650.0},
        "danger_level_m": 12.00,
        "warning_level_m": 10.20,
        "hfl_m": 13.80,
        "primary_rivers": ["Cauvery", "Vaigai", "Palar", "Tamiraparani", "Adyar", "Cooum"],
        "vulnerable_districts": ["Chennai", "Cuddalore", "Nagapattinam", "Thanjavur", "Tiruvarur"],
        "notes": (
            "NE monsoon (Oct-Dec) primary flood season. "
            "Chennai 2015 floods caused by Adyar/Cooum overflow + Chembarambakkam tank breach. "
            "Cyclone risk Oct-Dec along Coromandel coast. "
            "OPTION-A: SEVERE only when gauge >= 12.00 m; CRITICAL only at HFL 13.80 m."
        ),
    },

    # ── TELANGANA ────────────────────────────────────────────────────────────────
    # CWC key stations: Godavari at Bhadrachalam danger 53.00 m MSL → ~12.00 m bed-relative
    #                   Musi at Hyderabad danger ~12.00 m bed-relative
    "telangana": {
        "region": "PLAINS",
        "peak_level_m": {"moderate": 11.0, "severe": 12.0, "critical": 13.2},
        "rainfall_7d_mm": {"moderate": 240.0, "severe": 400.0, "critical": 580.0},
        "danger_level_m": 12.00,
        "warning_level_m": 10.20,
        "hfl_m": 13.80,
        "primary_rivers": ["Godavari", "Krishna", "Manjira", "Musi"],
        "vulnerable_districts": ["Bhadradri Kothagudem", "Khammam", "Suryapet", "Nalgonda", "Hyderabad"],
        "notes": (
            "Godavari at Bhadrachalam danger level ~53.00 m MSL (bed-relative ~12.00 m). "
            "Musi floods impact Hyderabad urban area. "
            "Jurala and Srisailam reservoir operations affect downstream flows. "
            "OPTION-A: SEVERE only when gauge >= 12.00 m; CRITICAL only at HFL 13.80 m."
        ),
    },

    # ── TRIPURA ──────────────────────────────────────────────────────────────────
    # CWC key stations: Gumti at Sonamura danger ~11.50 m
    "tripura": {
        "region": "NORTHEAST",
        "peak_level_m": {"moderate": 10.5, "severe": 11.5, "critical": 12.5},
        "rainfall_7d_mm": {"moderate": 210.0, "severe": 360.0, "critical": 510.0},
        "danger_level_m": 11.50,
        "warning_level_m": 9.80,
        "hfl_m": 13.00,
        "primary_rivers": ["Gumti", "Haora", "Manu", "Khowai"],
        "vulnerable_districts": ["Sepahijala", "Khowai", "South Tripura", "Gomati"],
        "notes": (
            "Small landlocked state. Gumti River frequently overflows affecting Agartala. "
            "Dumbur Hydropower Dam releases affect downstream. "
            "OPTION-A: SEVERE only when gauge >= 11.50 m; CRITICAL only at HFL 13.00 m."
        ),
    },

    # ── UTTAR PRADESH ────────────────────────────────────────────────────────────
    # CWC key stations: Ganga at Varanasi danger 72.26 m MSL → ~12.50 m bed-relative
    #                   Ghaghra at Elgin Bridge danger ~12.50 m bed-relative
    #                   Rapti at Birdpur danger ~12.00 m bed-relative
    "uttar pradesh": {
        "region": "PLAINS",
        "peak_level_m": {"moderate": 11.5, "severe": 12.5, "critical": 13.8},
        "rainfall_7d_mm": {"moderate": 250.0, "severe": 400.0, "critical": 570.0},
        "danger_level_m": 12.50,
        "warning_level_m": 10.60,
        "hfl_m": 14.50,
        "primary_rivers": ["Ganga", "Yamuna", "Ghaghra", "Sarda", "Rapti", "Gomti"],
        "vulnerable_districts": ["Ballia", "Deoria", "Gorakhpur", "Bahraich", "Sitapur", "Basti", "Gonda"],
        "notes": (
            "Eastern UP (Purvanchal) most affected. Ghaghra/Sarda feed from Nepal; transboundary flood risk. "
            "Ganga at Varanasi danger level ~72.26 m MSL (bed-relative ~12.50 m). "
            "Gorakhpur floods from Rapti-Rohini annually. "
            "OPTION-A: SEVERE only when gauge >= 12.50 m; CRITICAL only at HFL 14.50 m."
        ),
    },

    # ── UTTARAKHAND ──────────────────────────────────────────────────────────────
    # CWC key stations: Ganga at Rishikesh danger ~11.00 m; Alaknanda at Srinagar danger ~11.00 m
    "uttarakhand": {
        "region": "HIMALAYAN",
        "peak_level_m": {"moderate": 10.0, "severe": 11.0, "critical": 12.2},
        "rainfall_7d_mm": {"moderate": 190.0, "severe": 320.0, "critical": 460.0},
        "danger_level_m": 11.00,
        "warning_level_m": 9.40,
        "hfl_m": 13.00,
        "primary_rivers": ["Ganga", "Alaknanda", "Bhagirathi", "Yamuna", "Kali", "Mandakini"],
        "vulnerable_districts": ["Chamoli", "Rudraprayag", "Uttarkashi", "Pithoragarh", "Haridwar"],
        "notes": (
            "Kedarnath 2013 flash flood worst disaster in independent India (5000+ deaths). "
            "GLOF, cloudbursts, landslide dam outbursts. "
            "Chamoli GLOF (Feb 2021) destroyed Tapovan-Vishnugad project. "
            "OPTION-A: SEVERE only when gauge >= 11.00 m; CRITICAL only at HFL 13.00 m."
        ),
    },

    # ── WEST BENGAL ──────────────────────────────────────────────────────────────
    # CWC key stations: Ganga at Farakka danger ~12.50 m; Teesta at Jaldhaka danger ~12.00 m
    #                   Damodar at Rhondia danger ~12.00 m
    "west bengal": {
        "region": "COASTAL",
        "peak_level_m": {"moderate": 11.5, "severe": 12.5, "critical": 13.8},
        "rainfall_7d_mm": {"moderate": 270.0, "severe": 430.0, "critical": 620.0},
        "danger_level_m": 12.50,
        "warning_level_m": 10.60,
        "hfl_m": 14.50,
        "primary_rivers": ["Ganga/Hooghly", "Teesta", "Damodar", "Mayurakshi", "Jaldhaka"],
        "vulnerable_districts": ["Malda", "Murshidabad", "South 24 Parganas", "Hooghly", "Jalpaiguri", "Koch Bihar"],
        "notes": (
            "DVC controlled releases affect Howrah-Hooghly. "
            "Teesta floods North Bengal post-Sikkim releases. "
            "Sundarbans tidal flooding compounded by cyclone storm surge. "
            "OPTION-A: SEVERE only when gauge >= 12.50 m; CRITICAL only at HFL 14.50 m."
        ),
    },

    # ══ UNION TERRITORIES ════════════════════════════════════════════════════════

    # ── ANDAMAN AND NICOBAR ISLANDS ──────────────────────────────────────────────
    "andaman and nicobar islands": {
        "region": "ISLAND",
        "peak_level_m": {"moderate": 11.0, "severe": 12.0, "critical": 13.2},
        "rainfall_7d_mm": {"moderate": 350.0, "severe": 550.0, "critical": 750.0},
        "danger_level_m": 12.00,
        "warning_level_m": 10.20,
        "hfl_m": 13.80,
        "primary_rivers": ["Kalpong", "Dagmar"],
        "vulnerable_districts": ["North Andaman", "South Andaman", "Nicobar"],
        "notes": (
            "Cyclone and tsunami risk. Receives ~3000 mm/year. "
            "Remote islands have limited early warning infrastructure. "
            "OPTION-A: SEVERE only when gauge >= 12.00 m; CRITICAL only at HFL 13.80 m."
        ),
    },

    # ── CHANDIGARH ───────────────────────────────────────────────────────────────
    "chandigarh": {
        "region": "URBAN_UT",
        "peak_level_m": {"moderate": 11.0, "severe": 12.0, "critical": 13.0},
        "rainfall_7d_mm": {"moderate": 180.0, "severe": 290.0, "critical": 420.0},
        "danger_level_m": 12.00,
        "warning_level_m": 10.20,
        "hfl_m": 13.40,
        "primary_rivers": ["Ghaggar", "Sukhna Choe"],
        "vulnerable_districts": ["Chandigarh UT"],
        "notes": (
            "Urban flash flooding from impervious surfaces. Sukhna Lake overflow risk. "
            "Ghaggar carries high peak discharge from Shivalik Hills during monsoon. "
            "OPTION-A: SEVERE only when gauge >= 12.00 m; CRITICAL only at HFL 13.40 m."
        ),
    },

    # ── DADRA AND NAGAR HAVELI AND DAMAN AND DIU ──────────────────────────────────
    "dadra and nagar haveli and daman and diu": {
        "region": "COASTAL",
        "peak_level_m": {"moderate": 10.5, "severe": 11.5, "critical": 12.5},
        "rainfall_7d_mm": {"moderate": 300.0, "severe": 480.0, "critical": 680.0},
        "danger_level_m": 11.50,
        "warning_level_m": 9.80,
        "hfl_m": 13.20,
        "primary_rivers": ["Damanganga", "Kolak"],
        "vulnerable_districts": ["Dadra", "Nagar Haveli", "Daman", "Diu"],
        "notes": (
            "High Konkan rainfall (2500-3000 mm). Damanganga River floods Silvassa and Daman town. "
            "Short rivers with steep gradients respond within 2-3 hours to rainfall events. "
            "OPTION-A: SEVERE only when gauge >= 11.50 m; CRITICAL only at HFL 13.20 m."
        ),
    },

    # ── DELHI ─────────────────────────────────────────────────────────────────────
    # CWC: Yamuna at Old Railway Bridge Delhi
    # WARNING 204.00 m MSL | DANGER 204.83 m MSL | HFL 207.49 m MSL (2013)
    # 2023 all-time high: 208.66 m MSL
    # Note: peak_level_m uses MSL datum (203-206 m) unlike relative states.
    # Option-A guard uses MSL values directly from CWC live feed.
    "delhi": {
        "region": "URBAN_UT",
        "peak_level_m": {"moderate": 203.0, "severe": 204.5, "critical": 206.0},
        "rainfall_7d_mm": {"moderate": 150.0, "severe": 250.0, "critical": 380.0},
        "danger_level_m": 204.83,
        "warning_level_m": 204.00,
        "hfl_m": 207.49,
        "primary_rivers": ["Yamuna"],
        "vulnerable_districts": ["East Delhi", "North East Delhi", "Yamuna floodplain settlements"],
        "notes": (
            "CWC Yamuna at Old Railway Bridge Delhi danger 204.83 m MSL. "
            "2023 floods reached 208.66 m — highest ever recorded, above HFL 207.49 m. "
            "Hathnikund Barrage (Haryana) releases reach Delhi in ~2 days. "
            "DATUM: All thresholds use MSL gauge values for this state. "
            "OPTION-A: SEVERE only when gauge >= 204.83 m; CRITICAL only at HFL 207.49 m."
        ),
    },

    # ── JAMMU AND KASHMIR ────────────────────────────────────────────────────────
    # CWC key stations: Jhelum at Ram Munshi Bagh (Srinagar) danger ~11.00 m
    "jammu and kashmir": {
        "region": "HIMALAYAN",
        "peak_level_m": {"moderate": 10.0, "severe": 11.0, "critical": 12.5},
        "rainfall_7d_mm": {"moderate": 160.0, "severe": 270.0, "critical": 400.0},
        "danger_level_m": 11.00,
        "warning_level_m": 9.40,
        "hfl_m": 13.20,
        "primary_rivers": ["Jhelum", "Chenab", "Tawi", "Indus"],
        "vulnerable_districts": ["Srinagar", "Budgam", "Anantnag", "Jammu", "Ramban"],
        "notes": (
            "Jhelum Valley flooding at Srinagar in 2014 (worst in 60 years). "
            "Flat valley basin with poor drainage; Wular Lake natural buffer. "
            "Snowmelt + monsoon combination elevates risk. "
            "OPTION-A: SEVERE only when gauge >= 11.00 m; CRITICAL only at HFL 13.20 m."
        ),
    },

    # ── LADAKH ───────────────────────────────────────────────────────────────────
    # Very low rainfall; Leh cloudburst 2010 ~30 mm in 1 h caused catastrophic flooding
    "ladakh": {
        "region": "HIMALAYAN",
        "peak_level_m": {"moderate": 8.0, "severe": 9.5, "critical": 11.0},
        "rainfall_7d_mm": {"moderate": 60.0, "severe": 110.0, "critical": 180.0},
        "danger_level_m": 9.50,
        "warning_level_m": 8.10,
        "hfl_m": 11.50,
        "primary_rivers": ["Indus", "Zanskar", "Shyok", "Nubra"],
        "vulnerable_districts": ["Leh", "Kargil"],
        "notes": (
            "Cold desert; GLOF and cloudburst risk. "
            "Leh cloudburst 2010 caused ~200 deaths; even 30 mm/h is extreme here. "
            "Shyok/Siachen glacial lake outbursts generate extreme flows. "
            "OPTION-A: SEVERE only when gauge >= 9.50 m; CRITICAL only at HFL 11.50 m."
        ),
    },

    # ── LAKSHADWEEP ──────────────────────────────────────────────────────────────
    "lakshadweep": {
        "region": "ISLAND",
        "peak_level_m": {"moderate": 9.0, "severe": 10.0, "critical": 11.0},
        "rainfall_7d_mm": {"moderate": 300.0, "severe": 480.0, "critical": 680.0},
        "danger_level_m": 10.00,
        "warning_level_m": 8.50,
        "hfl_m": 11.50,
        "primary_rivers": [],
        "vulnerable_districts": ["Kavaratti", "Agatti", "Minicoy"],
        "notes": (
            "Low-lying coral atolls; max elevation ~4 m. Coastal inundation is primary hazard. "
            "Sea-level rise and storm surge threaten entire island chain. "
            "OPTION-A guard applies on tidal surge level proxy."
        ),
    },

    # ── PUDUCHERRY ───────────────────────────────────────────────────────────────
    "puducherry": {
        "region": "COASTAL",
        "peak_level_m": {"moderate": 10.5, "severe": 11.5, "critical": 12.5},
        "rainfall_7d_mm": {"moderate": 280.0, "severe": 440.0, "critical": 630.0},
        "danger_level_m": 11.50,
        "warning_level_m": 9.80,
        "hfl_m": 13.00,
        "primary_rivers": ["Gingee", "Pennaiyar", "Malattar"],
        "vulnerable_districts": ["Puducherry", "Karaikal", "Yanam", "Mahe"],
        "notes": (
            "Enclave UT receives NE monsoon (Oct-Dec). Coastal location makes it cyclone-prone. "
            "Pennaiyar and Gingee rivers carry runoff from Tamil Nadu hills. "
            "OPTION-A: SEVERE only when gauge >= 11.50 m; CRITICAL only at HFL 13.00 m."
        ),
    },
}


DEFAULT_STATE_ENTRY: StateSeverityMatrixEntry = {
    "region": "PLAINS",
    "peak_level_m": {"moderate": 11.5, "severe": 12.5, "critical": 13.5},
    "rainfall_7d_mm": {"moderate": 250.0, "severe": 400.0, "critical": 550.0},
    "danger_level_m": 12.5,
    "warning_level_m": 10.6,
    "hfl_m": 14.0,
    "primary_rivers": [],
    "vulnerable_districts": [],
    "notes": "Default thresholds — no specific calibration available for this state.",
}


def get_state_severity_entry(state: str) -> StateSeverityMatrixEntry:
    key = normalize_state_name(state)
    return STATE_SEVERITY_MATRIX.get(key, DEFAULT_STATE_ENTRY)


def _telemetry_level(value: Any) -> float:
    """Extract a telemetry level (warning/danger/river) as float; returns 0.0 on missing/invalid."""
    try:
        if value is None or value == "":
            return 0.0
        return float(value)
    except (TypeError, ValueError):
        return 0.0


def select_best_station_node(
    state_name: str,
    station_name: str | None,
    telemetry_payload: Dict[str, Any] | None,
) -> Optional[Dict[str, Any]]:
    """Pick the best telemetry node for the selected (state, station).

    Heuristics:
      - Prefer exact/partial match on station_name against node['station'] and node['river']
      - Prefer nodes in the same state (node['state_name'] / node['state'])
      - Otherwise pick the highest river_level within the same state
      - Return None if nothing usable
    """
    if not telemetry_payload:
        return None

    nodes = telemetry_payload.get("data") if isinstance(telemetry_payload, dict) else None
    if not isinstance(nodes, list) or not nodes:
        return None

    target_state = normalize_state_name(state_name)
    target_station = normalize_state_name(station_name or "")

    def node_state_match(node: Dict[str, Any]) -> bool:
        node_state_raw = node.get("state_name") or node.get("state") or ""
        return bool(target_state) and target_state in normalize_state_name(str(node_state_raw))

    def node_station_match(node: Dict[str, Any]) -> bool:
        if not target_station:
            return False
        station_raw = node.get("station") or ""
        river_raw = node.get("river") or ""
        return (
            target_station in normalize_state_name(str(station_raw))
            or target_station in normalize_state_name(str(river_raw))
        )

    ranked: list[tuple[int, float, Dict[str, Any]]] = []
    for node in nodes:
        if not isinstance(node, dict):
            continue
        if not node_state_match(node):
            continue
        river_level = _telemetry_level(node.get("river_level"))

        if node_station_match(node):
            # Best: station match in same state
            score = 0
        else:
            score = 2

        ranked.append((score, -river_level, node))

    if ranked:
        ranked.sort()
        return ranked[0][2]

    # Second pass: if state keys are inconsistent, still try station match globally.
    if target_station:
        for node in nodes:
            if not isinstance(node, dict):
                continue
            station_raw = node.get("station") or ""
            river_raw = node.get("river") or ""
            if (
                target_station in normalize_state_name(str(station_raw))
                or target_station in normalize_state_name(str(river_raw))
            ):
                return node

    return None


def build_effective_state_entry(
    state_name: str,
    station_telemetry: Optional[Dict[str, Any]],
) -> StateSeverityMatrixEntry:
    """Build an effective severity entry merging state defaults with station-specific CWC thresholds.

    - Always starts from the state matrix entry.
    - If telemetry provides non-zero/sane warning/danger levels, they override the state's warning/danger.
    - FIX: HFL fallback uses max(state_hfl, danger * 1.20) instead of danger + 1.0 so the
      CRITICAL window is never artificially collapsed to 1 m above SEVERE. The 1.20 factor
      gives a ~2.4 m gap at Bihar's danger level (12.0 m → 14.4 m) which matches the
      Kosi at Baltara calibrated HFL (14.40 m bed-relative).

    Telemetry override is only applied when values are > 0.
    """
    base_entry = get_state_severity_entry(state_name)
    entry: StateSeverityMatrixEntry = dict(base_entry)  # shallow copy is sufficient: we only override numeric fields

    if not station_telemetry:
        return entry

    warning = _telemetry_level(station_telemetry.get("warning_level"))
    danger = _telemetry_level(station_telemetry.get("danger_level"))

    # Override only if CWC values are non-zero and sane
    if warning > 0.0:
        entry["warning_level_m"] = warning
    if danger > 0.0:
        entry["danger_level_m"] = danger

    # FIX: use max(state_hfl, danger * 1.20) instead of danger + 1.0 so the CRITICAL
    # window is never collapsed to a 1 m band. 1.20 factor aligns with Bihar Kosi at
    # Baltara calibrated values (danger 12.00 m → HFL 14.40 m ≈ danger × 1.20).
    state_hfl = _telemetry_level(base_entry.get("hfl_m"))
    if danger > 0.0:
        entry["hfl_m"] = max(state_hfl, danger * 1.20)

    # Defensive: keep ordering consistent when both values are provided.
    # (If CWC warning > danger due to noise, clamp warning down.)
    if danger > 0.0 and warning > 0.0 and float(entry.get("warning_level_m", 0.0)) > float(entry.get("danger_level_m", 0.0)):
        entry["warning_level_m"] = float(entry["danger_level_m"]) * 0.86

    return entry



def severity_from_entry(
    peak_level_m: float,
    rainfall_7d_mm: float,
    entry: StateSeverityMatrixEntry,
    river_level_m: Optional[float] = None,
) -> SeverityLevel:
    """Derive LOW/MODERATE/SEVERE/CRITICAL from state matrix entry.

    Depth severity uses per-state peak_level_m thresholds (useful for
    offline labelling / training); rainfall severity comes from region-level
    7-day thresholds so all PLAINS/COASTAL/HIMALAYAN states behave consistently.

    If ``river_level_m`` is provided (live CWC gauge value), the Option-A guard
    is applied automatically to cap the result using CWC warning/danger/HFL
    thresholds. Pass river_level_m=None for training/offline use.
    """
    p = entry["peak_level_m"]
    r = entry["rainfall_7d_mm"]

    # Depth axis
    if peak_level_m >= p["critical"]:
        depth_sev: SeverityLevel = "CRITICAL"
    elif peak_level_m >= p["severe"]:
        depth_sev = "SEVERE"
    elif peak_level_m >= p["moderate"]:
        depth_sev = "MODERATE"
    else:
        depth_sev = "LOW"

    # Rainfall axis
    if rainfall_7d_mm >= r["critical"]:
        rain_sev: SeverityLevel = "CRITICAL"
    elif rainfall_7d_mm >= r["severe"]:
        rain_sev = "SEVERE"
    elif rainfall_7d_mm >= r["moderate"]:
        rain_sev = "MODERATE"
    else:
        rain_sev = "LOW"

    # Raw severity = max of depth and rainfall axes
    raw_severity: SeverityLevel = depth_sev if SEVERITY_ORDER[depth_sev] >= SEVERITY_ORDER[rain_sev] else rain_sev

    # Option-A guard — applied only when a live river gauge level is available
    if river_level_m is not None:
        return danger_level_override_guard(
            severity=raw_severity,
            river_level_m=float(river_level_m),
            rainfall_7d_mm=float(rainfall_7d_mm),
            entry=entry,
        )

    return raw_severity
