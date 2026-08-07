// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'doctor.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Doctor {

/// The `Doctor` row's UUID. Every availability and booking route wants
/// **this**, never [userId] — passing the user id is the mistake the web
/// availability editor shipped with (`FEATURE_MAP.md` §7.2).
 String get id;/// Nepal Medical Council registration number.
 String get nmid; String get degree; String? get specialty;/// Set by an operator with a `psql` update, never by this app. An
/// unverified doctor is invisible to `GET /api/doctors/doctors`.
 bool get verified;@JsonKey(name: 'user_id') String get userId;/// The `User.name` behind the profile, joined server-side.
 String get name;
/// Create a copy of Doctor
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DoctorCopyWith<Doctor> get copyWith => _$DoctorCopyWithImpl<Doctor>(this as Doctor, _$identity);

  /// Serializes this Doctor to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Doctor&&(identical(other.id, id) || other.id == id)&&(identical(other.nmid, nmid) || other.nmid == nmid)&&(identical(other.degree, degree) || other.degree == degree)&&(identical(other.specialty, specialty) || other.specialty == specialty)&&(identical(other.verified, verified) || other.verified == verified)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.name, name) || other.name == name));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,nmid,degree,specialty,verified,userId,name);

@override
String toString() {
  return 'Doctor(id: $id, nmid: $nmid, degree: $degree, specialty: $specialty, verified: $verified, userId: $userId, name: $name)';
}


}

/// @nodoc
abstract mixin class $DoctorCopyWith<$Res>  {
  factory $DoctorCopyWith(Doctor value, $Res Function(Doctor) _then) = _$DoctorCopyWithImpl;
@useResult
$Res call({
 String id, String nmid, String degree, String? specialty, bool verified,@JsonKey(name: 'user_id') String userId, String name
});




}
/// @nodoc
class _$DoctorCopyWithImpl<$Res>
    implements $DoctorCopyWith<$Res> {
  _$DoctorCopyWithImpl(this._self, this._then);

  final Doctor _self;
  final $Res Function(Doctor) _then;

/// Create a copy of Doctor
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? nmid = null,Object? degree = null,Object? specialty = freezed,Object? verified = null,Object? userId = null,Object? name = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,nmid: null == nmid ? _self.nmid : nmid // ignore: cast_nullable_to_non_nullable
as String,degree: null == degree ? _self.degree : degree // ignore: cast_nullable_to_non_nullable
as String,specialty: freezed == specialty ? _self.specialty : specialty // ignore: cast_nullable_to_non_nullable
as String?,verified: null == verified ? _self.verified : verified // ignore: cast_nullable_to_non_nullable
as bool,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [Doctor].
extension DoctorPatterns on Doctor {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Doctor value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Doctor() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Doctor value)  $default,){
final _that = this;
switch (_that) {
case _Doctor():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Doctor value)?  $default,){
final _that = this;
switch (_that) {
case _Doctor() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String nmid,  String degree,  String? specialty,  bool verified, @JsonKey(name: 'user_id')  String userId,  String name)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Doctor() when $default != null:
return $default(_that.id,_that.nmid,_that.degree,_that.specialty,_that.verified,_that.userId,_that.name);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String nmid,  String degree,  String? specialty,  bool verified, @JsonKey(name: 'user_id')  String userId,  String name)  $default,) {final _that = this;
switch (_that) {
case _Doctor():
return $default(_that.id,_that.nmid,_that.degree,_that.specialty,_that.verified,_that.userId,_that.name);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String nmid,  String degree,  String? specialty,  bool verified, @JsonKey(name: 'user_id')  String userId,  String name)?  $default,) {final _that = this;
switch (_that) {
case _Doctor() when $default != null:
return $default(_that.id,_that.nmid,_that.degree,_that.specialty,_that.verified,_that.userId,_that.name);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Doctor extends Doctor {
  const _Doctor({required this.id, required this.nmid, required this.degree, this.specialty, required this.verified, @JsonKey(name: 'user_id') required this.userId, required this.name}): super._();
  factory _Doctor.fromJson(Map<String, dynamic> json) => _$DoctorFromJson(json);

/// The `Doctor` row's UUID. Every availability and booking route wants
/// **this**, never [userId] — passing the user id is the mistake the web
/// availability editor shipped with (`FEATURE_MAP.md` §7.2).
@override final  String id;
/// Nepal Medical Council registration number.
@override final  String nmid;
@override final  String degree;
@override final  String? specialty;
/// Set by an operator with a `psql` update, never by this app. An
/// unverified doctor is invisible to `GET /api/doctors/doctors`.
@override final  bool verified;
@override@JsonKey(name: 'user_id') final  String userId;
/// The `User.name` behind the profile, joined server-side.
@override final  String name;

/// Create a copy of Doctor
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DoctorCopyWith<_Doctor> get copyWith => __$DoctorCopyWithImpl<_Doctor>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DoctorToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Doctor&&(identical(other.id, id) || other.id == id)&&(identical(other.nmid, nmid) || other.nmid == nmid)&&(identical(other.degree, degree) || other.degree == degree)&&(identical(other.specialty, specialty) || other.specialty == specialty)&&(identical(other.verified, verified) || other.verified == verified)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.name, name) || other.name == name));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,nmid,degree,specialty,verified,userId,name);

@override
String toString() {
  return 'Doctor(id: $id, nmid: $nmid, degree: $degree, specialty: $specialty, verified: $verified, userId: $userId, name: $name)';
}


}

/// @nodoc
abstract mixin class _$DoctorCopyWith<$Res> implements $DoctorCopyWith<$Res> {
  factory _$DoctorCopyWith(_Doctor value, $Res Function(_Doctor) _then) = __$DoctorCopyWithImpl;
@override @useResult
$Res call({
 String id, String nmid, String degree, String? specialty, bool verified,@JsonKey(name: 'user_id') String userId, String name
});




}
/// @nodoc
class __$DoctorCopyWithImpl<$Res>
    implements _$DoctorCopyWith<$Res> {
  __$DoctorCopyWithImpl(this._self, this._then);

  final _Doctor _self;
  final $Res Function(_Doctor) _then;

/// Create a copy of Doctor
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? nmid = null,Object? degree = null,Object? specialty = freezed,Object? verified = null,Object? userId = null,Object? name = null,}) {
  return _then(_Doctor(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,nmid: null == nmid ? _self.nmid : nmid // ignore: cast_nullable_to_non_nullable
as String,degree: null == degree ? _self.degree : degree // ignore: cast_nullable_to_non_nullable
as String,specialty: freezed == specialty ? _self.specialty : specialty // ignore: cast_nullable_to_non_nullable
as String?,verified: null == verified ? _self.verified : verified // ignore: cast_nullable_to_non_nullable
as bool,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$AvailabilityWindow {

 String get id;@JsonKey(name: 'day_of_week') String get dayOfWeek;@JsonKey(name: 'start_time') String get startTime;@JsonKey(name: 'end_time') String get endTime;/// How far apart the generated slots sit. Drives `available-slots`, and the
/// web editor never exposed it — so every window created there is on the
/// 30-minute default whether the doctor wanted that or not.
@JsonKey(name: 'slot_duration_minutes') int get slotDurationMinutes;/// A window switched off still exists; it just generates no slots. That is
/// how a doctor takes a Tuesday off without losing their Tuesday hours.
@JsonKey(name: 'is_available') bool get isAvailable;
/// Create a copy of AvailabilityWindow
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AvailabilityWindowCopyWith<AvailabilityWindow> get copyWith => _$AvailabilityWindowCopyWithImpl<AvailabilityWindow>(this as AvailabilityWindow, _$identity);

  /// Serializes this AvailabilityWindow to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AvailabilityWindow&&(identical(other.id, id) || other.id == id)&&(identical(other.dayOfWeek, dayOfWeek) || other.dayOfWeek == dayOfWeek)&&(identical(other.startTime, startTime) || other.startTime == startTime)&&(identical(other.endTime, endTime) || other.endTime == endTime)&&(identical(other.slotDurationMinutes, slotDurationMinutes) || other.slotDurationMinutes == slotDurationMinutes)&&(identical(other.isAvailable, isAvailable) || other.isAvailable == isAvailable));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,dayOfWeek,startTime,endTime,slotDurationMinutes,isAvailable);

@override
String toString() {
  return 'AvailabilityWindow(id: $id, dayOfWeek: $dayOfWeek, startTime: $startTime, endTime: $endTime, slotDurationMinutes: $slotDurationMinutes, isAvailable: $isAvailable)';
}


}

/// @nodoc
abstract mixin class $AvailabilityWindowCopyWith<$Res>  {
  factory $AvailabilityWindowCopyWith(AvailabilityWindow value, $Res Function(AvailabilityWindow) _then) = _$AvailabilityWindowCopyWithImpl;
@useResult
$Res call({
 String id,@JsonKey(name: 'day_of_week') String dayOfWeek,@JsonKey(name: 'start_time') String startTime,@JsonKey(name: 'end_time') String endTime,@JsonKey(name: 'slot_duration_minutes') int slotDurationMinutes,@JsonKey(name: 'is_available') bool isAvailable
});




}
/// @nodoc
class _$AvailabilityWindowCopyWithImpl<$Res>
    implements $AvailabilityWindowCopyWith<$Res> {
  _$AvailabilityWindowCopyWithImpl(this._self, this._then);

  final AvailabilityWindow _self;
  final $Res Function(AvailabilityWindow) _then;

/// Create a copy of AvailabilityWindow
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? dayOfWeek = null,Object? startTime = null,Object? endTime = null,Object? slotDurationMinutes = null,Object? isAvailable = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,dayOfWeek: null == dayOfWeek ? _self.dayOfWeek : dayOfWeek // ignore: cast_nullable_to_non_nullable
as String,startTime: null == startTime ? _self.startTime : startTime // ignore: cast_nullable_to_non_nullable
as String,endTime: null == endTime ? _self.endTime : endTime // ignore: cast_nullable_to_non_nullable
as String,slotDurationMinutes: null == slotDurationMinutes ? _self.slotDurationMinutes : slotDurationMinutes // ignore: cast_nullable_to_non_nullable
as int,isAvailable: null == isAvailable ? _self.isAvailable : isAvailable // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [AvailabilityWindow].
extension AvailabilityWindowPatterns on AvailabilityWindow {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AvailabilityWindow value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AvailabilityWindow() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AvailabilityWindow value)  $default,){
final _that = this;
switch (_that) {
case _AvailabilityWindow():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AvailabilityWindow value)?  $default,){
final _that = this;
switch (_that) {
case _AvailabilityWindow() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'day_of_week')  String dayOfWeek, @JsonKey(name: 'start_time')  String startTime, @JsonKey(name: 'end_time')  String endTime, @JsonKey(name: 'slot_duration_minutes')  int slotDurationMinutes, @JsonKey(name: 'is_available')  bool isAvailable)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AvailabilityWindow() when $default != null:
return $default(_that.id,_that.dayOfWeek,_that.startTime,_that.endTime,_that.slotDurationMinutes,_that.isAvailable);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'day_of_week')  String dayOfWeek, @JsonKey(name: 'start_time')  String startTime, @JsonKey(name: 'end_time')  String endTime, @JsonKey(name: 'slot_duration_minutes')  int slotDurationMinutes, @JsonKey(name: 'is_available')  bool isAvailable)  $default,) {final _that = this;
switch (_that) {
case _AvailabilityWindow():
return $default(_that.id,_that.dayOfWeek,_that.startTime,_that.endTime,_that.slotDurationMinutes,_that.isAvailable);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id, @JsonKey(name: 'day_of_week')  String dayOfWeek, @JsonKey(name: 'start_time')  String startTime, @JsonKey(name: 'end_time')  String endTime, @JsonKey(name: 'slot_duration_minutes')  int slotDurationMinutes, @JsonKey(name: 'is_available')  bool isAvailable)?  $default,) {final _that = this;
switch (_that) {
case _AvailabilityWindow() when $default != null:
return $default(_that.id,_that.dayOfWeek,_that.startTime,_that.endTime,_that.slotDurationMinutes,_that.isAvailable);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AvailabilityWindow extends AvailabilityWindow {
  const _AvailabilityWindow({required this.id, @JsonKey(name: 'day_of_week') required this.dayOfWeek, @JsonKey(name: 'start_time') required this.startTime, @JsonKey(name: 'end_time') required this.endTime, @JsonKey(name: 'slot_duration_minutes') required this.slotDurationMinutes, @JsonKey(name: 'is_available') required this.isAvailable}): super._();
  factory _AvailabilityWindow.fromJson(Map<String, dynamic> json) => _$AvailabilityWindowFromJson(json);

@override final  String id;
@override@JsonKey(name: 'day_of_week') final  String dayOfWeek;
@override@JsonKey(name: 'start_time') final  String startTime;
@override@JsonKey(name: 'end_time') final  String endTime;
/// How far apart the generated slots sit. Drives `available-slots`, and the
/// web editor never exposed it — so every window created there is on the
/// 30-minute default whether the doctor wanted that or not.
@override@JsonKey(name: 'slot_duration_minutes') final  int slotDurationMinutes;
/// A window switched off still exists; it just generates no slots. That is
/// how a doctor takes a Tuesday off without losing their Tuesday hours.
@override@JsonKey(name: 'is_available') final  bool isAvailable;

/// Create a copy of AvailabilityWindow
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AvailabilityWindowCopyWith<_AvailabilityWindow> get copyWith => __$AvailabilityWindowCopyWithImpl<_AvailabilityWindow>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AvailabilityWindowToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AvailabilityWindow&&(identical(other.id, id) || other.id == id)&&(identical(other.dayOfWeek, dayOfWeek) || other.dayOfWeek == dayOfWeek)&&(identical(other.startTime, startTime) || other.startTime == startTime)&&(identical(other.endTime, endTime) || other.endTime == endTime)&&(identical(other.slotDurationMinutes, slotDurationMinutes) || other.slotDurationMinutes == slotDurationMinutes)&&(identical(other.isAvailable, isAvailable) || other.isAvailable == isAvailable));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,dayOfWeek,startTime,endTime,slotDurationMinutes,isAvailable);

@override
String toString() {
  return 'AvailabilityWindow(id: $id, dayOfWeek: $dayOfWeek, startTime: $startTime, endTime: $endTime, slotDurationMinutes: $slotDurationMinutes, isAvailable: $isAvailable)';
}


}

/// @nodoc
abstract mixin class _$AvailabilityWindowCopyWith<$Res> implements $AvailabilityWindowCopyWith<$Res> {
  factory _$AvailabilityWindowCopyWith(_AvailabilityWindow value, $Res Function(_AvailabilityWindow) _then) = __$AvailabilityWindowCopyWithImpl;
@override @useResult
$Res call({
 String id,@JsonKey(name: 'day_of_week') String dayOfWeek,@JsonKey(name: 'start_time') String startTime,@JsonKey(name: 'end_time') String endTime,@JsonKey(name: 'slot_duration_minutes') int slotDurationMinutes,@JsonKey(name: 'is_available') bool isAvailable
});




}
/// @nodoc
class __$AvailabilityWindowCopyWithImpl<$Res>
    implements _$AvailabilityWindowCopyWith<$Res> {
  __$AvailabilityWindowCopyWithImpl(this._self, this._then);

  final _AvailabilityWindow _self;
  final $Res Function(_AvailabilityWindow) _then;

/// Create a copy of AvailabilityWindow
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? dayOfWeek = null,Object? startTime = null,Object? endTime = null,Object? slotDurationMinutes = null,Object? isAvailable = null,}) {
  return _then(_AvailabilityWindow(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,dayOfWeek: null == dayOfWeek ? _self.dayOfWeek : dayOfWeek // ignore: cast_nullable_to_non_nullable
as String,startTime: null == startTime ? _self.startTime : startTime // ignore: cast_nullable_to_non_nullable
as String,endTime: null == endTime ? _self.endTime : endTime // ignore: cast_nullable_to_non_nullable
as String,slotDurationMinutes: null == slotDurationMinutes ? _self.slotDurationMinutes : slotDurationMinutes // ignore: cast_nullable_to_non_nullable
as int,isAvailable: null == isAvailable ? _self.isAvailable : isAvailable // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
