import 'package:flutter/foundation.dart';

/// Resolves issue #33: Government & Agency Integration Support
/// Abstract interface for all external government data sources
abstract class DataSourceRepository {
  String get sourceName;
  String get sourceAbbreviation;
  Duration get refreshInterval;

  Future<List<Map<String, dynamic>>> fetchAlerts();
  Future<List<Map<String, dynamic>>> fetchStationReadings();
  Future<bool> healthCheck();
}

/// CWC Repository - Central Water Commission
/// Already integrated via scraping; this wraps it cleanly
class CWCRepository implements DataSourceRepository {
  @override
  String get sourceName => 'Central Water Commission';
  @override
  String get sourceAbbreviation => 'CWC';
  @override
  Duration get refreshInterval => const Duration(hours: 1);

  @override
  Future<List<Map<String, dynamic>>> fetchAlerts() async {
    // TODO: Wrap existing CWC scraper output here
    debugPrint('CWC: fetching flood alerts...');
    return [];
  }

  @override
  Future<List<Map<String, dynamic>>> fetchStationReadings() async {
    // TODO: Call existing CWC scraper -> returns station readings
    debugPrint('CWC: fetching station readings...');
    return [];
  }

  @override
  Future<bool> healthCheck() async {
    // TODO: Check if CWC site is reachable
    return true;
  }
}

/// IMD Repository - India Meteorological Department
class IMDRepository implements DataSourceRepository {
  @override
  String get sourceName => 'India Meteorological Department';
  @override
  String get sourceAbbreviation => 'IMD';
  @override
  Duration get refreshInterval => const Duration(hours: 3);

  // IMD RSS/API base — Bihar district warnings
  // static const String _baseUrl = 'https://mausam.imd.gov.in'; // unused

  @override
  Future<List<Map<String, dynamic>>> fetchAlerts() async {
    debugPrint('IMD: fetching district rainfall warnings...');
    // TODO: Scrape IMD colour-coded warnings (Yellow/Orange/Red)
    // GET $_baseUrl/backend/assets/json/statewise_fdwarning.json
    // Filter for Bihar districts
    return [];
  }

  @override
  Future<List<Map<String, dynamic>>> fetchStationReadings() async {
    // IMD provides rainfall data, not river levels
    debugPrint('IMD: fetching rainfall observations...');
    return [];
  }

  @override
  Future<bool> healthCheck() async {
    // TODO: Ping IMD endpoint
    return true;
  }
}

/// NDMA Repository - National Disaster Management Authority
class NDMARepository implements DataSourceRepository {
  @override
  String get sourceName => 'National Disaster Management Authority';
  @override
  String get sourceAbbreviation => 'NDMA';
  @override
  Duration get refreshInterval => const Duration(hours: 6);

  @override
  Future<List<Map<String, dynamic>>> fetchAlerts() async {
    debugPrint('NDMA: fetching national flood bulletins...');
    // TODO: Parse NDMA flood bulletin PDF/HTML from ndma.gov.in
    return [];
  }

  @override
  Future<List<Map<String, dynamic>>> fetchStationReadings() async {
    return []; // NDMA does not provide station readings
  }

  @override
  Future<bool> healthCheck() async {
    return true;
  }
}

/// SDMA Bihar Repository - State Disaster Management Authority
class SDMABiharRepository implements DataSourceRepository {
  @override
  String get sourceName => 'SDMA Bihar';
  @override
  String get sourceAbbreviation => 'SDMA';
  @override
  Duration get refreshInterval => const Duration(hours: 4);

  @override
  Future<List<Map<String, dynamic>>> fetchAlerts() async {
    debugPrint('SDMA Bihar: fetching state flood alerts...');
    // TODO: Scrape aapda.bih.nic.in for state alerts
    return [];
  }

  @override
  Future<List<Map<String, dynamic>>> fetchStationReadings() async {
    return [];
  }

  @override
  Future<bool> healthCheck() async {
    return true;
  }
}

/// Aggregator - merges all sources into a single alert stream
class AggregatedDataService {
  final List<DataSourceRepository> _repositories = [
    CWCRepository(),
    IMDRepository(),
    NDMARepository(),
    SDMABiharRepository(),
  ];

  Future<List<Map<String, dynamic>>> fetchAllAlerts() async {
    final results = <Map<String, dynamic>>[];
    for (final repo in _repositories) {
      try {
        final alerts = await repo.fetchAlerts();
        for (final alert in alerts) {
          results.add({...alert, 'source': repo.sourceAbbreviation});
        }
      } catch (e) {
        // One source failing does NOT break others
        debugPrint('${repo.sourceAbbreviation} fetch failed: $e');
      }
    }
    return results;
  }

  Future<Map<String, bool>> checkAllSources() async {
    final health = <String, bool>{};
    for (final repo in _repositories) {
      try {
        health[repo.sourceAbbreviation] = await repo.healthCheck();
      } catch (_) {
        health[repo.sourceAbbreviation] = false;
      }
    }
    return health;
  }
}
