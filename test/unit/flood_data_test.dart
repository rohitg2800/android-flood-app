// test/unit/flood_data_test.dart
// I-15: fromJson null safety and round-trip serialisation

import 'package:flutter_test/flutter_test.dart';
import 'package:flood_watch/models/flood_data.dart';

void main() {
  final validJson = <String, dynamic>{
    'station': 'Birpur',
    'river': 'Kosi',
    'state': 'Bihar',
    'district': 'Supaul',
    'latitude': 26.5127,
    'longitude': 86.5912,
    'currentLevel': 74.25,
    'warningLevel': 73.70,
    'dangerLevel': 76.02,
    'floodLevel': 76.02,
    'normalLevel': 71.48,
    'status': 'warning',
    'trend': 'rising',
    'lastUpdated': '2026-06-19T10:00:00Z',
    'discharge': null,
  };

  group('FloodData.fromJson', () {
    test('parses valid JSON without throwing', () {
      expect(() => FloodData.fromJson(validJson), returnsNormally);
    });

    test('station name parsed correctly', () {
      final data = FloodData.fromJson(validJson);
      expect(data.station, equals('Birpur'));
    });

    test('currentLevel parsed as double', () {
      final data = FloodData.fromJson(validJson);
      expect(data.currentLevel, equals(74.25));
    });

    test('null discharge does not throw', () {
      final data = FloodData.fromJson(validJson);
      expect(data.discharge, isNull);
    });

    test('toJson round-trips correctly', () {
      final data  = FloodData.fromJson(validJson);
      final data2 = FloodData.fromJson(data.toJson());
      expect(data2.station,      equals(data.station));
      expect(data2.currentLevel, equals(data.currentLevel));
    });

    test('missing optional fields do not throw', () {
      final minimal = Map<String, dynamic>.from(validJson)
        ..remove('discharge')
        ..remove('trend');
      expect(() => FloodData.fromJson(minimal), returnsNormally);
    });
  });

  group('FloodData level comparisons', () {
    late FloodData data;
    setUp(() => data = FloodData.fromJson(validJson));

    test('currentLevel above warningLevel', () {
      expect(data.currentLevel, greaterThan(data.warningLevel));
    });

    test('currentLevel below dangerLevel', () {
      expect(data.currentLevel, lessThan(data.dangerLevel));
    });
  });
}
