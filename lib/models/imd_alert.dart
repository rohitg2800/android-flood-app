// lib/models/imd_alert.dart
// OpsFlood — ImdAlert model (IMD weather alerts)
library;

import 'package:flutter/foundation.dart';

// ─── ImdSeverity ─────────────────────────────────────────────────────────────

enum ImdSeverity {
  green,
  yellow,
  orange,
  red;

  /// Higher = more severe.
  int get order => index;

  String get label => switch (this) {
        ImdSeverity.green => 'Green',
        ImdSeverity.yellow => 'Yellow',
        ImdSeverity.orange => 'Orange',
        ImdSeverity.red => 'Red',
      };

  static ImdSeverity fromString(String? s) {
    switch (s?.toLowerCase()) {
      case 'red':
        return ImdSeverity.red;
      case 'orange':
        return ImdSeverity.orange;
      case 'yellow':
        return ImdSeverity.yellow;
      default:
        return ImdSeverity.green;
    }
  }
}

// ─── ImdAlert ─────────────────────────────────────────────────────────────────

@immutable
class ImdAlert {
  const ImdAlert({
    required this.id,
    required this.state,
    required this.district,
    required this.headline,
    required this.description,
    required this.severity,
    required this.issuedAt,
    required this.validUntil,
    this.isNew = true,
  });

  final String id;
  final String state;
  final String district;
  final String headline;
  final String description;
  final ImdSeverity severity;
  final DateTime issuedAt;
  final DateTime validUntil;
  final bool isNew;

  /// Construct from raw dynamic map coming from LiveFetchEngine.
  factory ImdAlert.fromRaw(dynamic raw) {
    final m = raw as Map<String, dynamic>;
    return ImdAlert(
      id: (m['id'] ?? m['alert_id'] ?? '').toString(),
      state: (m['state'] ?? '').toString(),
      district: (m['district'] ?? '').toString(),
      headline: (m['headline'] ?? m['title'] ?? '').toString(),
      description: (m['description'] ?? m['body'] ?? '').toString(),
      severity: ImdSeverity.fromString(m['severity']?.toString()),
      issuedAt:
          DateTime.tryParse(m['issued_at']?.toString() ?? '') ?? DateTime.now(),
      validUntil: DateTime.tryParse(m['valid_until']?.toString() ?? '') ??
          DateTime.now().add(const Duration(hours: 24)),
      isNew: (m['is_new'] as bool?) ?? true,
    );
  }

  ImdAlert copyWith({
    String? id,
    String? state,
    String? district,
    String? headline,
    String? description,
    ImdSeverity? severity,
    DateTime? issuedAt,
    DateTime? validUntil,
    bool? isNew,
  }) {
    return ImdAlert(
      id: id ?? this.id,
      state: state ?? this.state,
      district: district ?? this.district,
      headline: headline ?? this.headline,
      description: description ?? this.description,
      severity: severity ?? this.severity,
      issuedAt: issuedAt ?? this.issuedAt,
      validUntil: validUntil ?? this.validUntil,
      isNew: isNew ?? this.isNew,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ImdAlert && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'ImdAlert($id, $severity, $state)';
}
