// lib/providers/live_engine_bridge_provider.dart  v4.3
//
// v4.3 (17 Jun 2026) — Birpur DL updated 74.70 → 76.02
//
// v4.2 (17 Jun 2026) — Dataflow audit: threshold + coordinate fixes
//
//   FIX-3: samastipur WL corrected: was warning==danger (both 46.00)
//     warning: 44.80, danger: 46.00  (from kBiharGauges)
//     With WL==DL every reading at exactly DL showed CRITICAL instead of DANGER.
//
//   FIX-4: darauli WL corrected: was warning(61.20) > danger(60.82) — impossible.
//     warning: 60.50, danger: 60.82  (from kBiharGauges)
//     This created a dead zone where station never transitioned through DANGER.
//
//   FIX-5: mahnar HFL corrected: was danger(49.70) > hfl(48.91) — impossible.
//     hfl: 51.20  (estimated from typical Ganga HFL range at this cross-section;
//     BEAMS RTDAS value pending confirmation — tagged TODO)
//
//   FIX-6: hathidah lon corrected: was 86.165 → 85.750 (40 km off, was in Lakhisarai)
//   FIX-7: sripalpur coords corrected: was (25.328, 85.038) → (25.52, 85.38)
//   FIX-8: sonbarsa coords corrected: was (25.993, 86.063) → (26.70, 85.48)
//           (was plotting in Samastipur, 75 km from actual Sitamarhi location)
//
// v4.1 (12 Jun 2026): _norm() double-space fix + threshold corrections.
// v4.0: ThresholdOverrideStore live RTDAS priority.
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/river_station.dart';
import '../services/bihar_live_engine.dart';
import '../services/threshold_override_store.dart';

// ── Threshold table ───────────────────────────────────────────────────────────────────
// SOURCE: bihar_rivers.dart v4.4 kBiharGauges (BEAMS RTDAS + BeFIQR)
// All levels in metres MSL.
const Map<String, ({double warning, double danger, double hfl, String river})>
    _kThresholds = {

  // ── GANGA (7 + WRD stations) ───────────────────────────────────────────
  'gandhighat': (warning: 47.50, danger: 48.60, hfl: 50.52, river: 'Ganga'),
  'dighaghat':  (warning: 49.30, danger: 50.45, hfl: 52.52, river: 'Ganga'),
  'hathidah':   (warning: 40.50, danger: 41.76, hfl: 43.52, river: 'Ganga'),
  'munger':     (warning: 38.20, danger: 39.33, hfl: 40.99, river: 'Ganga'),
  'kahalgaon':  (warning: 30.00, danger: 31.09, hfl: 32.87, river: 'Ganga'),
  'bhagalpur':  (warning: 32.50, danger: 33.68, hfl: 34.86, river: 'Ganga'),
  'buxar':      (warning: 59.20, danger: 60.30, hfl: 62.10, river: 'Ganga'),
  // WRD Ganga
  'udwantnagar': (warning: 53.67, danger: 58.40, hfl: 59.40, river: 'Ganga'),
  'azmabad':     (warning: 24.53, danger: 30.54, hfl: 32.41, river: 'Ganga'),
  // FIX-5: mahnar hfl corrected (was 48.91 < danger 49.70 — impossible)
  'mahnar':      (warning: 39.99, danger: 49.70, hfl: 51.20, river: 'Ganga'),  // TODO: verify with BEAMS RTDAS
  'sultanganj':  (warning: 28.07, danger: 34.50, hfl: 36.80, river: 'Ganga'),
  'ahiro':       (warning: 49.54, danger: 52.30, hfl: 52.85, river: 'Ganga'),
  'danapur':     (warning: 43.29, danger: 51.20, hfl: 52.61, river: 'Ganga'),
  'indo nepal border': (warning: 65.34, danger: 68.70, hfl: 70.20, river: 'Ganga'),
  'manpur':      (warning: 32.50, danger: 40.78, hfl: 41.83, river: 'Ganga'),
  'sitalpur':    (warning: 47.19, danger: 54.20, hfl: 55.10, river: 'Ganga'),
  'suryagadha':  (warning: 31.19, danger: 40.41, hfl: 40.90, river: 'Ganga'),

  // ── KOSI (10 stations) ────────────────────────────────────────────────────
  // v4.3: Birpur DL updated 74.70 → 76.02 (17 Jun 2026)
  'birpur':           (warning: 73.70, danger: 76.02, hfl: 77.10, river: 'Kosi'),  // hfl corrected above DL
  'birpur cwc':       (warning: 73.70, danger: 76.02, hfl: 77.10, river: 'Kosi'),  // hfl corrected above DL
  'basua':            (warning: 46.50, danger: 47.75, hfl: 49.24, river: 'Kosi'),
  'baltara':          (warning: 32.85, danger: 33.85, hfl: 36.40, river: 'Kosi'),
  'kursela':          (warning: 28.80, danger: 30.00, hfl: 32.10, river: 'Kosi'),
  'dumri bridge':     (warning: 32.85, danger: 33.85, hfl: 36.40, river: 'Kosi'),
  'bhim nagar':       (warning: 70.00, danger: 71.00, hfl: 72.50, river: 'Kosi'),
  'bhimnagar':        (warning: 70.00, danger: 71.00, hfl: 72.50, river: 'Kosi'),
  'vijay ghat bridge':(warning: 29.50, danger: 31.00, hfl: 33.50, river: 'Kosi'),
  'vijayghat':        (warning: 29.50, danger: 31.00, hfl: 33.50, river: 'Kosi'),
  'naugachia':        (warning: 29.50, danger: 31.00, hfl: 33.50, river: 'Ganga'),
  'dhamaraghat':      (warning: 34.98, danger: 37.50, hfl: 37.75, river: 'Kosi'),
  'dalsingh sarai':   (warning: 39.94, danger: 42.84, hfl: 44.34, river: 'Kosi'),
  'nirmali':          (warning: 50.40, danger: 53.78, hfl: 55.28, river: 'Kosi'),

  // ── GANDAK (6 + WRD stations) ─────────────────────────────────────────────
  'chatia':      (warning: 68.10, danger: 69.15, hfl: 70.04, river: 'Gandak'),
  'dumariaghat': (warning: 61.10, danger: 62.22, hfl: 64.36, river: 'Gandak'),
  'rewaghat':    (warning: 53.40, danger: 54.41, hfl: 55.46, river: 'Gandak'),
  'hajipur':     (warning: 49.40, danger: 50.32, hfl: 50.93, river: 'Gandak'),
  'lalganj':     (warning: 49.30, danger: 50.50, hfl: 51.83, river: 'Gandak'),
  'khadda':      (warning: 94.50, danger: 96.00, hfl: 97.50, river: 'Gandak'),
  // WRD Gandak
  'bagaha':      (warning: 87.34, danger: 89.40, hfl: 90.90, river: 'Gandak'),
  'kukraha':     (warning: 67.85, danger: 70.60, hfl: 72.10, river: 'Gandak'),
  'thakraha':    (warning: 75.37, danger: 77.18, hfl: 78.68, river: 'Gandak'),
  'triveni':     (warning: 104.12, danger: 109.67, hfl: 112.79, river: 'Gandak'),

  // ── BAGMATI (13 stations) ───────────────────────────────────────────────
  'dheng bridge':        (warning: 70.00, danger: 71.00, hfl: 73.47, river: 'Bagmati'),
  'dhengbridge':         (warning: 70.00, danger: 71.00, hfl: 73.47, river: 'Bagmati'),
  'sonakhan':            (warning: 67.80, danger: 68.80, hfl: 72.05, river: 'Bagmati'),
  'benibad':             (warning: 47.68, danger: 48.68, hfl: 50.12, river: 'Bagmati'),
  'hayaghat':            (warning: 44.50, danger: 45.72, hfl: 48.96, river: 'Bagmati'),
  'dhengraghat bagmati': (warning: 34.65, danger: 35.65, hfl: 47.30, river: 'Bagmati'),
  'kamtaul bagmati':     (warning: 49.00, danger: 50.00, hfl: 53.01, river: 'Bagmati'),
  'kamtaul':             (warning: 49.00, danger: 50.00, hfl: 53.01, river: 'Bagmati'),
  'runnisaidpur':        (warning: 52.50, danger: 55.00, hfl: 58.15, river: 'Bagmati'),
  'runisaidpur':         (warning: 52.50, danger: 55.00, hfl: 58.15, river: 'Bagmati'),
  'dubbadhar':           (warning: 59.00, danger: 61.28, hfl: 63.75, river: 'Bagmati'),
  'kansar':              (warning: 57.50, danger: 59.06, hfl: 60.86, river: 'Bagmati'),
  'kataunjha':           (warning: 52.80, danger: 55.00, hfl: 58.36, river: 'Bagmati'),
  // WRD Bagmati
  'badlaghat':  (warning: 33.06, danger: 36.31, hfl: 37.81, river: 'Bagmati'),
  'belsand':    (warning: 56.19, danger: 59.25, hfl: 60.75, river: 'Bagmati'),
  'bishunpur':  (warning: 42.42, danger: 47.40, hfl: 48.97, river: 'Bagmati'),

  // ── BURHI GANDAK (5 + WRD stations) ──────────────────────────────────────────
  'sikandarpur': (warning: 51.40, danger: 52.53, hfl: 54.29, river: 'Burhi Gandak'),
  // FIX-3: samastipur WL corrected: was warning==danger (both 46.00)
  'samastipur':  (warning: 44.80, danger: 46.00, hfl: 49.40, river: 'Burhi Gandak'),
  'rosera':      (warning: 41.50, danger: 42.63, hfl: 46.56, river: 'Burhi Gandak'),
  'khagaria':    (warning: 35.40, danger: 36.58, hfl: 39.22, river: 'Burhi Gandak'),
  'gaighat':     (warning: 53.00, danger: 54.00, hfl: 55.50, river: 'Burhi Gandak'),
  // WRD Burhi Gandak
  'ahirwalia':     (warning: 52.34, danger: 59.62, hfl: 61.17, river: 'Burhi Gandak'),
  'chanpatia':     (warning: 69.52, danger: 73.68, hfl: 76.68, river: 'Burhi Gandak'),
  'lalbegiaghat':  (warning: 56.61, danger: 63.20, hfl: 67.09, river: 'Burhi Gandak'),
  'chintawanpur':  (warning: 55.08, danger: 61.45, hfl: 62.95, river: 'Burhi Gandak'),
  'kanti':         (warning: 48.10, danger: 54.09, hfl: 56.45, river: 'Burhi Gandak'),
  'lakhoura':      (warning: 56.67, danger: 62.75, hfl: 64.25, river: 'Burhi Gandak'),
  'madhuban':      (warning: 53.48, danger: 60.19, hfl: 61.69, river: 'Burhi Gandak'),
  'sakra':         (warning: 42.52, danger: 50.58, hfl: 51.47, river: 'Burhi Gandak'),
  'sugauli':       (warning: 63.58, danger: 66.50, hfl: 69.00, river: 'Burhi Gandak'),

  // ── GHAGHRA (2 stations) ────────────────────────────────────────────────────
  // FIX-4: darauli WL corrected: was 61.20 > danger 60.82 (impossible)
  'darauli':        (warning: 60.50, danger: 60.82, hfl: 61.82, river: 'Ghaghra'),
  'gangpur siswan': (warning: 56.70, danger: 57.04, hfl: 58.26, river: 'Ghaghra'),
  'gangpur':        (warning: 56.70, danger: 57.04, hfl: 58.26, river: 'Ghaghra'),

  // ── KAMLA (4 stations) ──────────────────────────────────────────────────────
  'jainagar':      (warning: 67.75, danger: 67.75, hfl: 71.35, river: 'Kamla'),
  'jhanjharpur':   (warning: 48.50, danger: 50.00, hfl: 53.11, river: 'Kamla'),
  'kamtaul kamla': (warning: 43.00, danger: 44.00, hfl: 45.45, river: 'Kamla'),
  'phulparas':     (warning: 49.50, danger: 50.50, hfl: 53.11, river: 'Kamla'),

  // ── MAHANANDA (4 stations) ────────────────────────────────────────────────
  'taibpur':               (warning: 64.40, danger: 66.00, hfl: 67.22, river: 'Mahananda'),
  'dhengraghat mahananda': (warning: 34.65, danger: 35.65, hfl: 38.20, river: 'Mahananda'),
  'jhawa':                 (warning: 30.00, danger: 31.40, hfl: 34.07, river: 'Mahananda'),
  'sikti':        (warning: 60.06, danger: 61.40, hfl: 62.90, river: 'Mahananda'),
  'chargharia':   (warning: 44.55, danger: 46.94, hfl: 48.85, river: 'Mahananda'),
  'moujabadi':    (warning: 50.16, danger: 52.05, hfl: 53.55, river: 'Mahananda'),

  // ── PUNPUN (3 stations) ───────────────────────────────────────────────────
  'sripalpur':  (warning: 50.60, danger: 51.83, hfl: 53.91, river: 'Punpun'),
  'fatehpur':   (warning: 43.14, danger: 51.63, hfl: 52.63, river: 'Punpun'),
  'kinjer':     (warning: 61.42, danger: 65.00, hfl: 67.95, river: 'Punpun'),

  // ── ADHWARA / DHAUS / KHIROI (4 stations) ─────────────────────────────────
  'ekmighat':        (warning: 45.00, danger: 46.94, hfl: 49.52, river: 'Khiroi'),
  'kamtaul adhwara': (warning: 48.00, danger: 50.00, hfl: 53.05, river: 'Adhwara'),
  'saulighat':       (warning: 50.00, danger: 52.37, hfl: 55.10, river: 'Dhaus'),
  'agropatti':       (warning: 51.00, danger: 52.75, hfl: 54.53, river: 'Khiroi'),
  'saharghat':       (warning: 52.32, danger: 55.50, hfl: 58.25, river: 'Adhwara'),

  // ── JHIM / LAL BAKEYA / BALAN / BHUTAHI BALAN ────────────────────────────────
  'sonbarsa':        (warning: 80.50, danger: 81.85, hfl: 83.20, river: 'Jhim'),
  'lalbakeya':       (warning: 73.00, danger: 74.00, hfl: 75.50, river: 'Lalbakeya'),
  'goabari':         (warning: 69.50, danger: 71.15, hfl: 73.86, river: 'Lal Bakeya'),
  'phulparas balan': (warning: 59.50, danger: 60.80, hfl: 61.80, river: 'Balan'),
  'laukaha':         (warning: 78.50, danger: 79.80, hfl: 80.80, river: 'Bhutahi Balan'),

  // ── KHANDO / KAREH ───────────────────────────────────────────────────────────────
  'dagmara':  (warning: 60.50, danger: 61.50, hfl: 62.50, river: 'Khando'),
  'karachin': (warning: 38.50, danger: 40.00, hfl: 41.90, river: 'Kareh'),

  // ── BAYA / FALGU / HAROHAR / KAMALA BALAN / KANKAI / KARMNASA / KIUL / MECHI / PARMAN / SONE ──
  'bachhwara':    (warning: 35.21, danger: 42.88, hfl: 44.38, river: 'Baya'),
  'mohauddin nagar': (warning: 38.53, danger: 43.47, hfl: 44.97, river: 'Baya'),
  'saksohra':     (warning: 26.44, danger: 33.50, hfl: 35.14, river: 'Falgu'),
  'kadirganj':    (warning: 25.00, danger: 30.00, hfl: 32.00, river: 'Harohar'),
  'mankatha':     (warning: 32.72, danger: 40.78, hfl: 42.88, river: 'Harohar'),
  'kapasiya':     (warning: 41.60, danger: 43.78, hfl: 45.28, river: 'Kamala Balan'),
  'jhagarua':     (warning: 42.84, danger: 46.22, hfl: 47.72, river: 'Kamalabalan'),
  'kakarghatti':  (warning: 43.95, danger: 47.50, hfl: 49.00, river: 'Kamalabalan'),
  'rauta':        (warning: 40.22, danger: 41.71, hfl: 43.21, river: 'Kankai'),
  'chousa':       (warning: 50.36, danger: 61.89, hfl: 62.89, river: 'Karmnasa'),
  'durgawati':    (warning: 63.70, danger: 69.00, hfl: 71.00, river: 'Karmnasha'),
  'jamui':        (warning: 66.13, danger: 69.00, hfl: 69.61, river: 'Kiul'),
  'lakhisarai':   (warning: 35.72, danger: 42.40, hfl: 45.90, river: 'Kiul'),
  'galgalia':     (warning: 79.21, danger: 82.30, hfl: 83.66, river: 'Mechi'),
  'araria':       (warning: 45.07, danger: 47.00, hfl: 49.40, river: 'Parman'),
  'bathnaha':     (warning: 59.95, danger: 62.56, hfl: 64.06, river: 'Parman'),
  'amour':        (warning: 36.95, danger: 38.38, hfl: 39.88, river: 'Parman'),
  'indrapuri':    (warning: 101.10, danger: 108.20, hfl: 108.85, river: 'Sone'),
  'koelwar':      (warning: 46.32, danger: 55.52, hfl: 58.88, river: 'Sone'),
  'maner':        (warning: 43.38, danger: 52.00, hfl: 53.79, river: 'Sone'),
  'banjari':      (warning: 120.72, danger: 124.89, hfl: 125.89, river: 'Sone'),
  'paliganj':     (warning: 61.15, danger: 69.10, hfl: 69.14, river: 'Sone'),
  'yadunathpur':  (warning: 144.74, danger: 147.14, hfl: 149.35, river: 'Sone'),
  'banka':        (warning: 80.47, danger: 86.75, hfl: 87.40, river: 'Chandan'),
};

// ── Station coordinates ──────────────────────────────────────────────────────────────────
const Map<String, ({double lat, double lon})> _kCoords = {
  // GANGA
  'gandhighat':        (lat: 25.614, lon: 85.127),
  'dighaghat':         (lat: 25.623, lon: 85.074),
  // FIX-6: hathidah lon corrected 86.165 → 85.750 (was in Lakhisarai, 40 km off)
  'hathidah':          (lat: 25.417, lon: 85.750),
  'munger':            (lat: 25.375, lon: 86.474),
  'kahalgaon':         (lat: 25.207, lon: 87.268),
  'bhagalpur':         (lat: 25.245, lon: 86.978),
  'buxar':             (lat: 25.563, lon: 83.978),
  // KOSI
  'birpur':            (lat: 26.505, lon: 86.914),
  'birpur cwc':        (lat: 26.505, lon: 86.914),
  'basua':             (lat: 26.430, lon: 86.702),
  'baltara':           (lat: 25.867, lon: 86.563),
  'kursela':           (lat: 25.453, lon: 87.266),
  'dumri bridge':      (lat: 25.920, lon: 86.580),
  'bhim nagar':        (lat: 26.862, lon: 87.062),
  'bhimnagar':         (lat: 26.862, lon: 87.062),
  'vijay ghat bridge': (lat: 25.700, lon: 86.900),
  'vijayghat':         (lat: 25.700, lon: 86.900),
  'naugachia':         (lat: 25.390, lon: 87.097),
  // GANDAK
  'chatia':            (lat: 26.680, lon: 84.882),
  'dumariaghat':       (lat: 27.093, lon: 84.478),
  'rewaghat':          (lat: 26.205, lon: 84.975),
  'hajipur':           (lat: 25.683, lon: 85.209),
  'lalganj':           (lat: 25.873, lon: 85.177),
  'khadda':            (lat: 27.098, lon: 83.893),
  // BAGMATI
  'dheng bridge':          (lat: 26.740, lon: 85.594),
  'dhengbridge':           (lat: 26.740, lon: 85.594),
  'sonakhan':              (lat: 26.920, lon: 85.450),
  'benibad':               (lat: 26.148, lon: 85.852),
  'hayaghat':              (lat: 26.122, lon: 85.762),
  'dhengraghat bagmati':   (lat: 26.098, lon: 87.951),
  'kamtaul bagmati':       (lat: 26.392, lon: 85.862),
  'kamtaul':               (lat: 26.392, lon: 85.862),
  'runnisaidpur':          (lat: 26.553, lon: 85.473),
  'runisaidpur':           (lat: 26.553, lon: 85.473),
  'dubbadhar':             (lat: 26.820, lon: 85.380),
  'kansar':                (lat: 26.780, lon: 85.510),
  'kataunjha':             (lat: 26.640, lon: 85.520),
  // BURHI GANDAK
  'sikandarpur':       (lat: 26.118, lon: 85.391),
  'samastipur':        (lat: 25.871, lon: 85.779),
  'rosera':            (lat: 25.863, lon: 85.984),
  'khagaria':          (lat: 25.502, lon: 86.468),
  'gaighat':           (lat: 25.990, lon: 85.684),
  // GHAGHRA
  'darauli':           (lat: 26.102, lon: 84.136),
  'gangpur siswan':    (lat: 26.218, lon: 84.357),
  'gangpur':           (lat: 26.218, lon: 84.357),
  // KAMLA
  'jainagar':          (lat: 26.597, lon: 86.247),
  'jhanjharpur':       (lat: 26.268, lon: 86.280),
  'kamtaul kamla':     (lat: 26.392, lon: 85.862),
  'phulparas':         (lat: 26.519, lon: 86.504),
  // MAHANANDA
  'taibpur':               (lat: 25.775, lon: 87.474),
  'dhengraghat mahananda': (lat: 26.098, lon: 87.951),
  'dhengraghat':           (lat: 26.098, lon: 87.951),
  'jhawa':                 (lat: 25.614, lon: 87.835),
  // PUNPUN
  // FIX-7: sripalpur coords corrected (25.328,85.038) → (25.52,85.38)
  'sripalpur':         (lat: 25.520, lon: 85.380),
  // ADHWARA / DHAUS / KHIROI
  'ekmighat':          (lat: 26.597, lon: 85.617),
  'kamtaul adhwara':   (lat: 26.392, lon: 85.862),
  'saulighat':         (lat: 26.480, lon: 85.720),
  'agropatti':         (lat: 26.430, lon: 85.680),
  // JHIM / LAL BAKEYA / BALAN
  // FIX-8: sonbarsa coords corrected (25.993,86.063) → (26.70,85.48) — was 75 km off in Samastipur
  'sonbarsa':          (lat: 26.700, lon: 85.480),
  'lalbakeya':         (lat: 26.600, lon: 85.750),
  'goabari':           (lat: 26.530, lon: 85.810),
  'phulparas balan':   (lat: 26.519, lon: 86.504),
  'laukaha':           (lat: 26.408, lon: 86.533),
  // KHANDO / KAREH
  'dagmara':           (lat: 26.179, lon: 86.723),
  'karachin':          (lat: 25.432, lon: 85.519),
  // WRD Bihar
  'saharghat':         (lat: 26.543, lon: 85.857),
  'badlaghat':         (lat: 25.552, lon: 86.584),
  'belsand':           (lat: 26.432, lon: 85.395),
  'bishunpur':         (lat: 24.820, lon: 84.208),
  'bachhwara':         (lat: 25.575, lon: 85.900),
  'mohauddin nagar':   (lat: 26.020, lon: 85.640),
  'ahirwalia':         (lat: 26.150, lon: 84.780),
  'chanpatia':         (lat: 26.896, lon: 84.518),
  'lalbegiaghat':      (lat: 26.060, lon: 85.320),
  'chintawanpur':      (lat: 26.550, lon: 85.100),
  'kanti':             (lat: 26.182, lon: 85.271),
  'lakhoura':          (lat: 26.430, lon: 85.050),
  'madhuban':          (lat: 26.441, lon: 85.137),
  'sakra':             (lat: 25.966, lon: 85.529),
  'sugauli':           (lat: 26.757, lon: 84.778),
  'banka':             (lat: 24.833, lon: 86.816),
  'jehanabad':         (lat: 25.153, lon: 85.007),
  'kolhachak':         (lat: 25.220, lon: 85.060),
  'masaurhi':          (lat: 25.352, lon: 84.987),
  'dobhi':             (lat: 24.503, lon: 84.895),
  'saksohra':          (lat: 24.750, lon: 85.170),
  'bagaha':            (lat: 27.059, lon: 84.206),
  'kukraha':           (lat: 26.650, lon: 84.560),
  'mahua':             (lat: 25.802, lon: 85.426),
  'thakraha':          (lat: 26.776, lon: 84.271),
  'triveni':           (lat: 25.325, lon: 85.404),
  'udwantnagar':       (lat: 25.507, lon: 84.623),
  'azmabad':           (lat: 25.357, lon: 87.224),
  'mahnar':            (lat: 25.622, lon: 85.509),
  'sultanganj':        (lat: 25.241, lon: 86.735),
  'ahiro':             (lat: 24.924, lon: 87.116),
  'danapur':           (lat: 25.636, lon: 85.047),
  'hisua':             (lat: 24.846, lon: 85.395),
  'indo nepal border': (lat: 27.100, lon: 84.300),
  'manpur':            (lat: 24.812, lon: 85.066),
  'nardiganj':         (lat: 24.944, lon: 85.430),
  'nawada':            (lat: 24.817, lon: 85.518),
  'sitalpur':          (lat: 25.764, lon: 85.030),
  'suryagadha':        (lat: 25.350, lon: 86.390),
  'chhapra':           (lat: 25.773, lon: 84.785),
  'kadirganj':         (lat: 25.550, lon: 85.950),
  'mankatha':          (lat: 25.207, lon: 86.057),
  'kapasiya':          (lat: 25.424, lon: 86.111),
  'jhagarua':          (lat: 26.320, lon: 86.180),
  'kakarghatti':       (lat: 26.183, lon: 85.949),
  'rauta':             (lat: 25.716, lon: 87.779),
  'chousa':            (lat: 25.510, lon: 84.060),
  'durgawati':         (lat: 25.241, lon: 83.475),
  'jamui':             (lat: 24.756, lon: 86.301),
  'lakhisarai':        (lat: 25.154, lon: 86.174),
  'dhamaraghat':       (lat: 26.200, lon: 87.080),
  'dalsingh sarai':    (lat: 25.665, lon: 85.841),
  'nirmali':           (lat: 26.379, lon: 86.732),
  'sikti':             (lat: 26.408, lon: 87.551),
  'chargharia':        (lat: 26.338, lon: 87.649),
  'moujabadi':         (lat: 25.680, lon: 87.520),
  'galgalia':          (lat: 26.527, lon: 88.113),
  'araria':            (lat: 26.135, lon: 87.465),
  'bathnaha':          (lat: 26.674, lon: 85.550),
  'amour':             (lat: 25.986, lon: 87.679),
  'fatehpur':          (lat: 24.608, lon: 85.226),
  'kinjer':            (lat: 24.640, lon: 85.140),
  'indrapuri':         (lat: 24.834, lon: 84.137),
  'koelwar':           (lat: 25.569, lon: 84.793),
  'maner':             (lat: 25.660, lon: 84.910),
  'banjari':           (lat: 24.675, lon: 83.993),
  'paliganj':          (lat: 25.292, lon: 84.817),
  'yadunathpur':       (lat: 24.595, lon: 83.906),
};

// ── _norm ────────────────────────────────────────────────────────────────────────────
String _norm(String v) => v
    .toLowerCase()
    .replaceAll(RegExp(r'\s*\(.*?\)'), '')
    .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
    .replaceAll(RegExp(r' +'), ' ')
    .trim();

// ── _lookupThreshold ───────────────────────────────────────────────────────────────
// Priority: 1. ThresholdOverrideStore (live RTDAS)  2. _kThresholds  3. null
({double warning, double danger, double hfl, String river})?
    _lookupThreshold(String normName) {
  final override = ThresholdOverrideStore.instance.get(normName);
  if (override != null && override.dl != null) {
    final compiled = _kThresholds[normName];
    return (
      warning: override.wl ?? compiled?.warning ?? override.dl! * 0.99,
      danger:  override.dl!,
      hfl:     override.hfl ?? compiled?.hfl ?? override.dl! * 1.05,
      river:   compiled?.river ?? 'Bihar River',
    );
  }
  final exact = _kThresholds[normName];
  if (exact != null) return exact;
  // Substring / prefix match for variant spellings.
  for (final entry in _kThresholds.entries) {
    final k = entry.key;
    if (normName.contains(k) || k.contains(normName)) return entry.value;
  }
  return null;
}

// ── Provider ─────────────────────────────────────────────────────────────────────────
class LiveEngineBridgeNotifier extends Notifier<List<RiverStation>> {
  StreamSubscription<BiharLiveFeed>? _sub;

  @override
  List<RiverStation> build() {
    if (!BiharLiveEngine.instance.running) BiharLiveEngine.instance.start();
    _sub?.cancel();
    _sub = BiharLiveEngine.instance.stream.listen(_onFeed);
    ref.onDispose(() => _sub?.cancel());
    final existing = BiharLiveEngine.instance.latest;
    return existing != null ? _convert(existing) : [];
  }

  void _onFeed(BiharLiveFeed feed) {
    state = _convert(feed);
    if (kDebugMode) {
      debugPrint('[LiveEngineBridge] ${state.length} stations from engine feed');
    }
  }

  List<RiverStation> _convert(BiharLiveFeed feed) {
    final result = <RiverStation>[];

    for (final item in feed.items) {
      if (item.kind != FeedItemKind.riverGauge &&
          item.kind != FeedItemKind.barrage    &&
          item.kind != FeedItemKind.telemetry) continue;
      if (item.id == 'rtdas|__sync_marker__') continue;

      final rawVal  = item.value ?? '';
      final numStr  = rawVal.replaceAll(RegExp(r'[^0-9.]'), '');
      final level   = double.tryParse(numStr);
      final hasData = level != null && level > 0;

      final normName = _norm(item.title);
      final thresh   = _lookupThreshold(normName);

      if (!hasData) {
        final river = thresh?.river
            ?? (item.raw['river'] as String?)?.trim()
            ?? item.subtitle;
        result.add(RiverStation(
          city:        item.title,
          state:       (item.raw['state'] as String?)?.trim() ?? 'Bihar',
          river:       river,
          station:     item.title,
          current:     -1,
          warning:     thresh?.warning ?? 0,
          danger:      thresh?.danger  ?? 0,
          hfl:         thresh?.hfl     ?? 0,
          lastUpdated: '--:--',
          dataSource:  item.source.name.toUpperCase(),
          isLive:      false,
          lat:         _kCoords[normName]?.lat,
          lon:         _kCoords[normName]?.lon,
          liveStatus:  'NO_DATA',
        ));
        continue;
      }

      // Only use verified thresholds — never derive from current level
      // Stations with no threshold get danger=0 so they never trigger alerts
      final warning = thresh?.warning ?? 0.0;
      final danger  = thresh?.danger  ?? 0.0;
      final hfl     = thresh?.hfl     ?? 0.0;

      final river = (item.raw['river'] as String?)?.trim().isNotEmpty == true
          ? item.raw['river'] as String
          : thresh?.river ?? item.subtitle;
      final stateStr = (item.raw['state'] as String?)?.trim().isNotEmpty == true
          ? item.raw['state'] as String
          : 'Bihar';

      result.add(RiverStation(
        city:        item.title,
        state:       stateStr,
        river:       river,
        station:     item.title,
        current:     level,
        warning:     warning,
        danger:      danger,
        hfl:         hfl,
        lastUpdated:
            '${item.fetchedAt.hour.toString().padLeft(2, '0')}:'
            '${item.fetchedAt.minute.toString().padLeft(2, '0')}',
        dataSource:  item.source.name.toUpperCase(),
        isLive:      true,
        lat:         _kCoords[normName]?.lat,
        lon:         _kCoords[normName]?.lon,
        liveStatus:  item.dangerLevel,
      ));
    }
    return result;
  }
}

final liveEngineStationsProvider =
    NotifierProvider<LiveEngineBridgeNotifier, List<RiverStation>>(
        LiveEngineBridgeNotifier.new);
