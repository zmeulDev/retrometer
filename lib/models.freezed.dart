// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$StageConfig {
  String get id => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  double get targetAvgSpeed => throw _privateConstructorUsedError;
  double get maxSpeedLimit => throw _privateConstructorUsedError;
  double? get endLatitude => throw _privateConstructorUsedError;
  double? get endLongitude => throw _privateConstructorUsedError;
  double get endGeofenceRadiusM => throw _privateConstructorUsedError;
  bool get autoStop => throw _privateConstructorUsedError;
  double get totalDistanceKm => throw _privateConstructorUsedError;
  int get allocatedTimeSeconds => throw _privateConstructorUsedError;

  /// Create a copy of StageConfig
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $StageConfigCopyWith<StageConfig> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $StageConfigCopyWith<$Res> {
  factory $StageConfigCopyWith(
    StageConfig value,
    $Res Function(StageConfig) then,
  ) = _$StageConfigCopyWithImpl<$Res, StageConfig>;
  @useResult
  $Res call({
    String id,
    String name,
    double targetAvgSpeed,
    double maxSpeedLimit,
    double? endLatitude,
    double? endLongitude,
    double endGeofenceRadiusM,
    bool autoStop,
    double totalDistanceKm,
    int allocatedTimeSeconds,
  });
}

/// @nodoc
class _$StageConfigCopyWithImpl<$Res, $Val extends StageConfig>
    implements $StageConfigCopyWith<$Res> {
  _$StageConfigCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of StageConfig
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? targetAvgSpeed = null,
    Object? maxSpeedLimit = null,
    Object? endLatitude = freezed,
    Object? endLongitude = freezed,
    Object? endGeofenceRadiusM = null,
    Object? autoStop = null,
    Object? totalDistanceKm = null,
    Object? allocatedTimeSeconds = null,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            name: null == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                      as String,
            targetAvgSpeed: null == targetAvgSpeed
                ? _value.targetAvgSpeed
                : targetAvgSpeed // ignore: cast_nullable_to_non_nullable
                      as double,
            maxSpeedLimit: null == maxSpeedLimit
                ? _value.maxSpeedLimit
                : maxSpeedLimit // ignore: cast_nullable_to_non_nullable
                      as double,
            endLatitude: freezed == endLatitude
                ? _value.endLatitude
                : endLatitude // ignore: cast_nullable_to_non_nullable
                      as double?,
            endLongitude: freezed == endLongitude
                ? _value.endLongitude
                : endLongitude // ignore: cast_nullable_to_non_nullable
                      as double?,
            endGeofenceRadiusM: null == endGeofenceRadiusM
                ? _value.endGeofenceRadiusM
                : endGeofenceRadiusM // ignore: cast_nullable_to_non_nullable
                      as double,
            autoStop: null == autoStop
                ? _value.autoStop
                : autoStop // ignore: cast_nullable_to_non_nullable
                      as bool,
            totalDistanceKm: null == totalDistanceKm
                ? _value.totalDistanceKm
                : totalDistanceKm // ignore: cast_nullable_to_non_nullable
                      as double,
            allocatedTimeSeconds: null == allocatedTimeSeconds
                ? _value.allocatedTimeSeconds
                : allocatedTimeSeconds // ignore: cast_nullable_to_non_nullable
                      as int,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$StageConfigImplCopyWith<$Res>
    implements $StageConfigCopyWith<$Res> {
  factory _$$StageConfigImplCopyWith(
    _$StageConfigImpl value,
    $Res Function(_$StageConfigImpl) then,
  ) = __$$StageConfigImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String name,
    double targetAvgSpeed,
    double maxSpeedLimit,
    double? endLatitude,
    double? endLongitude,
    double endGeofenceRadiusM,
    bool autoStop,
    double totalDistanceKm,
    int allocatedTimeSeconds,
  });
}

/// @nodoc
class __$$StageConfigImplCopyWithImpl<$Res>
    extends _$StageConfigCopyWithImpl<$Res, _$StageConfigImpl>
    implements _$$StageConfigImplCopyWith<$Res> {
  __$$StageConfigImplCopyWithImpl(
    _$StageConfigImpl _value,
    $Res Function(_$StageConfigImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of StageConfig
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? targetAvgSpeed = null,
    Object? maxSpeedLimit = null,
    Object? endLatitude = freezed,
    Object? endLongitude = freezed,
    Object? endGeofenceRadiusM = null,
    Object? autoStop = null,
    Object? totalDistanceKm = null,
    Object? allocatedTimeSeconds = null,
  }) {
    return _then(
      _$StageConfigImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        name: null == name
            ? _value.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        targetAvgSpeed: null == targetAvgSpeed
            ? _value.targetAvgSpeed
            : targetAvgSpeed // ignore: cast_nullable_to_non_nullable
                  as double,
        maxSpeedLimit: null == maxSpeedLimit
            ? _value.maxSpeedLimit
            : maxSpeedLimit // ignore: cast_nullable_to_non_nullable
                  as double,
        endLatitude: freezed == endLatitude
            ? _value.endLatitude
            : endLatitude // ignore: cast_nullable_to_non_nullable
                  as double?,
        endLongitude: freezed == endLongitude
            ? _value.endLongitude
            : endLongitude // ignore: cast_nullable_to_non_nullable
                  as double?,
        endGeofenceRadiusM: null == endGeofenceRadiusM
            ? _value.endGeofenceRadiusM
            : endGeofenceRadiusM // ignore: cast_nullable_to_non_nullable
                  as double,
        autoStop: null == autoStop
            ? _value.autoStop
            : autoStop // ignore: cast_nullable_to_non_nullable
                  as bool,
        totalDistanceKm: null == totalDistanceKm
            ? _value.totalDistanceKm
            : totalDistanceKm // ignore: cast_nullable_to_non_nullable
                  as double,
        allocatedTimeSeconds: null == allocatedTimeSeconds
            ? _value.allocatedTimeSeconds
            : allocatedTimeSeconds // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// @nodoc

class _$StageConfigImpl implements _StageConfig {
  const _$StageConfigImpl({
    required this.id,
    this.name = 'Stage 1',
    this.targetAvgSpeed = 40.0,
    this.maxSpeedLimit = 60.0,
    this.endLatitude,
    this.endLongitude,
    this.endGeofenceRadiusM = 200.0,
    this.autoStop = true,
    this.totalDistanceKm = 0.0,
    this.allocatedTimeSeconds = 0,
  });

  @override
  final String id;
  @override
  @JsonKey()
  final String name;
  @override
  @JsonKey()
  final double targetAvgSpeed;
  @override
  @JsonKey()
  final double maxSpeedLimit;
  @override
  final double? endLatitude;
  @override
  final double? endLongitude;
  @override
  @JsonKey()
  final double endGeofenceRadiusM;
  @override
  @JsonKey()
  final bool autoStop;
  @override
  @JsonKey()
  final double totalDistanceKm;
  @override
  @JsonKey()
  final int allocatedTimeSeconds;

  @override
  String toString() {
    return 'StageConfig(id: $id, name: $name, targetAvgSpeed: $targetAvgSpeed, maxSpeedLimit: $maxSpeedLimit, endLatitude: $endLatitude, endLongitude: $endLongitude, endGeofenceRadiusM: $endGeofenceRadiusM, autoStop: $autoStop, totalDistanceKm: $totalDistanceKm, allocatedTimeSeconds: $allocatedTimeSeconds)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$StageConfigImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.targetAvgSpeed, targetAvgSpeed) ||
                other.targetAvgSpeed == targetAvgSpeed) &&
            (identical(other.maxSpeedLimit, maxSpeedLimit) ||
                other.maxSpeedLimit == maxSpeedLimit) &&
            (identical(other.endLatitude, endLatitude) ||
                other.endLatitude == endLatitude) &&
            (identical(other.endLongitude, endLongitude) ||
                other.endLongitude == endLongitude) &&
            (identical(other.endGeofenceRadiusM, endGeofenceRadiusM) ||
                other.endGeofenceRadiusM == endGeofenceRadiusM) &&
            (identical(other.autoStop, autoStop) ||
                other.autoStop == autoStop) &&
            (identical(other.totalDistanceKm, totalDistanceKm) ||
                other.totalDistanceKm == totalDistanceKm) &&
            (identical(other.allocatedTimeSeconds, allocatedTimeSeconds) ||
                other.allocatedTimeSeconds == allocatedTimeSeconds));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    name,
    targetAvgSpeed,
    maxSpeedLimit,
    endLatitude,
    endLongitude,
    endGeofenceRadiusM,
    autoStop,
    totalDistanceKm,
    allocatedTimeSeconds,
  );

  /// Create a copy of StageConfig
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$StageConfigImplCopyWith<_$StageConfigImpl> get copyWith =>
      __$$StageConfigImplCopyWithImpl<_$StageConfigImpl>(this, _$identity);
}

abstract class _StageConfig implements StageConfig {
  const factory _StageConfig({
    required final String id,
    final String name,
    final double targetAvgSpeed,
    final double maxSpeedLimit,
    final double? endLatitude,
    final double? endLongitude,
    final double endGeofenceRadiusM,
    final bool autoStop,
    final double totalDistanceKm,
    final int allocatedTimeSeconds,
  }) = _$StageConfigImpl;

  @override
  String get id;
  @override
  String get name;
  @override
  double get targetAvgSpeed;
  @override
  double get maxSpeedLimit;
  @override
  double? get endLatitude;
  @override
  double? get endLongitude;
  @override
  double get endGeofenceRadiusM;
  @override
  bool get autoStop;
  @override
  double get totalDistanceKm;
  @override
  int get allocatedTimeSeconds;

  /// Create a copy of StageConfig
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$StageConfigImplCopyWith<_$StageConfigImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$StageTelemetry {
  DateTime? get startTime => throw _privateConstructorUsedError;
  double get currentDistance => throw _privateConstructorUsedError;
  double get currentSpeed => throw _privateConstructorUsedError;
  StageStatus get status => throw _privateConstructorUsedError;
  double? get latitude => throw _privateConstructorUsedError;
  double? get longitude => throw _privateConstructorUsedError;

  /// Create a copy of StageTelemetry
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $StageTelemetryCopyWith<StageTelemetry> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $StageTelemetryCopyWith<$Res> {
  factory $StageTelemetryCopyWith(
    StageTelemetry value,
    $Res Function(StageTelemetry) then,
  ) = _$StageTelemetryCopyWithImpl<$Res, StageTelemetry>;
  @useResult
  $Res call({
    DateTime? startTime,
    double currentDistance,
    double currentSpeed,
    StageStatus status,
    double? latitude,
    double? longitude,
  });
}

/// @nodoc
class _$StageTelemetryCopyWithImpl<$Res, $Val extends StageTelemetry>
    implements $StageTelemetryCopyWith<$Res> {
  _$StageTelemetryCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of StageTelemetry
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? startTime = freezed,
    Object? currentDistance = null,
    Object? currentSpeed = null,
    Object? status = null,
    Object? latitude = freezed,
    Object? longitude = freezed,
  }) {
    return _then(
      _value.copyWith(
            startTime: freezed == startTime
                ? _value.startTime
                : startTime // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            currentDistance: null == currentDistance
                ? _value.currentDistance
                : currentDistance // ignore: cast_nullable_to_non_nullable
                      as double,
            currentSpeed: null == currentSpeed
                ? _value.currentSpeed
                : currentSpeed // ignore: cast_nullable_to_non_nullable
                      as double,
            status: null == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                      as StageStatus,
            latitude: freezed == latitude
                ? _value.latitude
                : latitude // ignore: cast_nullable_to_non_nullable
                      as double?,
            longitude: freezed == longitude
                ? _value.longitude
                : longitude // ignore: cast_nullable_to_non_nullable
                      as double?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$StageTelemetryImplCopyWith<$Res>
    implements $StageTelemetryCopyWith<$Res> {
  factory _$$StageTelemetryImplCopyWith(
    _$StageTelemetryImpl value,
    $Res Function(_$StageTelemetryImpl) then,
  ) = __$$StageTelemetryImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    DateTime? startTime,
    double currentDistance,
    double currentSpeed,
    StageStatus status,
    double? latitude,
    double? longitude,
  });
}

/// @nodoc
class __$$StageTelemetryImplCopyWithImpl<$Res>
    extends _$StageTelemetryCopyWithImpl<$Res, _$StageTelemetryImpl>
    implements _$$StageTelemetryImplCopyWith<$Res> {
  __$$StageTelemetryImplCopyWithImpl(
    _$StageTelemetryImpl _value,
    $Res Function(_$StageTelemetryImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of StageTelemetry
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? startTime = freezed,
    Object? currentDistance = null,
    Object? currentSpeed = null,
    Object? status = null,
    Object? latitude = freezed,
    Object? longitude = freezed,
  }) {
    return _then(
      _$StageTelemetryImpl(
        startTime: freezed == startTime
            ? _value.startTime
            : startTime // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        currentDistance: null == currentDistance
            ? _value.currentDistance
            : currentDistance // ignore: cast_nullable_to_non_nullable
                  as double,
        currentSpeed: null == currentSpeed
            ? _value.currentSpeed
            : currentSpeed // ignore: cast_nullable_to_non_nullable
                  as double,
        status: null == status
            ? _value.status
            : status // ignore: cast_nullable_to_non_nullable
                  as StageStatus,
        latitude: freezed == latitude
            ? _value.latitude
            : latitude // ignore: cast_nullable_to_non_nullable
                  as double?,
        longitude: freezed == longitude
            ? _value.longitude
            : longitude // ignore: cast_nullable_to_non_nullable
                  as double?,
      ),
    );
  }
}

/// @nodoc

class _$StageTelemetryImpl implements _StageTelemetry {
  const _$StageTelemetryImpl({
    this.startTime,
    this.currentDistance = 0.0,
    this.currentSpeed = 0.0,
    this.status = StageStatus.idle,
    this.latitude,
    this.longitude,
  });

  @override
  final DateTime? startTime;
  @override
  @JsonKey()
  final double currentDistance;
  @override
  @JsonKey()
  final double currentSpeed;
  @override
  @JsonKey()
  final StageStatus status;
  @override
  final double? latitude;
  @override
  final double? longitude;

  @override
  String toString() {
    return 'StageTelemetry(startTime: $startTime, currentDistance: $currentDistance, currentSpeed: $currentSpeed, status: $status, latitude: $latitude, longitude: $longitude)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$StageTelemetryImpl &&
            (identical(other.startTime, startTime) ||
                other.startTime == startTime) &&
            (identical(other.currentDistance, currentDistance) ||
                other.currentDistance == currentDistance) &&
            (identical(other.currentSpeed, currentSpeed) ||
                other.currentSpeed == currentSpeed) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.latitude, latitude) ||
                other.latitude == latitude) &&
            (identical(other.longitude, longitude) ||
                other.longitude == longitude));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    startTime,
    currentDistance,
    currentSpeed,
    status,
    latitude,
    longitude,
  );

  /// Create a copy of StageTelemetry
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$StageTelemetryImplCopyWith<_$StageTelemetryImpl> get copyWith =>
      __$$StageTelemetryImplCopyWithImpl<_$StageTelemetryImpl>(
        this,
        _$identity,
      );
}

abstract class _StageTelemetry implements StageTelemetry {
  const factory _StageTelemetry({
    final DateTime? startTime,
    final double currentDistance,
    final double currentSpeed,
    final StageStatus status,
    final double? latitude,
    final double? longitude,
  }) = _$StageTelemetryImpl;

  @override
  DateTime? get startTime;
  @override
  double get currentDistance;
  @override
  double get currentSpeed;
  @override
  StageStatus get status;
  @override
  double? get latitude;
  @override
  double? get longitude;

  /// Create a copy of StageTelemetry
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$StageTelemetryImplCopyWith<_$StageTelemetryImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$RallyState {
  StageConfig get config => throw _privateConstructorUsedError;
  StageTelemetry get telemetry => throw _privateConstructorUsedError;

  /// Create a copy of RallyState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $RallyStateCopyWith<RallyState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $RallyStateCopyWith<$Res> {
  factory $RallyStateCopyWith(
    RallyState value,
    $Res Function(RallyState) then,
  ) = _$RallyStateCopyWithImpl<$Res, RallyState>;
  @useResult
  $Res call({StageConfig config, StageTelemetry telemetry});

  $StageConfigCopyWith<$Res> get config;
  $StageTelemetryCopyWith<$Res> get telemetry;
}

/// @nodoc
class _$RallyStateCopyWithImpl<$Res, $Val extends RallyState>
    implements $RallyStateCopyWith<$Res> {
  _$RallyStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of RallyState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? config = null, Object? telemetry = null}) {
    return _then(
      _value.copyWith(
            config: null == config
                ? _value.config
                : config // ignore: cast_nullable_to_non_nullable
                      as StageConfig,
            telemetry: null == telemetry
                ? _value.telemetry
                : telemetry // ignore: cast_nullable_to_non_nullable
                      as StageTelemetry,
          )
          as $Val,
    );
  }

  /// Create a copy of RallyState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $StageConfigCopyWith<$Res> get config {
    return $StageConfigCopyWith<$Res>(_value.config, (value) {
      return _then(_value.copyWith(config: value) as $Val);
    });
  }

  /// Create a copy of RallyState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $StageTelemetryCopyWith<$Res> get telemetry {
    return $StageTelemetryCopyWith<$Res>(_value.telemetry, (value) {
      return _then(_value.copyWith(telemetry: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$RallyStateImplCopyWith<$Res>
    implements $RallyStateCopyWith<$Res> {
  factory _$$RallyStateImplCopyWith(
    _$RallyStateImpl value,
    $Res Function(_$RallyStateImpl) then,
  ) = __$$RallyStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({StageConfig config, StageTelemetry telemetry});

  @override
  $StageConfigCopyWith<$Res> get config;
  @override
  $StageTelemetryCopyWith<$Res> get telemetry;
}

/// @nodoc
class __$$RallyStateImplCopyWithImpl<$Res>
    extends _$RallyStateCopyWithImpl<$Res, _$RallyStateImpl>
    implements _$$RallyStateImplCopyWith<$Res> {
  __$$RallyStateImplCopyWithImpl(
    _$RallyStateImpl _value,
    $Res Function(_$RallyStateImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of RallyState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? config = null, Object? telemetry = null}) {
    return _then(
      _$RallyStateImpl(
        config: null == config
            ? _value.config
            : config // ignore: cast_nullable_to_non_nullable
                  as StageConfig,
        telemetry: null == telemetry
            ? _value.telemetry
            : telemetry // ignore: cast_nullable_to_non_nullable
                  as StageTelemetry,
      ),
    );
  }
}

/// @nodoc

class _$RallyStateImpl implements _RallyState {
  const _$RallyStateImpl({
    this.config = const StageConfig(id: 'stage-1'),
    this.telemetry = const StageTelemetry(),
  });

  @override
  @JsonKey()
  final StageConfig config;
  @override
  @JsonKey()
  final StageTelemetry telemetry;

  @override
  String toString() {
    return 'RallyState(config: $config, telemetry: $telemetry)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$RallyStateImpl &&
            (identical(other.config, config) || other.config == config) &&
            (identical(other.telemetry, telemetry) ||
                other.telemetry == telemetry));
  }

  @override
  int get hashCode => Object.hash(runtimeType, config, telemetry);

  /// Create a copy of RallyState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$RallyStateImplCopyWith<_$RallyStateImpl> get copyWith =>
      __$$RallyStateImplCopyWithImpl<_$RallyStateImpl>(this, _$identity);
}

abstract class _RallyState implements RallyState {
  const factory _RallyState({
    final StageConfig config,
    final StageTelemetry telemetry,
  }) = _$RallyStateImpl;

  @override
  StageConfig get config;
  @override
  StageTelemetry get telemetry;

  /// Create a copy of RallyState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$RallyStateImplCopyWith<_$RallyStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$PlannedStage {
  String get id => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;

  /// Scheduled start (wall clock). `null` = no time trigger (location-only).
  DateTime? get startTime => throw _privateConstructorUsedError;
  double get targetAvgSpeed => throw _privateConstructorUsedError;
  double get maxSpeedLimit => throw _privateConstructorUsedError;

  /// Start geofence centre. `null` = no location trigger (time-only).
  double? get latitude => throw _privateConstructorUsedError;
  double? get longitude => throw _privateConstructorUsedError;
  double get geofenceRadiusM => throw _privateConstructorUsedError;
  bool get autoStart => throw _privateConstructorUsedError;
  bool get started => throw _privateConstructorUsedError;

  /// Finish location. Null when the crew didn't set one (no auto-stop).
  double? get endLatitude => throw _privateConstructorUsedError;
  double? get endLongitude => throw _privateConstructorUsedError;
  double get endGeofenceRadiusM => throw _privateConstructorUsedError;
  bool get autoStop => throw _privateConstructorUsedError;

  /// Crew-entered total stage length (km). 0 = not set.
  double get totalDistanceKm => throw _privateConstructorUsedError;

  /// Crew-entered total allocated time (seconds). 0 = not set.
  int get allocatedTimeSeconds => throw _privateConstructorUsedError;

  /// Create a copy of PlannedStage
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $PlannedStageCopyWith<PlannedStage> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PlannedStageCopyWith<$Res> {
  factory $PlannedStageCopyWith(
    PlannedStage value,
    $Res Function(PlannedStage) then,
  ) = _$PlannedStageCopyWithImpl<$Res, PlannedStage>;
  @useResult
  $Res call({
    String id,
    String name,
    DateTime? startTime,
    double targetAvgSpeed,
    double maxSpeedLimit,
    double? latitude,
    double? longitude,
    double geofenceRadiusM,
    bool autoStart,
    bool started,
    double? endLatitude,
    double? endLongitude,
    double endGeofenceRadiusM,
    bool autoStop,
    double totalDistanceKm,
    int allocatedTimeSeconds,
  });
}

/// @nodoc
class _$PlannedStageCopyWithImpl<$Res, $Val extends PlannedStage>
    implements $PlannedStageCopyWith<$Res> {
  _$PlannedStageCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of PlannedStage
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? startTime = freezed,
    Object? targetAvgSpeed = null,
    Object? maxSpeedLimit = null,
    Object? latitude = freezed,
    Object? longitude = freezed,
    Object? geofenceRadiusM = null,
    Object? autoStart = null,
    Object? started = null,
    Object? endLatitude = freezed,
    Object? endLongitude = freezed,
    Object? endGeofenceRadiusM = null,
    Object? autoStop = null,
    Object? totalDistanceKm = null,
    Object? allocatedTimeSeconds = null,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            name: null == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                      as String,
            startTime: freezed == startTime
                ? _value.startTime
                : startTime // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            targetAvgSpeed: null == targetAvgSpeed
                ? _value.targetAvgSpeed
                : targetAvgSpeed // ignore: cast_nullable_to_non_nullable
                      as double,
            maxSpeedLimit: null == maxSpeedLimit
                ? _value.maxSpeedLimit
                : maxSpeedLimit // ignore: cast_nullable_to_non_nullable
                      as double,
            latitude: freezed == latitude
                ? _value.latitude
                : latitude // ignore: cast_nullable_to_non_nullable
                      as double?,
            longitude: freezed == longitude
                ? _value.longitude
                : longitude // ignore: cast_nullable_to_non_nullable
                      as double?,
            geofenceRadiusM: null == geofenceRadiusM
                ? _value.geofenceRadiusM
                : geofenceRadiusM // ignore: cast_nullable_to_non_nullable
                      as double,
            autoStart: null == autoStart
                ? _value.autoStart
                : autoStart // ignore: cast_nullable_to_non_nullable
                      as bool,
            started: null == started
                ? _value.started
                : started // ignore: cast_nullable_to_non_nullable
                      as bool,
            endLatitude: freezed == endLatitude
                ? _value.endLatitude
                : endLatitude // ignore: cast_nullable_to_non_nullable
                      as double?,
            endLongitude: freezed == endLongitude
                ? _value.endLongitude
                : endLongitude // ignore: cast_nullable_to_non_nullable
                      as double?,
            endGeofenceRadiusM: null == endGeofenceRadiusM
                ? _value.endGeofenceRadiusM
                : endGeofenceRadiusM // ignore: cast_nullable_to_non_nullable
                      as double,
            autoStop: null == autoStop
                ? _value.autoStop
                : autoStop // ignore: cast_nullable_to_non_nullable
                      as bool,
            totalDistanceKm: null == totalDistanceKm
                ? _value.totalDistanceKm
                : totalDistanceKm // ignore: cast_nullable_to_non_nullable
                      as double,
            allocatedTimeSeconds: null == allocatedTimeSeconds
                ? _value.allocatedTimeSeconds
                : allocatedTimeSeconds // ignore: cast_nullable_to_non_nullable
                      as int,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$PlannedStageImplCopyWith<$Res>
    implements $PlannedStageCopyWith<$Res> {
  factory _$$PlannedStageImplCopyWith(
    _$PlannedStageImpl value,
    $Res Function(_$PlannedStageImpl) then,
  ) = __$$PlannedStageImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String name,
    DateTime? startTime,
    double targetAvgSpeed,
    double maxSpeedLimit,
    double? latitude,
    double? longitude,
    double geofenceRadiusM,
    bool autoStart,
    bool started,
    double? endLatitude,
    double? endLongitude,
    double endGeofenceRadiusM,
    bool autoStop,
    double totalDistanceKm,
    int allocatedTimeSeconds,
  });
}

/// @nodoc
class __$$PlannedStageImplCopyWithImpl<$Res>
    extends _$PlannedStageCopyWithImpl<$Res, _$PlannedStageImpl>
    implements _$$PlannedStageImplCopyWith<$Res> {
  __$$PlannedStageImplCopyWithImpl(
    _$PlannedStageImpl _value,
    $Res Function(_$PlannedStageImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of PlannedStage
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? startTime = freezed,
    Object? targetAvgSpeed = null,
    Object? maxSpeedLimit = null,
    Object? latitude = freezed,
    Object? longitude = freezed,
    Object? geofenceRadiusM = null,
    Object? autoStart = null,
    Object? started = null,
    Object? endLatitude = freezed,
    Object? endLongitude = freezed,
    Object? endGeofenceRadiusM = null,
    Object? autoStop = null,
    Object? totalDistanceKm = null,
    Object? allocatedTimeSeconds = null,
  }) {
    return _then(
      _$PlannedStageImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        name: null == name
            ? _value.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        startTime: freezed == startTime
            ? _value.startTime
            : startTime // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        targetAvgSpeed: null == targetAvgSpeed
            ? _value.targetAvgSpeed
            : targetAvgSpeed // ignore: cast_nullable_to_non_nullable
                  as double,
        maxSpeedLimit: null == maxSpeedLimit
            ? _value.maxSpeedLimit
            : maxSpeedLimit // ignore: cast_nullable_to_non_nullable
                  as double,
        latitude: freezed == latitude
            ? _value.latitude
            : latitude // ignore: cast_nullable_to_non_nullable
                  as double?,
        longitude: freezed == longitude
            ? _value.longitude
            : longitude // ignore: cast_nullable_to_non_nullable
                  as double?,
        geofenceRadiusM: null == geofenceRadiusM
            ? _value.geofenceRadiusM
            : geofenceRadiusM // ignore: cast_nullable_to_non_nullable
                  as double,
        autoStart: null == autoStart
            ? _value.autoStart
            : autoStart // ignore: cast_nullable_to_non_nullable
                  as bool,
        started: null == started
            ? _value.started
            : started // ignore: cast_nullable_to_non_nullable
                  as bool,
        endLatitude: freezed == endLatitude
            ? _value.endLatitude
            : endLatitude // ignore: cast_nullable_to_non_nullable
                  as double?,
        endLongitude: freezed == endLongitude
            ? _value.endLongitude
            : endLongitude // ignore: cast_nullable_to_non_nullable
                  as double?,
        endGeofenceRadiusM: null == endGeofenceRadiusM
            ? _value.endGeofenceRadiusM
            : endGeofenceRadiusM // ignore: cast_nullable_to_non_nullable
                  as double,
        autoStop: null == autoStop
            ? _value.autoStop
            : autoStop // ignore: cast_nullable_to_non_nullable
                  as bool,
        totalDistanceKm: null == totalDistanceKm
            ? _value.totalDistanceKm
            : totalDistanceKm // ignore: cast_nullable_to_non_nullable
                  as double,
        allocatedTimeSeconds: null == allocatedTimeSeconds
            ? _value.allocatedTimeSeconds
            : allocatedTimeSeconds // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// @nodoc

class _$PlannedStageImpl extends _PlannedStage {
  const _$PlannedStageImpl({
    required this.id,
    required this.name,
    this.startTime,
    this.targetAvgSpeed = 40.0,
    this.maxSpeedLimit = 60.0,
    this.latitude,
    this.longitude,
    this.geofenceRadiusM = 200.0,
    this.autoStart = true,
    this.started = false,
    this.endLatitude,
    this.endLongitude,
    this.endGeofenceRadiusM = 200.0,
    this.autoStop = true,
    this.totalDistanceKm = 0.0,
    this.allocatedTimeSeconds = 0,
  }) : super._();

  @override
  final String id;
  @override
  final String name;

  /// Scheduled start (wall clock). `null` = no time trigger (location-only).
  @override
  final DateTime? startTime;
  @override
  @JsonKey()
  final double targetAvgSpeed;
  @override
  @JsonKey()
  final double maxSpeedLimit;

  /// Start geofence centre. `null` = no location trigger (time-only).
  @override
  final double? latitude;
  @override
  final double? longitude;
  @override
  @JsonKey()
  final double geofenceRadiusM;
  @override
  @JsonKey()
  final bool autoStart;
  @override
  @JsonKey()
  final bool started;

  /// Finish location. Null when the crew didn't set one (no auto-stop).
  @override
  final double? endLatitude;
  @override
  final double? endLongitude;
  @override
  @JsonKey()
  final double endGeofenceRadiusM;
  @override
  @JsonKey()
  final bool autoStop;

  /// Crew-entered total stage length (km). 0 = not set.
  @override
  @JsonKey()
  final double totalDistanceKm;

  /// Crew-entered total allocated time (seconds). 0 = not set.
  @override
  @JsonKey()
  final int allocatedTimeSeconds;

  @override
  String toString() {
    return 'PlannedStage(id: $id, name: $name, startTime: $startTime, targetAvgSpeed: $targetAvgSpeed, maxSpeedLimit: $maxSpeedLimit, latitude: $latitude, longitude: $longitude, geofenceRadiusM: $geofenceRadiusM, autoStart: $autoStart, started: $started, endLatitude: $endLatitude, endLongitude: $endLongitude, endGeofenceRadiusM: $endGeofenceRadiusM, autoStop: $autoStop, totalDistanceKm: $totalDistanceKm, allocatedTimeSeconds: $allocatedTimeSeconds)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PlannedStageImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.startTime, startTime) ||
                other.startTime == startTime) &&
            (identical(other.targetAvgSpeed, targetAvgSpeed) ||
                other.targetAvgSpeed == targetAvgSpeed) &&
            (identical(other.maxSpeedLimit, maxSpeedLimit) ||
                other.maxSpeedLimit == maxSpeedLimit) &&
            (identical(other.latitude, latitude) ||
                other.latitude == latitude) &&
            (identical(other.longitude, longitude) ||
                other.longitude == longitude) &&
            (identical(other.geofenceRadiusM, geofenceRadiusM) ||
                other.geofenceRadiusM == geofenceRadiusM) &&
            (identical(other.autoStart, autoStart) ||
                other.autoStart == autoStart) &&
            (identical(other.started, started) || other.started == started) &&
            (identical(other.endLatitude, endLatitude) ||
                other.endLatitude == endLatitude) &&
            (identical(other.endLongitude, endLongitude) ||
                other.endLongitude == endLongitude) &&
            (identical(other.endGeofenceRadiusM, endGeofenceRadiusM) ||
                other.endGeofenceRadiusM == endGeofenceRadiusM) &&
            (identical(other.autoStop, autoStop) ||
                other.autoStop == autoStop) &&
            (identical(other.totalDistanceKm, totalDistanceKm) ||
                other.totalDistanceKm == totalDistanceKm) &&
            (identical(other.allocatedTimeSeconds, allocatedTimeSeconds) ||
                other.allocatedTimeSeconds == allocatedTimeSeconds));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    name,
    startTime,
    targetAvgSpeed,
    maxSpeedLimit,
    latitude,
    longitude,
    geofenceRadiusM,
    autoStart,
    started,
    endLatitude,
    endLongitude,
    endGeofenceRadiusM,
    autoStop,
    totalDistanceKm,
    allocatedTimeSeconds,
  );

  /// Create a copy of PlannedStage
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PlannedStageImplCopyWith<_$PlannedStageImpl> get copyWith =>
      __$$PlannedStageImplCopyWithImpl<_$PlannedStageImpl>(this, _$identity);
}

abstract class _PlannedStage extends PlannedStage {
  const factory _PlannedStage({
    required final String id,
    required final String name,
    final DateTime? startTime,
    final double targetAvgSpeed,
    final double maxSpeedLimit,
    final double? latitude,
    final double? longitude,
    final double geofenceRadiusM,
    final bool autoStart,
    final bool started,
    final double? endLatitude,
    final double? endLongitude,
    final double endGeofenceRadiusM,
    final bool autoStop,
    final double totalDistanceKm,
    final int allocatedTimeSeconds,
  }) = _$PlannedStageImpl;
  const _PlannedStage._() : super._();

  @override
  String get id;
  @override
  String get name;

  /// Scheduled start (wall clock). `null` = no time trigger (location-only).
  @override
  DateTime? get startTime;
  @override
  double get targetAvgSpeed;
  @override
  double get maxSpeedLimit;

  /// Start geofence centre. `null` = no location trigger (time-only).
  @override
  double? get latitude;
  @override
  double? get longitude;
  @override
  double get geofenceRadiusM;
  @override
  bool get autoStart;
  @override
  bool get started;

  /// Finish location. Null when the crew didn't set one (no auto-stop).
  @override
  double? get endLatitude;
  @override
  double? get endLongitude;
  @override
  double get endGeofenceRadiusM;
  @override
  bool get autoStop;

  /// Crew-entered total stage length (km). 0 = not set.
  @override
  double get totalDistanceKm;

  /// Crew-entered total allocated time (seconds). 0 = not set.
  @override
  int get allocatedTimeSeconds;

  /// Create a copy of PlannedStage
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PlannedStageImplCopyWith<_$PlannedStageImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$Competition {
  String get id => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String get location => throw _privateConstructorUsedError;

  /// First day of the event (optional). `null` = not set.
  DateTime? get startDate => throw _privateConstructorUsedError;

  /// Last day of the event (optional). `null` or equal to [startDate] means a
  /// single-day event. When set, must be on/after [startDate].
  DateTime? get endDate => throw _privateConstructorUsedError;
  String get pilot => throw _privateConstructorUsedError;
  String get copilot => throw _privateConstructorUsedError;
  String get car => throw _privateConstructorUsedError;
  String get category => throw _privateConstructorUsedError;
  int get totalTeams => throw _privateConstructorUsedError;
  String get contactPerson => throw _privateConstructorUsedError;
  String? get contactPhone => throw _privateConstructorUsedError;
  double get cost => throw _privateConstructorUsedError;
  int get overallStanding => throw _privateConstructorUsedError;
  int get categoryStanding => throw _privateConstructorUsedError;
  List<PlannedStage> get stages => throw _privateConstructorUsedError;

  /// Create a copy of Competition
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $CompetitionCopyWith<Competition> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CompetitionCopyWith<$Res> {
  factory $CompetitionCopyWith(
    Competition value,
    $Res Function(Competition) then,
  ) = _$CompetitionCopyWithImpl<$Res, Competition>;
  @useResult
  $Res call({
    String id,
    String name,
    String location,
    DateTime? startDate,
    DateTime? endDate,
    String pilot,
    String copilot,
    String car,
    String category,
    int totalTeams,
    String contactPerson,
    String? contactPhone,
    double cost,
    int overallStanding,
    int categoryStanding,
    List<PlannedStage> stages,
  });
}

/// @nodoc
class _$CompetitionCopyWithImpl<$Res, $Val extends Competition>
    implements $CompetitionCopyWith<$Res> {
  _$CompetitionCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Competition
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? location = null,
    Object? startDate = freezed,
    Object? endDate = freezed,
    Object? pilot = null,
    Object? copilot = null,
    Object? car = null,
    Object? category = null,
    Object? totalTeams = null,
    Object? contactPerson = null,
    Object? contactPhone = freezed,
    Object? cost = null,
    Object? overallStanding = null,
    Object? categoryStanding = null,
    Object? stages = null,
  }) {
    return _then(
      _value.copyWith(
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
            startDate: freezed == startDate
                ? _value.startDate
                : startDate // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            endDate: freezed == endDate
                ? _value.endDate
                : endDate // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            pilot: null == pilot
                ? _value.pilot
                : pilot // ignore: cast_nullable_to_non_nullable
                      as String,
            copilot: null == copilot
                ? _value.copilot
                : copilot // ignore: cast_nullable_to_non_nullable
                      as String,
            car: null == car
                ? _value.car
                : car // ignore: cast_nullable_to_non_nullable
                      as String,
            category: null == category
                ? _value.category
                : category // ignore: cast_nullable_to_non_nullable
                      as String,
            totalTeams: null == totalTeams
                ? _value.totalTeams
                : totalTeams // ignore: cast_nullable_to_non_nullable
                      as int,
            contactPerson: null == contactPerson
                ? _value.contactPerson
                : contactPerson // ignore: cast_nullable_to_non_nullable
                      as String,
            contactPhone: freezed == contactPhone
                ? _value.contactPhone
                : contactPhone // ignore: cast_nullable_to_non_nullable
                      as String?,
            cost: null == cost
                ? _value.cost
                : cost // ignore: cast_nullable_to_non_nullable
                      as double,
            overallStanding: null == overallStanding
                ? _value.overallStanding
                : overallStanding // ignore: cast_nullable_to_non_nullable
                      as int,
            categoryStanding: null == categoryStanding
                ? _value.categoryStanding
                : categoryStanding // ignore: cast_nullable_to_non_nullable
                      as int,
            stages: null == stages
                ? _value.stages
                : stages // ignore: cast_nullable_to_non_nullable
                      as List<PlannedStage>,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$CompetitionImplCopyWith<$Res>
    implements $CompetitionCopyWith<$Res> {
  factory _$$CompetitionImplCopyWith(
    _$CompetitionImpl value,
    $Res Function(_$CompetitionImpl) then,
  ) = __$$CompetitionImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String name,
    String location,
    DateTime? startDate,
    DateTime? endDate,
    String pilot,
    String copilot,
    String car,
    String category,
    int totalTeams,
    String contactPerson,
    String? contactPhone,
    double cost,
    int overallStanding,
    int categoryStanding,
    List<PlannedStage> stages,
  });
}

/// @nodoc
class __$$CompetitionImplCopyWithImpl<$Res>
    extends _$CompetitionCopyWithImpl<$Res, _$CompetitionImpl>
    implements _$$CompetitionImplCopyWith<$Res> {
  __$$CompetitionImplCopyWithImpl(
    _$CompetitionImpl _value,
    $Res Function(_$CompetitionImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of Competition
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? location = null,
    Object? startDate = freezed,
    Object? endDate = freezed,
    Object? pilot = null,
    Object? copilot = null,
    Object? car = null,
    Object? category = null,
    Object? totalTeams = null,
    Object? contactPerson = null,
    Object? contactPhone = freezed,
    Object? cost = null,
    Object? overallStanding = null,
    Object? categoryStanding = null,
    Object? stages = null,
  }) {
    return _then(
      _$CompetitionImpl(
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
        startDate: freezed == startDate
            ? _value.startDate
            : startDate // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        endDate: freezed == endDate
            ? _value.endDate
            : endDate // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        pilot: null == pilot
            ? _value.pilot
            : pilot // ignore: cast_nullable_to_non_nullable
                  as String,
        copilot: null == copilot
            ? _value.copilot
            : copilot // ignore: cast_nullable_to_non_nullable
                  as String,
        car: null == car
            ? _value.car
            : car // ignore: cast_nullable_to_non_nullable
                  as String,
        category: null == category
            ? _value.category
            : category // ignore: cast_nullable_to_non_nullable
                  as String,
        totalTeams: null == totalTeams
            ? _value.totalTeams
            : totalTeams // ignore: cast_nullable_to_non_nullable
                  as int,
        contactPerson: null == contactPerson
            ? _value.contactPerson
            : contactPerson // ignore: cast_nullable_to_non_nullable
                  as String,
        contactPhone: freezed == contactPhone
            ? _value.contactPhone
            : contactPhone // ignore: cast_nullable_to_non_nullable
                  as String?,
        cost: null == cost
            ? _value.cost
            : cost // ignore: cast_nullable_to_non_nullable
                  as double,
        overallStanding: null == overallStanding
            ? _value.overallStanding
            : overallStanding // ignore: cast_nullable_to_non_nullable
                  as int,
        categoryStanding: null == categoryStanding
            ? _value.categoryStanding
            : categoryStanding // ignore: cast_nullable_to_non_nullable
                  as int,
        stages: null == stages
            ? _value._stages
            : stages // ignore: cast_nullable_to_non_nullable
                  as List<PlannedStage>,
      ),
    );
  }
}

/// @nodoc

class _$CompetitionImpl extends _Competition {
  const _$CompetitionImpl({
    required this.id,
    this.name = '',
    this.location = '',
    this.startDate,
    this.endDate,
    this.pilot = '',
    this.copilot = '',
    this.car = '',
    this.category = '',
    this.totalTeams = 0,
    this.contactPerson = '',
    this.contactPhone,
    this.cost = 0.0,
    this.overallStanding = 0,
    this.categoryStanding = 0,
    final List<PlannedStage> stages = const <PlannedStage>[],
  }) : _stages = stages,
       super._();

  @override
  final String id;
  @override
  @JsonKey()
  final String name;
  @override
  @JsonKey()
  final String location;

  /// First day of the event (optional). `null` = not set.
  @override
  final DateTime? startDate;

  /// Last day of the event (optional). `null` or equal to [startDate] means a
  /// single-day event. When set, must be on/after [startDate].
  @override
  final DateTime? endDate;
  @override
  @JsonKey()
  final String pilot;
  @override
  @JsonKey()
  final String copilot;
  @override
  @JsonKey()
  final String car;
  @override
  @JsonKey()
  final String category;
  @override
  @JsonKey()
  final int totalTeams;
  @override
  @JsonKey()
  final String contactPerson;
  @override
  final String? contactPhone;
  @override
  @JsonKey()
  final double cost;
  @override
  @JsonKey()
  final int overallStanding;
  @override
  @JsonKey()
  final int categoryStanding;
  final List<PlannedStage> _stages;
  @override
  @JsonKey()
  List<PlannedStage> get stages {
    if (_stages is EqualUnmodifiableListView) return _stages;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_stages);
  }

  @override
  String toString() {
    return 'Competition(id: $id, name: $name, location: $location, startDate: $startDate, endDate: $endDate, pilot: $pilot, copilot: $copilot, car: $car, category: $category, totalTeams: $totalTeams, contactPerson: $contactPerson, contactPhone: $contactPhone, cost: $cost, overallStanding: $overallStanding, categoryStanding: $categoryStanding, stages: $stages)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CompetitionImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.location, location) ||
                other.location == location) &&
            (identical(other.startDate, startDate) ||
                other.startDate == startDate) &&
            (identical(other.endDate, endDate) || other.endDate == endDate) &&
            (identical(other.pilot, pilot) || other.pilot == pilot) &&
            (identical(other.copilot, copilot) || other.copilot == copilot) &&
            (identical(other.car, car) || other.car == car) &&
            (identical(other.category, category) ||
                other.category == category) &&
            (identical(other.totalTeams, totalTeams) ||
                other.totalTeams == totalTeams) &&
            (identical(other.contactPerson, contactPerson) ||
                other.contactPerson == contactPerson) &&
            (identical(other.contactPhone, contactPhone) ||
                other.contactPhone == contactPhone) &&
            (identical(other.cost, cost) || other.cost == cost) &&
            (identical(other.overallStanding, overallStanding) ||
                other.overallStanding == overallStanding) &&
            (identical(other.categoryStanding, categoryStanding) ||
                other.categoryStanding == categoryStanding) &&
            const DeepCollectionEquality().equals(other._stages, _stages));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    name,
    location,
    startDate,
    endDate,
    pilot,
    copilot,
    car,
    category,
    totalTeams,
    contactPerson,
    contactPhone,
    cost,
    overallStanding,
    categoryStanding,
    const DeepCollectionEquality().hash(_stages),
  );

  /// Create a copy of Competition
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$CompetitionImplCopyWith<_$CompetitionImpl> get copyWith =>
      __$$CompetitionImplCopyWithImpl<_$CompetitionImpl>(this, _$identity);
}

abstract class _Competition extends Competition {
  const factory _Competition({
    required final String id,
    final String name,
    final String location,
    final DateTime? startDate,
    final DateTime? endDate,
    final String pilot,
    final String copilot,
    final String car,
    final String category,
    final int totalTeams,
    final String contactPerson,
    final String? contactPhone,
    final double cost,
    final int overallStanding,
    final int categoryStanding,
    final List<PlannedStage> stages,
  }) = _$CompetitionImpl;
  const _Competition._() : super._();

  @override
  String get id;
  @override
  String get name;
  @override
  String get location;

  /// First day of the event (optional). `null` = not set.
  @override
  DateTime? get startDate;

  /// Last day of the event (optional). `null` or equal to [startDate] means a
  /// single-day event. When set, must be on/after [startDate].
  @override
  DateTime? get endDate;
  @override
  String get pilot;
  @override
  String get copilot;
  @override
  String get car;
  @override
  String get category;
  @override
  int get totalTeams;
  @override
  String get contactPerson;
  @override
  String? get contactPhone;
  @override
  double get cost;
  @override
  int get overallStanding;
  @override
  int get categoryStanding;
  @override
  List<PlannedStage> get stages;

  /// Create a copy of Competition
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$CompetitionImplCopyWith<_$CompetitionImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
