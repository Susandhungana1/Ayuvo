// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'vital_sign.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$VitalSign {

 String get id;@JsonKey(name: 'blood_pressure_systolic') int? get systolic;@JsonKey(name: 'blood_pressure_diastolic') int? get diastolic;@JsonKey(name: 'heart_rate') int? get heartRate; double? get weight;@JsonKey(name: 'blood_sugar') double? get bloodSugar; double? get temperature;@JsonKey(name: 'oxygen_saturation') int? get oxygenSaturation; String? get notes;/// Naive UTC. Read it through [measured], never with `DateTime.parse`.
@JsonKey(name: 'measured_at') String get measuredAt;@JsonKey(name: 'created_at') String get createdAt;
/// Create a copy of VitalSign
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VitalSignCopyWith<VitalSign> get copyWith => _$VitalSignCopyWithImpl<VitalSign>(this as VitalSign, _$identity);

  /// Serializes this VitalSign to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VitalSign&&(identical(other.id, id) || other.id == id)&&(identical(other.systolic, systolic) || other.systolic == systolic)&&(identical(other.diastolic, diastolic) || other.diastolic == diastolic)&&(identical(other.heartRate, heartRate) || other.heartRate == heartRate)&&(identical(other.weight, weight) || other.weight == weight)&&(identical(other.bloodSugar, bloodSugar) || other.bloodSugar == bloodSugar)&&(identical(other.temperature, temperature) || other.temperature == temperature)&&(identical(other.oxygenSaturation, oxygenSaturation) || other.oxygenSaturation == oxygenSaturation)&&(identical(other.notes, notes) || other.notes == notes)&&(identical(other.measuredAt, measuredAt) || other.measuredAt == measuredAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,systolic,diastolic,heartRate,weight,bloodSugar,temperature,oxygenSaturation,notes,measuredAt,createdAt);

@override
String toString() {
  return 'VitalSign(id: $id, systolic: $systolic, diastolic: $diastolic, heartRate: $heartRate, weight: $weight, bloodSugar: $bloodSugar, temperature: $temperature, oxygenSaturation: $oxygenSaturation, notes: $notes, measuredAt: $measuredAt, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class $VitalSignCopyWith<$Res>  {
  factory $VitalSignCopyWith(VitalSign value, $Res Function(VitalSign) _then) = _$VitalSignCopyWithImpl;
@useResult
$Res call({
 String id,@JsonKey(name: 'blood_pressure_systolic') int? systolic,@JsonKey(name: 'blood_pressure_diastolic') int? diastolic,@JsonKey(name: 'heart_rate') int? heartRate, double? weight,@JsonKey(name: 'blood_sugar') double? bloodSugar, double? temperature,@JsonKey(name: 'oxygen_saturation') int? oxygenSaturation, String? notes,@JsonKey(name: 'measured_at') String measuredAt,@JsonKey(name: 'created_at') String createdAt
});




}
/// @nodoc
class _$VitalSignCopyWithImpl<$Res>
    implements $VitalSignCopyWith<$Res> {
  _$VitalSignCopyWithImpl(this._self, this._then);

  final VitalSign _self;
  final $Res Function(VitalSign) _then;

/// Create a copy of VitalSign
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? systolic = freezed,Object? diastolic = freezed,Object? heartRate = freezed,Object? weight = freezed,Object? bloodSugar = freezed,Object? temperature = freezed,Object? oxygenSaturation = freezed,Object? notes = freezed,Object? measuredAt = null,Object? createdAt = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,systolic: freezed == systolic ? _self.systolic : systolic // ignore: cast_nullable_to_non_nullable
as int?,diastolic: freezed == diastolic ? _self.diastolic : diastolic // ignore: cast_nullable_to_non_nullable
as int?,heartRate: freezed == heartRate ? _self.heartRate : heartRate // ignore: cast_nullable_to_non_nullable
as int?,weight: freezed == weight ? _self.weight : weight // ignore: cast_nullable_to_non_nullable
as double?,bloodSugar: freezed == bloodSugar ? _self.bloodSugar : bloodSugar // ignore: cast_nullable_to_non_nullable
as double?,temperature: freezed == temperature ? _self.temperature : temperature // ignore: cast_nullable_to_non_nullable
as double?,oxygenSaturation: freezed == oxygenSaturation ? _self.oxygenSaturation : oxygenSaturation // ignore: cast_nullable_to_non_nullable
as int?,notes: freezed == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String?,measuredAt: null == measuredAt ? _self.measuredAt : measuredAt // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [VitalSign].
extension VitalSignPatterns on VitalSign {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _VitalSign value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _VitalSign() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _VitalSign value)  $default,){
final _that = this;
switch (_that) {
case _VitalSign():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _VitalSign value)?  $default,){
final _that = this;
switch (_that) {
case _VitalSign() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'blood_pressure_systolic')  int? systolic, @JsonKey(name: 'blood_pressure_diastolic')  int? diastolic, @JsonKey(name: 'heart_rate')  int? heartRate,  double? weight, @JsonKey(name: 'blood_sugar')  double? bloodSugar,  double? temperature, @JsonKey(name: 'oxygen_saturation')  int? oxygenSaturation,  String? notes, @JsonKey(name: 'measured_at')  String measuredAt, @JsonKey(name: 'created_at')  String createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VitalSign() when $default != null:
return $default(_that.id,_that.systolic,_that.diastolic,_that.heartRate,_that.weight,_that.bloodSugar,_that.temperature,_that.oxygenSaturation,_that.notes,_that.measuredAt,_that.createdAt);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'blood_pressure_systolic')  int? systolic, @JsonKey(name: 'blood_pressure_diastolic')  int? diastolic, @JsonKey(name: 'heart_rate')  int? heartRate,  double? weight, @JsonKey(name: 'blood_sugar')  double? bloodSugar,  double? temperature, @JsonKey(name: 'oxygen_saturation')  int? oxygenSaturation,  String? notes, @JsonKey(name: 'measured_at')  String measuredAt, @JsonKey(name: 'created_at')  String createdAt)  $default,) {final _that = this;
switch (_that) {
case _VitalSign():
return $default(_that.id,_that.systolic,_that.diastolic,_that.heartRate,_that.weight,_that.bloodSugar,_that.temperature,_that.oxygenSaturation,_that.notes,_that.measuredAt,_that.createdAt);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id, @JsonKey(name: 'blood_pressure_systolic')  int? systolic, @JsonKey(name: 'blood_pressure_diastolic')  int? diastolic, @JsonKey(name: 'heart_rate')  int? heartRate,  double? weight, @JsonKey(name: 'blood_sugar')  double? bloodSugar,  double? temperature, @JsonKey(name: 'oxygen_saturation')  int? oxygenSaturation,  String? notes, @JsonKey(name: 'measured_at')  String measuredAt, @JsonKey(name: 'created_at')  String createdAt)?  $default,) {final _that = this;
switch (_that) {
case _VitalSign() when $default != null:
return $default(_that.id,_that.systolic,_that.diastolic,_that.heartRate,_that.weight,_that.bloodSugar,_that.temperature,_that.oxygenSaturation,_that.notes,_that.measuredAt,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _VitalSign extends VitalSign {
  const _VitalSign({required this.id, @JsonKey(name: 'blood_pressure_systolic') this.systolic, @JsonKey(name: 'blood_pressure_diastolic') this.diastolic, @JsonKey(name: 'heart_rate') this.heartRate, this.weight, @JsonKey(name: 'blood_sugar') this.bloodSugar, this.temperature, @JsonKey(name: 'oxygen_saturation') this.oxygenSaturation, this.notes, @JsonKey(name: 'measured_at') required this.measuredAt, @JsonKey(name: 'created_at') required this.createdAt}): super._();
  factory _VitalSign.fromJson(Map<String, dynamic> json) => _$VitalSignFromJson(json);

@override final  String id;
@override@JsonKey(name: 'blood_pressure_systolic') final  int? systolic;
@override@JsonKey(name: 'blood_pressure_diastolic') final  int? diastolic;
@override@JsonKey(name: 'heart_rate') final  int? heartRate;
@override final  double? weight;
@override@JsonKey(name: 'blood_sugar') final  double? bloodSugar;
@override final  double? temperature;
@override@JsonKey(name: 'oxygen_saturation') final  int? oxygenSaturation;
@override final  String? notes;
/// Naive UTC. Read it through [measured], never with `DateTime.parse`.
@override@JsonKey(name: 'measured_at') final  String measuredAt;
@override@JsonKey(name: 'created_at') final  String createdAt;

/// Create a copy of VitalSign
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VitalSignCopyWith<_VitalSign> get copyWith => __$VitalSignCopyWithImpl<_VitalSign>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$VitalSignToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _VitalSign&&(identical(other.id, id) || other.id == id)&&(identical(other.systolic, systolic) || other.systolic == systolic)&&(identical(other.diastolic, diastolic) || other.diastolic == diastolic)&&(identical(other.heartRate, heartRate) || other.heartRate == heartRate)&&(identical(other.weight, weight) || other.weight == weight)&&(identical(other.bloodSugar, bloodSugar) || other.bloodSugar == bloodSugar)&&(identical(other.temperature, temperature) || other.temperature == temperature)&&(identical(other.oxygenSaturation, oxygenSaturation) || other.oxygenSaturation == oxygenSaturation)&&(identical(other.notes, notes) || other.notes == notes)&&(identical(other.measuredAt, measuredAt) || other.measuredAt == measuredAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,systolic,diastolic,heartRate,weight,bloodSugar,temperature,oxygenSaturation,notes,measuredAt,createdAt);

@override
String toString() {
  return 'VitalSign(id: $id, systolic: $systolic, diastolic: $diastolic, heartRate: $heartRate, weight: $weight, bloodSugar: $bloodSugar, temperature: $temperature, oxygenSaturation: $oxygenSaturation, notes: $notes, measuredAt: $measuredAt, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$VitalSignCopyWith<$Res> implements $VitalSignCopyWith<$Res> {
  factory _$VitalSignCopyWith(_VitalSign value, $Res Function(_VitalSign) _then) = __$VitalSignCopyWithImpl;
@override @useResult
$Res call({
 String id,@JsonKey(name: 'blood_pressure_systolic') int? systolic,@JsonKey(name: 'blood_pressure_diastolic') int? diastolic,@JsonKey(name: 'heart_rate') int? heartRate, double? weight,@JsonKey(name: 'blood_sugar') double? bloodSugar, double? temperature,@JsonKey(name: 'oxygen_saturation') int? oxygenSaturation, String? notes,@JsonKey(name: 'measured_at') String measuredAt,@JsonKey(name: 'created_at') String createdAt
});




}
/// @nodoc
class __$VitalSignCopyWithImpl<$Res>
    implements _$VitalSignCopyWith<$Res> {
  __$VitalSignCopyWithImpl(this._self, this._then);

  final _VitalSign _self;
  final $Res Function(_VitalSign) _then;

/// Create a copy of VitalSign
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? systolic = freezed,Object? diastolic = freezed,Object? heartRate = freezed,Object? weight = freezed,Object? bloodSugar = freezed,Object? temperature = freezed,Object? oxygenSaturation = freezed,Object? notes = freezed,Object? measuredAt = null,Object? createdAt = null,}) {
  return _then(_VitalSign(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,systolic: freezed == systolic ? _self.systolic : systolic // ignore: cast_nullable_to_non_nullable
as int?,diastolic: freezed == diastolic ? _self.diastolic : diastolic // ignore: cast_nullable_to_non_nullable
as int?,heartRate: freezed == heartRate ? _self.heartRate : heartRate // ignore: cast_nullable_to_non_nullable
as int?,weight: freezed == weight ? _self.weight : weight // ignore: cast_nullable_to_non_nullable
as double?,bloodSugar: freezed == bloodSugar ? _self.bloodSugar : bloodSugar // ignore: cast_nullable_to_non_nullable
as double?,temperature: freezed == temperature ? _self.temperature : temperature // ignore: cast_nullable_to_non_nullable
as double?,oxygenSaturation: freezed == oxygenSaturation ? _self.oxygenSaturation : oxygenSaturation // ignore: cast_nullable_to_non_nullable
as int?,notes: freezed == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String?,measuredAt: null == measuredAt ? _self.measuredAt : measuredAt // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
