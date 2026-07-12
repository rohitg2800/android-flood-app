// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'community_report.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

CommunityReport _$CommunityReportFromJson(Map<String, dynamic> json) {
  return _CommunityReport.fromJson(json);
}

/// @nodoc
mixin _$CommunityReport {
  String get id => throw _privateConstructorUsedError;
  String get title => throw _privateConstructorUsedError;
  String get description => throw _privateConstructorUsedError;
  String get reportType => throw _privateConstructorUsedError;
  double get latitude => throw _privateConstructorUsedError;
  double get longitude => throw _privateConstructorUsedError;
  String get status => throw _privateConstructorUsedError;
  String get submittedBy => throw _privateConstructorUsedError;
  DateTime get submittedAt => throw _privateConstructorUsedError;
  String? get imageUrl => throw _privateConstructorUsedError;
  String? get address => throw _privateConstructorUsedError;
  int get upvotes => throw _privateConstructorUsedError;

  /// Serializes this CommunityReport to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of CommunityReport
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $CommunityReportCopyWith<CommunityReport> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CommunityReportCopyWith<$Res> {
  factory $CommunityReportCopyWith(
          CommunityReport value, $Res Function(CommunityReport) then) =
      _$CommunityReportCopyWithImpl<$Res, CommunityReport>;
  @useResult
  $Res call(
      {String id,
      String title,
      String description,
      String reportType,
      double latitude,
      double longitude,
      String status,
      String submittedBy,
      DateTime submittedAt,
      String? imageUrl,
      String? address,
      int upvotes});
}

/// @nodoc
class _$CommunityReportCopyWithImpl<$Res, $Val extends CommunityReport>
    implements $CommunityReportCopyWith<$Res> {
  _$CommunityReportCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of CommunityReport
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? description = null,
    Object? reportType = null,
    Object? latitude = null,
    Object? longitude = null,
    Object? status = null,
    Object? submittedBy = null,
    Object? submittedAt = null,
    Object? imageUrl = freezed,
    Object? address = freezed,
    Object? upvotes = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      title: null == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      description: null == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String,
      reportType: null == reportType
          ? _value.reportType
          : reportType // ignore: cast_nullable_to_non_nullable
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
              as String,
      submittedBy: null == submittedBy
          ? _value.submittedBy
          : submittedBy // ignore: cast_nullable_to_non_nullable
              as String,
      submittedAt: null == submittedAt
          ? _value.submittedAt
          : submittedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      imageUrl: freezed == imageUrl
          ? _value.imageUrl
          : imageUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      address: freezed == address
          ? _value.address
          : address // ignore: cast_nullable_to_non_nullable
              as String?,
      upvotes: null == upvotes
          ? _value.upvotes
          : upvotes // ignore: cast_nullable_to_non_nullable
              as int,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$CommunityReportImplCopyWith<$Res>
    implements $CommunityReportCopyWith<$Res> {
  factory _$$CommunityReportImplCopyWith(_$CommunityReportImpl value,
          $Res Function(_$CommunityReportImpl) then) =
      __$$CommunityReportImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String title,
      String description,
      String reportType,
      double latitude,
      double longitude,
      String status,
      String submittedBy,
      DateTime submittedAt,
      String? imageUrl,
      String? address,
      int upvotes});
}

/// @nodoc
class __$$CommunityReportImplCopyWithImpl<$Res>
    extends _$CommunityReportCopyWithImpl<$Res, _$CommunityReportImpl>
    implements _$$CommunityReportImplCopyWith<$Res> {
  __$$CommunityReportImplCopyWithImpl(
      _$CommunityReportImpl _value, $Res Function(_$CommunityReportImpl) _then)
      : super(_value, _then);

  /// Create a copy of CommunityReport
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? description = null,
    Object? reportType = null,
    Object? latitude = null,
    Object? longitude = null,
    Object? status = null,
    Object? submittedBy = null,
    Object? submittedAt = null,
    Object? imageUrl = freezed,
    Object? address = freezed,
    Object? upvotes = null,
  }) {
    return _then(_$CommunityReportImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      title: null == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      description: null == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String,
      reportType: null == reportType
          ? _value.reportType
          : reportType // ignore: cast_nullable_to_non_nullable
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
              as String,
      submittedBy: null == submittedBy
          ? _value.submittedBy
          : submittedBy // ignore: cast_nullable_to_non_nullable
              as String,
      submittedAt: null == submittedAt
          ? _value.submittedAt
          : submittedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      imageUrl: freezed == imageUrl
          ? _value.imageUrl
          : imageUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      address: freezed == address
          ? _value.address
          : address // ignore: cast_nullable_to_non_nullable
              as String?,
      upvotes: null == upvotes
          ? _value.upvotes
          : upvotes // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$CommunityReportImpl implements _CommunityReport {
  const _$CommunityReportImpl(
      {required this.id,
      required this.title,
      required this.description,
      required this.reportType,
      required this.latitude,
      required this.longitude,
      required this.status,
      required this.submittedBy,
      required this.submittedAt,
      this.imageUrl,
      this.address,
      this.upvotes = 0});

  factory _$CommunityReportImpl.fromJson(Map<String, dynamic> json) =>
      _$$CommunityReportImplFromJson(json);

  @override
  final String id;
  @override
  final String title;
  @override
  final String description;
  @override
  final String reportType;
  @override
  final double latitude;
  @override
  final double longitude;
  @override
  final String status;
  @override
  final String submittedBy;
  @override
  final DateTime submittedAt;
  @override
  final String? imageUrl;
  @override
  final String? address;
  @override
  @JsonKey()
  final int upvotes;

  @override
  String toString() {
    return 'CommunityReport(id: $id, title: $title, description: $description, reportType: $reportType, latitude: $latitude, longitude: $longitude, status: $status, submittedBy: $submittedBy, submittedAt: $submittedAt, imageUrl: $imageUrl, address: $address, upvotes: $upvotes)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CommunityReportImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.reportType, reportType) ||
                other.reportType == reportType) &&
            (identical(other.latitude, latitude) ||
                other.latitude == latitude) &&
            (identical(other.longitude, longitude) ||
                other.longitude == longitude) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.submittedBy, submittedBy) ||
                other.submittedBy == submittedBy) &&
            (identical(other.submittedAt, submittedAt) ||
                other.submittedAt == submittedAt) &&
            (identical(other.imageUrl, imageUrl) ||
                other.imageUrl == imageUrl) &&
            (identical(other.address, address) || other.address == address) &&
            (identical(other.upvotes, upvotes) || other.upvotes == upvotes));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      title,
      description,
      reportType,
      latitude,
      longitude,
      status,
      submittedBy,
      submittedAt,
      imageUrl,
      address,
      upvotes);

  /// Create a copy of CommunityReport
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$CommunityReportImplCopyWith<_$CommunityReportImpl> get copyWith =>
      __$$CommunityReportImplCopyWithImpl<_$CommunityReportImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$CommunityReportImplToJson(
      this,
    );
  }
}

abstract class _CommunityReport implements CommunityReport {
  const factory _CommunityReport(
      {required final String id,
      required final String title,
      required final String description,
      required final String reportType,
      required final double latitude,
      required final double longitude,
      required final String status,
      required final String submittedBy,
      required final DateTime submittedAt,
      final String? imageUrl,
      final String? address,
      final int upvotes}) = _$CommunityReportImpl;

  factory _CommunityReport.fromJson(Map<String, dynamic> json) =
      _$CommunityReportImpl.fromJson;

  @override
  String get id;
  @override
  String get title;
  @override
  String get description;
  @override
  String get reportType;
  @override
  double get latitude;
  @override
  double get longitude;
  @override
  String get status;
  @override
  String get submittedBy;
  @override
  DateTime get submittedAt;
  @override
  String? get imageUrl;
  @override
  String? get address;
  @override
  int get upvotes;

  /// Create a copy of CommunityReport
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$CommunityReportImplCopyWith<_$CommunityReportImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
