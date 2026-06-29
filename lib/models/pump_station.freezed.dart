// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'pump_station.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not allowed to call it directly');

/// @nodoc
mixin _$PumpStation {
  String get id => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String? get district => throw _privateConstructorUsedError;
  String get state => throw _privateConstructorUsedError;
  double? get locationLat => throw _privateConstructorUsedError;
  double? get locationLng => throw _privateConstructorUsedError;
  StationStatus get status => throw _privateConstructorUsedError;
  double? get capacityLps => throw _privateConstructorUsedError;
  DateTime? get installedAt => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;
  DateTime get updatedAt => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $PumpStationCopyWith<PumpStation> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PumpStationCopyWith<$Res> {
  factory $PumpStationCopyWith(
          PumpStation value, $Res Function(PumpStation) then) =
      _$PumpStationCopyWithImpl<$Res, PumpStation>;
  @useResult
  $Res call(
      {String id,
      String name,
      String? district,
      String state,
      double? locationLat,
      double? locationLng,
      StationStatus status,
      double? capacityLps,
      DateTime? installedAt,
      DateTime createdAt,
      DateTime updatedAt});
}

/// @nodoc
class _$PumpStationCopyWithImpl<$Res, $Val extends PumpStation>
    implements $PumpStationCopyWith<$Res> {
  _$PumpStationCopyWithImpl(this._value, this._then);

  final $Val _value;
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call(
      {Object? id = null,
      Object? name = null,
      Object? district = freezed,
      Object? state = null,
      Object? locationLat = freezed,
      Object? locationLng = freezed,
      Object? status = null,
      Object? capacityLps = freezed,
      Object? installedAt = freezed,
      Object? createdAt = null,
      Object? updatedAt = null}) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id as String,
      name: null == name
          ? _value.name
          : name as String,
      district: freezed == district
          ? _value.district
          : district as String?,
      state: null == state
          ? _value.state
          : state as String,
      locationLat: freezed == locationLat
          ? _value.locationLat
          : locationLat as double?,
      locationLng: freezed == locationLng
          ? _value.locationLng
          : locationLng as double?,
      status: null == status
          ? _value.status
          : status as StationStatus,
      capacityLps: freezed == capacityLps
          ? _value.capacityLps
          : capacityLps as double?,
      installedAt: freezed == installedAt
          ? _value.installedAt
          : installedAt as DateTime?,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt as DateTime,
      updatedAt: null == updatedAt
          ? _value.updatedAt
          : updatedAt as DateTime,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$PumpStationImplCopyWith<$Res>
    implements $PumpStationCopyWith<$Res> {
  factory _$$PumpStationImplCopyWith(
          _$PumpStationImpl value, $Res Function(_$PumpStationImpl) then) =
      __$$PumpStationImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String name,
      String? district,
      String state,
      double? locationLat,
      double? locationLng,
      StationStatus status,
      double? capacityLps,
      DateTime? installedAt,
      DateTime createdAt,
      DateTime updatedAt});
}

/// @nodoc
class __$$PumpStationImplCopyWithImpl<$Res>
    extends _$PumpStationCopyWithImpl<$Res, _$PumpStationImpl>
    implements _$$PumpStationImplCopyWith<$Res> {
  __$$PumpStationImplCopyWithImpl(
      _$PumpStationImpl _value, $Res Function(_$PumpStationImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call(
      {Object? id = null,
      Object? name = null,
      Object? district = freezed,
      Object? state = null,
      Object? locationLat = freezed,
      Object? locationLng = freezed,
      Object? status = null,
      Object? capacityLps = freezed,
      Object? installedAt = freezed,
      Object? createdAt = null,
      Object? updatedAt = null}) {
    return _then(_$PumpStationImpl(
      id: null == id ? _value.id : id as String,
      name: null == name ? _value.name : name as String,
      district: freezed == district ? _value.district : district as String?,
      state: null == state ? _value.state : state as String,
      locationLat: freezed == locationLat ? _value.locationLat : locationLat as double?,
      locationLng: freezed == locationLng ? _value.locationLng : locationLng as double?,
      status: null == status ? _value.status : status as StationStatus,
      capacityLps: freezed == capacityLps ? _value.capacityLps : capacityLps as double?,
      installedAt: freezed == installedAt ? _value.installedAt : installedAt as DateTime?,
      createdAt: null == createdAt ? _value.createdAt : createdAt as DateTime,
      updatedAt: null == updatedAt ? _value.updatedAt : updatedAt as DateTime,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$PumpStationImpl implements _PumpStation {
  const _$PumpStationImpl(
      {required this.id,
      required this.name,
      this.district,
      this.state = 'Bihar',
      this.locationLat,
      this.locationLng,
      this.status = StationStatus.inactive,
      this.capacityLps,
      this.installedAt,
      required this.createdAt,
      required this.updatedAt});

  factory _$PumpStationImpl.fromJson(Map<String, dynamic> json) =>
      _$$PumpStationImplFromJson(json);

  @override
  final String id;
  @override
  final String name;
  @override
  final String? district;
  @override
  @JsonKey()
  final String state;
  @override
  final double? locationLat;
  @override
  final double? locationLng;
  @override
  @JsonKey()
  final StationStatus status;
  @override
  final double? capacityLps;
  @override
  final DateTime? installedAt;
  @override
  final DateTime createdAt;
  @override
  final DateTime updatedAt;

  @override
  String toString() {
    return 'PumpStation(id: $id, name: $name, district: $district, state: $state, locationLat: $locationLat, locationLng: $locationLng, status: $status, capacityLps: $capacityLps, installedAt: $installedAt, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PumpStationImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.district, district) || other.district == district) &&
            (identical(other.state, state) || other.state == state) &&
            (identical(other.locationLat, locationLat) || other.locationLat == locationLat) &&
            (identical(other.locationLng, locationLng) || other.locationLng == locationLng) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.capacityLps, capacityLps) || other.capacityLps == capacityLps) &&
            (identical(other.installedAt, installedAt) || other.installedAt == installedAt) &&
            (identical(other.createdAt, createdAt) || other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(runtimeType, id, name, district, state, locationLat, locationLng, status, capacityLps, installedAt, createdAt, updatedAt);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$PumpStationImplCopyWith<_$PumpStationImpl> get copyWith =>
      __$$PumpStationImplCopyWithImpl<_$PumpStationImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$PumpStationImplToJson(this);
  }
}

abstract class _PumpStation implements PumpStation {
  const factory _PumpStation(
      {required final String id,
      required final String name,
      final String? district,
      final String state,
      final double? locationLat,
      final double? locationLng,
      final StationStatus status,
      final double? capacityLps,
      final DateTime? installedAt,
      required final DateTime createdAt,
      required final DateTime updatedAt}) = _$PumpStationImpl;

  @override
  String get id;
  @override
  String get name;
  @override
  String? get district;
  @override
  String get state;
  @override
  double? get locationLat;
  @override
  double? get locationLng;
  @override
  StationStatus get status;
  @override
  double? get capacityLps;
  @override
  DateTime? get installedAt;
  @override
  DateTime get createdAt;
  @override
  DateTime get updatedAt;
  @override
  @JsonKey(ignore: true)
  _$$PumpStationImplCopyWith<_$PumpStationImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

// ──────────────────────────────────────────
// MotorLog
// ──────────────────────────────────────────

/// @nodoc
mixin _$MotorLog {
  int get id => throw _privateConstructorUsedError;
  String get pumpStationId => throw _privateConstructorUsedError;
  String? get triggeredBy => throw _privateConstructorUsedError;
  MotorAction get action => throw _privateConstructorUsedError;
  String? get reason => throw _privateConstructorUsedError;
  int? get waterLevelRefId => throw _privateConstructorUsedError;
  DateTime get loggedAt => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $MotorLogCopyWith<MotorLog> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $MotorLogCopyWith<$Res> {
  factory $MotorLogCopyWith(MotorLog value, $Res Function(MotorLog) then) =
      _$MotorLogCopyWithImpl<$Res, MotorLog>;
  @useResult
  $Res call(
      {int id,
      String pumpStationId,
      String? triggeredBy,
      MotorAction action,
      String? reason,
      int? waterLevelRefId,
      DateTime loggedAt});
}

/// @nodoc
class _$MotorLogCopyWithImpl<$Res, $Val extends MotorLog>
    implements $MotorLogCopyWith<$Res> {
  _$MotorLogCopyWithImpl(this._value, this._then);
  final $Val _value;
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call(
      {Object? id = null,
      Object? pumpStationId = null,
      Object? triggeredBy = freezed,
      Object? action = null,
      Object? reason = freezed,
      Object? waterLevelRefId = freezed,
      Object? loggedAt = null}) {
    return _then(_value.copyWith(
      id: null == id ? _value.id : id as int,
      pumpStationId: null == pumpStationId ? _value.pumpStationId : pumpStationId as String,
      triggeredBy: freezed == triggeredBy ? _value.triggeredBy : triggeredBy as String?,
      action: null == action ? _value.action : action as MotorAction,
      reason: freezed == reason ? _value.reason : reason as String?,
      waterLevelRefId: freezed == waterLevelRefId ? _value.waterLevelRefId : waterLevelRefId as int?,
      loggedAt: null == loggedAt ? _value.loggedAt : loggedAt as DateTime,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$MotorLogImplCopyWith<$Res>
    implements $MotorLogCopyWith<$Res> {
  factory _$$MotorLogImplCopyWith(
          _$MotorLogImpl value, $Res Function(_$MotorLogImpl) then) =
      __$$MotorLogImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {int id,
      String pumpStationId,
      String? triggeredBy,
      MotorAction action,
      String? reason,
      int? waterLevelRefId,
      DateTime loggedAt});
}

/// @nodoc
class __$$MotorLogImplCopyWithImpl<$Res>
    extends _$MotorLogCopyWithImpl<$Res, _$MotorLogImpl>
    implements _$$MotorLogImplCopyWith<$Res> {
  __$$MotorLogImplCopyWithImpl(
      _$MotorLogImpl _value, $Res Function(_$MotorLogImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call(
      {Object? id = null,
      Object? pumpStationId = null,
      Object? triggeredBy = freezed,
      Object? action = null,
      Object? reason = freezed,
      Object? waterLevelRefId = freezed,
      Object? loggedAt = null}) {
    return _then(_$MotorLogImpl(
      id: null == id ? _value.id : id as int,
      pumpStationId: null == pumpStationId ? _value.pumpStationId : pumpStationId as String,
      triggeredBy: freezed == triggeredBy ? _value.triggeredBy : triggeredBy as String?,
      action: null == action ? _value.action : action as MotorAction,
      reason: freezed == reason ? _value.reason : reason as String?,
      waterLevelRefId: freezed == waterLevelRefId ? _value.waterLevelRefId : waterLevelRefId as int?,
      loggedAt: null == loggedAt ? _value.loggedAt : loggedAt as DateTime,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$MotorLogImpl implements _MotorLog {
  const _$MotorLogImpl(
      {required this.id,
      required this.pumpStationId,
      this.triggeredBy,
      required this.action,
      this.reason,
      this.waterLevelRefId,
      required this.loggedAt});

  factory _$MotorLogImpl.fromJson(Map<String, dynamic> json) =>
      _$$MotorLogImplFromJson(json);

  @override
  final int id;
  @override
  final String pumpStationId;
  @override
  final String? triggeredBy;
  @override
  final MotorAction action;
  @override
  final String? reason;
  @override
  final int? waterLevelRefId;
  @override
  final DateTime loggedAt;

  @override
  String toString() {
    return 'MotorLog(id: $id, pumpStationId: $pumpStationId, triggeredBy: $triggeredBy, action: $action, reason: $reason, waterLevelRefId: $waterLevelRefId, loggedAt: $loggedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MotorLogImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.pumpStationId, pumpStationId) || other.pumpStationId == pumpStationId) &&
            (identical(other.triggeredBy, triggeredBy) || other.triggeredBy == triggeredBy) &&
            (identical(other.action, action) || other.action == action) &&
            (identical(other.reason, reason) || other.reason == reason) &&
            (identical(other.waterLevelRefId, waterLevelRefId) || other.waterLevelRefId == waterLevelRefId) &&
            (identical(other.loggedAt, loggedAt) || other.loggedAt == loggedAt));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(runtimeType, id, pumpStationId, triggeredBy, action, reason, waterLevelRefId, loggedAt);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$MotorLogImplCopyWith<_$MotorLogImpl> get copyWith =>
      __$$MotorLogImplCopyWithImpl<_$MotorLogImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$MotorLogImplToJson(this);
  }
}

abstract class _MotorLog implements MotorLog {
  const factory _MotorLog(
      {required final int id,
      required final String pumpStationId,
      final String? triggeredBy,
      required final MotorAction action,
      final String? reason,
      final int? waterLevelRefId,
      required final DateTime loggedAt}) = _$MotorLogImpl;

  @override
  int get id;
  @override
  String get pumpStationId;
  @override
  String? get triggeredBy;
  @override
  MotorAction get action;
  @override
  String? get reason;
  @override
  int? get waterLevelRefId;
  @override
  DateTime get loggedAt;
  @override
  @JsonKey(ignore: true)
  _$$MotorLogImplCopyWith<_$MotorLogImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
