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
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

PumpStation _$PumpStationFromJson(Map<String, dynamic> json) {
  return _PumpStation.fromJson(json);
}

/// @nodoc
mixin _$PumpStation {
  String get id => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String get location => throw _privateConstructorUsedError;
  double get latitude => throw _privateConstructorUsedError;
  double get longitude => throw _privateConstructorUsedError;
  PumpStationStatus get status => throw _privateConstructorUsedError;
  double get capacityLitersPerSecond => throw _privateConstructorUsedError;
  double get currentFlowRate => throw _privateConstructorUsedError;
  String? get districtName => throw _privateConstructorUsedError;
  String? get lastInspectedAt => throw _privateConstructorUsedError;
  String? get notes => throw _privateConstructorUsedError;

  /// Serializes this PumpStation to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of PumpStation
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
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
      String location,
      double latitude,
      double longitude,
      PumpStationStatus status,
      double capacityLitersPerSecond,
      double currentFlowRate,
      String? districtName,
      String? lastInspectedAt,
      String? notes});
}

/// @nodoc
class _$PumpStationCopyWithImpl<$Res, $Val extends PumpStation>
    implements $PumpStationCopyWith<$Res> {
  _$PumpStationCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of PumpStation
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? location = null,
    Object? latitude = null,
    Object? longitude = null,
    Object? status = null,
    Object? capacityLitersPerSecond = null,
    Object? currentFlowRate = null,
    Object? districtName = freezed,
    Object? lastInspectedAt = freezed,
    Object? notes = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      location: null == location
          ? _value.location
          : location // ignore: cast_nullable_to_non_nullable
              as String,
      latitude: null == latitude
          ? _value.latitude
          : latitude // ignore: cast_nullable_to_non_nullable
              as double,
      longitude: null == longitude
          ? _value.longitude
          : longitude // ignore: cast_nullable_to_non_nullable
              as double,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as PumpStationStatus,
      capacityLitersPerSecond: null == capacityLitersPerSecond
          ? _value.capacityLitersPerSecond
          : capacityLitersPerSecond // ignore: cast_nullable_to_non_nullable
              as double,
      currentFlowRate: null == currentFlowRate
          ? _value.currentFlowRate
          : currentFlowRate // ignore: cast_nullable_to_non_nullable
              as double,
      districtName: freezed == districtName
          ? _value.districtName
          : districtName // ignore: cast_nullable_to_non_nullable
              as String?,
      lastInspectedAt: freezed == lastInspectedAt
          ? _value.lastInspectedAt
          : lastInspectedAt // ignore: cast_nullable_to_non_nullable
              as String?,
      notes: freezed == notes
          ? _value.notes
          : notes // ignore: cast_nullable_to_non_nullable
              as String?,
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
      String location,
      double latitude,
      double longitude,
      PumpStationStatus status,
      double capacityLitersPerSecond,
      double currentFlowRate,
      String? districtName,
      String? lastInspectedAt,
      String? notes});
}

/// @nodoc
class __$$PumpStationImplCopyWithImpl<$Res>
    extends _$PumpStationCopyWithImpl<$Res, _$PumpStationImpl>
    implements _$$PumpStationImplCopyWith<$Res> {
  __$$PumpStationImplCopyWithImpl(
      _$PumpStationImpl _value, $Res Function(_$PumpStationImpl) _then)
      : super(_value, _then);

  /// Create a copy of PumpStation
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? location = null,
    Object? latitude = null,
    Object? longitude = null,
    Object? status = null,
    Object? capacityLitersPerSecond = null,
    Object? currentFlowRate = null,
    Object? districtName = freezed,
    Object? lastInspectedAt = freezed,
    Object? notes = freezed,
  }) {
    return _then(_$PumpStationImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      location: null == location
          ? _value.location
          : location // ignore: cast_nullable_to_non_nullable
              as String,
      latitude: null == latitude
          ? _value.latitude
          : latitude // ignore: cast_nullable_to_non_nullable
              as double,
      longitude: null == longitude
          ? _value.longitude
          : longitude // ignore: cast_nullable_to_non_nullable
              as double,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as PumpStationStatus,
      capacityLitersPerSecond: null == capacityLitersPerSecond
          ? _value.capacityLitersPerSecond
          : capacityLitersPerSecond // ignore: cast_nullable_to_non_nullable
              as double,
      currentFlowRate: null == currentFlowRate
          ? _value.currentFlowRate
          : currentFlowRate // ignore: cast_nullable_to_non_nullable
              as double,
      districtName: freezed == districtName
          ? _value.districtName
          : districtName // ignore: cast_nullable_to_non_nullable
              as String?,
      lastInspectedAt: freezed == lastInspectedAt
          ? _value.lastInspectedAt
          : lastInspectedAt // ignore: cast_nullable_to_non_nullable
              as String?,
      notes: freezed == notes
          ? _value.notes
          : notes // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$PumpStationImpl implements _PumpStation {
  const _$PumpStationImpl(
      {required this.id,
      required this.name,
      required this.location,
      required this.latitude,
      required this.longitude,
      required this.status,
      required this.capacityLitersPerSecond,
      required this.currentFlowRate,
      this.districtName,
      this.lastInspectedAt,
      this.notes});

  factory _$PumpStationImpl.fromJson(Map<String, dynamic> json) =>
      _$$PumpStationImplFromJson(json);

  @override
  final String id;
  @override
  final String name;
  @override
  final String location;
  @override
  final double latitude;
  @override
  final double longitude;
  @override
  final PumpStationStatus status;
  @override
  final double capacityLitersPerSecond;
  @override
  final double currentFlowRate;
  @override
  final String? districtName;
  @override
  final String? lastInspectedAt;
  @override
  final String? notes;

  @override
  String toString() {
    return 'PumpStation(id: $id, name: $name, location: $location, latitude: $latitude, longitude: $longitude, status: $status, capacityLitersPerSecond: $capacityLitersPerSecond, currentFlowRate: $currentFlowRate, districtName: $districtName, lastInspectedAt: $lastInspectedAt, notes: $notes)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PumpStationImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.location, location) ||
                other.location == location) &&
            (identical(other.latitude, latitude) ||
                other.latitude == latitude) &&
            (identical(other.longitude, longitude) ||
                other.longitude == longitude) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(
                    other.capacityLitersPerSecond, capacityLitersPerSecond) ||
                other.capacityLitersPerSecond == capacityLitersPerSecond) &&
            (identical(other.currentFlowRate, currentFlowRate) ||
                other.currentFlowRate == currentFlowRate) &&
            (identical(other.districtName, districtName) ||
                other.districtName == districtName) &&
            (identical(other.lastInspectedAt, lastInspectedAt) ||
                other.lastInspectedAt == lastInspectedAt) &&
            (identical(other.notes, notes) || other.notes == notes));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      name,
      location,
      latitude,
      longitude,
      status,
      capacityLitersPerSecond,
      currentFlowRate,
      districtName,
      lastInspectedAt,
      notes);

  /// Create a copy of PumpStation
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PumpStationImplCopyWith<_$PumpStationImpl> get copyWith =>
      __$$PumpStationImplCopyWithImpl<_$PumpStationImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$PumpStationImplToJson(
      this,
    );
  }
}

abstract class _PumpStation implements PumpStation {
  const factory _PumpStation(
      {required final String id,
      required final String name,
      required final String location,
      required final double latitude,
      required final double longitude,
      required final PumpStationStatus status,
      required final double capacityLitersPerSecond,
      required final double currentFlowRate,
      final String? districtName,
      final String? lastInspectedAt,
      final String? notes}) = _$PumpStationImpl;

  factory _PumpStation.fromJson(Map<String, dynamic> json) =
      _$PumpStationImpl.fromJson;

  @override
  String get id;
  @override
  String get name;
  @override
  String get location;
  @override
  double get latitude;
  @override
  double get longitude;
  @override
  PumpStationStatus get status;
  @override
  double get capacityLitersPerSecond;
  @override
  double get currentFlowRate;
  @override
  String? get districtName;
  @override
  String? get lastInspectedAt;
  @override
  String? get notes;

  /// Create a copy of PumpStation
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PumpStationImplCopyWith<_$PumpStationImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
