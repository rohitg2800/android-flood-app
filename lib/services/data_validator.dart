// lib/services/data_validator.dart
// Data Integrity layer — validates raw CWC/WRD payloads before they reach
// any Riverpod provider or UI widget.
//
// Usage:
//   final result = DataValidator.validateStation(rawJson);
//   result.when(ok: (s) => use(s), err: (f) => handleFailure(f));
library;

import 'dart:convert';
import '../models/flood_data.dart';
import '../services/befiqr_cwc_service.dart';

// ─── Failure taxonomy ─────────────────────────────────────────────────────────

enum ValidationFailureKind {
  malformedJson,      // parse error / null / wrong type
  emptyPayload,       // list or map is present but empty
  missingFields,      // required key absent
  levelOutOfRange,    // water level outside 0.5–250 m
  staleTimestamp,     // fetchedAt older than 30 min
  negativeLevel,      // sanity: currentLevel < 0
}

class ValidationFailure {
  final ValidationFailureKind kind;
  final String                detail;
  const ValidationFailure(this.kind, this.detail);

  /// Human-readable short label — shown in UI chips / banners
  String get label => switch (kind) {
    ValidationFailureKind.malformedJson    => 'MALFORMED',
    ValidationFailureKind.emptyPayload     => 'NO DATA',
    ValidationFailureKind.missingFields    => 'INCOMPLETE',
    ValidationFailureKind.levelOutOfRange  => 'RANGE ERR',
    ValidationFailureKind.staleTimestamp   => 'STALE',
    ValidationFailureKind.negativeLevel    => 'NEGATIVE LVL',
  };

  /// Maps to UI state: staleTimestamp → DataQualityState.stale, rest → sourceError
  DataQualityState get uiState => switch (kind) {
    ValidationFailureKind.staleTimestamp => DataQualityState.stale,
    _                                    => DataQualityState.sourceError,
  };

  @override String toString() => 'ValidationFailure(${kind.name}: $detail)';
}

// ─── Result type ──────────────────────────────────────────────────────────────

sealed class ValidationResult<T> {
  const ValidationResult();

  bool get isOk  => this is ValidationOk<T>;
  bool get isErr => this is ValidationErr<T>;

  R when<R>({
    required R Function(T value)                ok,
    required R Function(ValidationFailure fail) err,
  }) {
    return switch (this) {
      ValidationOk<T>  v => ok(v.value),
      ValidationErr<T> e => err(e.failure),
    };
  }

  T?                 get valueOrNull   => isOk  ? (this as ValidationOk<T>).value    : null;
  ValidationFailure? get failureOrNull => isErr ? (this as ValidationErr<T>).failure : null;
}

final class ValidationOk<T>  extends ValidationResult<T> {
  final T value;
  const ValidationOk(this.value);
}

final class ValidationErr<T> extends ValidationResult<T> {
  final ValidationFailure failure;
  const ValidationErr(this.failure);
}

// ─── UI data quality states ───────────────────────────────────────────────────

enum DataQualityState {
  fresh,       // passed all checks
  stale,       // timestamp > 30 min
  sourceError, // structural / range / missing field problem
}

// ─── Constraints ─────────────────────────────────────────────────────────────

class ValidatorConstraints {
  /// Realistic river water level range in metres
  /// (covers Birpur barrage @ 214 m, upper bound 250 m for safety)
  static const double minLevel = 0.5;
  static const double maxLevel = 250.0;
  static const Duration maxAge = Duration(minutes: 30);

  static const List<String> requiredCwcKeys = [
    'river', 'site', 'currentLevel', 'dangerLevel', 'fetchedAt',
  ];
  static const List<String> requiredFloodKeys = [
    'city', 'state', 'currentLevel', 'warningLevel',
    'dangerLevel', 'safeLevel', 'riskLevel', 'status', 'lastUpdated',
  ];
}

// ─── DataValidator ────────────────────────────────────────────────────────────

abstract final class DataValidator {

  // ── CwcStation from parsed object ─────────────────────────────────────────

  static ValidationResult<CwcStation> validateStation(CwcStation s) {
    // 1. Negative level
    if (s.currentLevel < 0) {
      return ValidationErr(ValidationFailure(
        ValidationFailureKind.negativeLevel,
        '${s.site}: currentLevel=${s.currentLevel}',
      ));
    }
    // 2. Realistic range
    if (s.currentLevel < ValidatorConstraints.minLevel ||
        s.currentLevel > ValidatorConstraints.maxLevel) {
      return ValidationErr(ValidationFailure(
        ValidationFailureKind.levelOutOfRange,
        '${s.site}: ${s.currentLevel}m not in '
        '[${ValidatorConstraints.minLevel}, ${ValidatorConstraints.maxLevel}]',
      ));
    }
    if (s.dangerLevel < ValidatorConstraints.minLevel ||
        s.dangerLevel > ValidatorConstraints.maxLevel) {
      return ValidationErr(ValidationFailure(
        ValidationFailureKind.levelOutOfRange,
        '${s.site} dangerLevel=${s.dangerLevel}m out of range',
      ));
    }
    // 3. Stale timestamp
    final age = DateTime.now().difference(s.fetchedAt);
    if (age > ValidatorConstraints.maxAge) {
      return ValidationErr(ValidationFailure(
        ValidationFailureKind.staleTimestamp,
        '${s.site}: data is ${age.inMinutes}m old',
      ));
    }
    return ValidationOk(s);
  }

  // ── Raw JSON map → CwcStation ──────────────────────────────────────────────

  static ValidationResult<CwcStation> validateStationJson(
      Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) {
      return ValidationErr(ValidationFailure(
        ValidationFailureKind.emptyPayload, 'null or empty map',
      ));
    }
    for (final key in ValidatorConstraints.requiredCwcKeys) {
      if (!json.containsKey(key) || json[key] == null) {
        return ValidationErr(ValidationFailure(
          ValidationFailureKind.missingFields, 'missing key: $key',
        ));
      }
    }
    try {
      final station = CwcStation.fromJson(json);
      return validateStation(station);
    } catch (e) {
      return ValidationErr(ValidationFailure(
        ValidationFailureKind.malformedJson, e.toString(),
      ));
    }
  }

  // ── Raw JSON string → List<CwcStation> ────────────────────────────────────

  static ValidationResult<List<CwcStation>> validateStationListJson(
      String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return ValidationErr(ValidationFailure(
        ValidationFailureKind.emptyPayload, 'empty string',
      ));
    }
    List<dynamic> decoded;
    try {
      decoded = jsonDecode(raw) as List<dynamic>;
    } catch (e) {
      return ValidationErr(ValidationFailure(
        ValidationFailureKind.malformedJson, e.toString(),
      ));
    }
    if (decoded.isEmpty) {
      return ValidationErr(ValidationFailure(
        ValidationFailureKind.emptyPayload, 'list has 0 items',
      ));
    }
    final valid    = <CwcStation>[];
    final rejected = <ValidationFailure>[];
    for (final item in decoded) {
      if (item is! Map<String, dynamic>) {
        rejected.add(ValidationFailure(
            ValidationFailureKind.malformedJson, 'item is not a map'));
        continue;
      }
      validateStationJson(item).when(
        ok:  valid.add,
        err: rejected.add,
      );
    }
    if (valid.isEmpty) {
      return ValidationErr(ValidationFailure(
        ValidationFailureKind.emptyPayload,
        'all ${decoded.length} items failed: ${rejected.first.detail}',
      ));
    }
    return ValidationOk(valid);
  }

  // ── FloodData from parsed object ───────────────────────────────────────────

  static ValidationResult<FloodData> validateFloodData(FloodData f) {
    if (f.currentLevel < ValidatorConstraints.minLevel ||
        f.currentLevel > ValidatorConstraints.maxLevel) {
      return ValidationErr(ValidationFailure(
        ValidationFailureKind.levelOutOfRange,
        '${f.city}: ${f.currentLevel}m out of range',
      ));
    }
    final _lu = f.lastUpdated;
    if (_lu != null) {
      final age = DateTime.now().difference(_lu);
      if (age > ValidatorConstraints.maxAge) {
        return ValidationErr(ValidationFailure(
          ValidationFailureKind.staleTimestamp,
          '${f.city}: data is ${age.inMinutes}m old',
        ));
      }
    }
    return ValidationOk(f);
  }

  // ── Bulk partition: (valid, failures) ────────────────────────────────────

  static ({List<T> valid, List<ValidationFailure> failures})
      partitionList<T>(
          List<T> items,
          ValidationResult<T> Function(T) validate) {
    final valid    = <T>[];
    final failures = <ValidationFailure>[];
    for (final item in items) {
      validate(item).when(ok: valid.add, err: failures.add);
    }
    return (valid: valid, failures: failures);
  }
}
