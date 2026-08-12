// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'appointment.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Appointment {

 String get id; String get title; String? get description;/// `Doctor.id` — a UUID, and **not** the doctor's user id. Present only
/// when the appointment was booked against a listed doctor.
@JsonKey(name: 'doctor_id') String? get doctorId;@JsonKey(name: 'doctor_name') String? get doctorName; String? get hospital;/// Naive *local* wall clock. See the library comment.
@JsonKey(name: 'appointment_date') String get appointmentDate;@JsonKey(name: 'duration_minutes') int get durationMinutes; String get status; String? get reason;/// Whether the server's reminder job has already emailed about this one.
/// Read so the app never claims a reminder it did not send.
@JsonKey(name: 'reminder_sent') bool get reminderSent;
/// Create a copy of Appointment
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AppointmentCopyWith<Appointment> get copyWith => _$AppointmentCopyWithImpl<Appointment>(this as Appointment, _$identity);

  /// Serializes this Appointment to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Appointment&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&(identical(other.description, description) || other.description == description)&&(identical(other.doctorId, doctorId) || other.doctorId == doctorId)&&(identical(other.doctorName, doctorName) || other.doctorName == doctorName)&&(identical(other.hospital, hospital) || other.hospital == hospital)&&(identical(other.appointmentDate, appointmentDate) || other.appointmentDate == appointmentDate)&&(identical(other.durationMinutes, durationMinutes) || other.durationMinutes == durationMinutes)&&(identical(other.status, status) || other.status == status)&&(identical(other.reason, reason) || other.reason == reason)&&(identical(other.reminderSent, reminderSent) || other.reminderSent == reminderSent));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,title,description,doctorId,doctorName,hospital,appointmentDate,durationMinutes,status,reason,reminderSent);

@override
String toString() {
  return 'Appointment(id: $id, title: $title, description: $description, doctorId: $doctorId, doctorName: $doctorName, hospital: $hospital, appointmentDate: $appointmentDate, durationMinutes: $durationMinutes, status: $status, reason: $reason, reminderSent: $reminderSent)';
}


}

/// @nodoc
abstract mixin class $AppointmentCopyWith<$Res>  {
  factory $AppointmentCopyWith(Appointment value, $Res Function(Appointment) _then) = _$AppointmentCopyWithImpl;
@useResult
$Res call({
 String id, String title, String? description,@JsonKey(name: 'doctor_id') String? doctorId,@JsonKey(name: 'doctor_name') String? doctorName, String? hospital,@JsonKey(name: 'appointment_date') String appointmentDate,@JsonKey(name: 'duration_minutes') int durationMinutes, String status, String? reason,@JsonKey(name: 'reminder_sent') bool reminderSent
});




}
/// @nodoc
class _$AppointmentCopyWithImpl<$Res>
    implements $AppointmentCopyWith<$Res> {
  _$AppointmentCopyWithImpl(this._self, this._then);

  final Appointment _self;
  final $Res Function(Appointment) _then;

/// Create a copy of Appointment
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? title = null,Object? description = freezed,Object? doctorId = freezed,Object? doctorName = freezed,Object? hospital = freezed,Object? appointmentDate = null,Object? durationMinutes = null,Object? status = null,Object? reason = freezed,Object? reminderSent = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,doctorId: freezed == doctorId ? _self.doctorId : doctorId // ignore: cast_nullable_to_non_nullable
as String?,doctorName: freezed == doctorName ? _self.doctorName : doctorName // ignore: cast_nullable_to_non_nullable
as String?,hospital: freezed == hospital ? _self.hospital : hospital // ignore: cast_nullable_to_non_nullable
as String?,appointmentDate: null == appointmentDate ? _self.appointmentDate : appointmentDate // ignore: cast_nullable_to_non_nullable
as String,durationMinutes: null == durationMinutes ? _self.durationMinutes : durationMinutes // ignore: cast_nullable_to_non_nullable
as int,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,reason: freezed == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as String?,reminderSent: null == reminderSent ? _self.reminderSent : reminderSent // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [Appointment].
extension AppointmentPatterns on Appointment {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Appointment value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Appointment() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Appointment value)  $default,){
final _that = this;
switch (_that) {
case _Appointment():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Appointment value)?  $default,){
final _that = this;
switch (_that) {
case _Appointment() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String title,  String? description, @JsonKey(name: 'doctor_id')  String? doctorId, @JsonKey(name: 'doctor_name')  String? doctorName,  String? hospital, @JsonKey(name: 'appointment_date')  String appointmentDate, @JsonKey(name: 'duration_minutes')  int durationMinutes,  String status,  String? reason, @JsonKey(name: 'reminder_sent')  bool reminderSent)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Appointment() when $default != null:
return $default(_that.id,_that.title,_that.description,_that.doctorId,_that.doctorName,_that.hospital,_that.appointmentDate,_that.durationMinutes,_that.status,_that.reason,_that.reminderSent);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String title,  String? description, @JsonKey(name: 'doctor_id')  String? doctorId, @JsonKey(name: 'doctor_name')  String? doctorName,  String? hospital, @JsonKey(name: 'appointment_date')  String appointmentDate, @JsonKey(name: 'duration_minutes')  int durationMinutes,  String status,  String? reason, @JsonKey(name: 'reminder_sent')  bool reminderSent)  $default,) {final _that = this;
switch (_that) {
case _Appointment():
return $default(_that.id,_that.title,_that.description,_that.doctorId,_that.doctorName,_that.hospital,_that.appointmentDate,_that.durationMinutes,_that.status,_that.reason,_that.reminderSent);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String title,  String? description, @JsonKey(name: 'doctor_id')  String? doctorId, @JsonKey(name: 'doctor_name')  String? doctorName,  String? hospital, @JsonKey(name: 'appointment_date')  String appointmentDate, @JsonKey(name: 'duration_minutes')  int durationMinutes,  String status,  String? reason, @JsonKey(name: 'reminder_sent')  bool reminderSent)?  $default,) {final _that = this;
switch (_that) {
case _Appointment() when $default != null:
return $default(_that.id,_that.title,_that.description,_that.doctorId,_that.doctorName,_that.hospital,_that.appointmentDate,_that.durationMinutes,_that.status,_that.reason,_that.reminderSent);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Appointment extends Appointment {
  const _Appointment({required this.id, required this.title, this.description, @JsonKey(name: 'doctor_id') this.doctorId, @JsonKey(name: 'doctor_name') this.doctorName, this.hospital, @JsonKey(name: 'appointment_date') required this.appointmentDate, @JsonKey(name: 'duration_minutes') required this.durationMinutes, required this.status, this.reason, @JsonKey(name: 'reminder_sent') this.reminderSent = false}): super._();
  factory _Appointment.fromJson(Map<String, dynamic> json) => _$AppointmentFromJson(json);

@override final  String id;
@override final  String title;
@override final  String? description;
/// `Doctor.id` — a UUID, and **not** the doctor's user id. Present only
/// when the appointment was booked against a listed doctor.
@override@JsonKey(name: 'doctor_id') final  String? doctorId;
@override@JsonKey(name: 'doctor_name') final  String? doctorName;
@override final  String? hospital;
/// Naive *local* wall clock. See the library comment.
@override@JsonKey(name: 'appointment_date') final  String appointmentDate;
@override@JsonKey(name: 'duration_minutes') final  int durationMinutes;
@override final  String status;
@override final  String? reason;
/// Whether the server's reminder job has already emailed about this one.
/// Read so the app never claims a reminder it did not send.
@override@JsonKey(name: 'reminder_sent') final  bool reminderSent;

/// Create a copy of Appointment
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AppointmentCopyWith<_Appointment> get copyWith => __$AppointmentCopyWithImpl<_Appointment>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AppointmentToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Appointment&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&(identical(other.description, description) || other.description == description)&&(identical(other.doctorId, doctorId) || other.doctorId == doctorId)&&(identical(other.doctorName, doctorName) || other.doctorName == doctorName)&&(identical(other.hospital, hospital) || other.hospital == hospital)&&(identical(other.appointmentDate, appointmentDate) || other.appointmentDate == appointmentDate)&&(identical(other.durationMinutes, durationMinutes) || other.durationMinutes == durationMinutes)&&(identical(other.status, status) || other.status == status)&&(identical(other.reason, reason) || other.reason == reason)&&(identical(other.reminderSent, reminderSent) || other.reminderSent == reminderSent));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,title,description,doctorId,doctorName,hospital,appointmentDate,durationMinutes,status,reason,reminderSent);

@override
String toString() {
  return 'Appointment(id: $id, title: $title, description: $description, doctorId: $doctorId, doctorName: $doctorName, hospital: $hospital, appointmentDate: $appointmentDate, durationMinutes: $durationMinutes, status: $status, reason: $reason, reminderSent: $reminderSent)';
}


}

/// @nodoc
abstract mixin class _$AppointmentCopyWith<$Res> implements $AppointmentCopyWith<$Res> {
  factory _$AppointmentCopyWith(_Appointment value, $Res Function(_Appointment) _then) = __$AppointmentCopyWithImpl;
@override @useResult
$Res call({
 String id, String title, String? description,@JsonKey(name: 'doctor_id') String? doctorId,@JsonKey(name: 'doctor_name') String? doctorName, String? hospital,@JsonKey(name: 'appointment_date') String appointmentDate,@JsonKey(name: 'duration_minutes') int durationMinutes, String status, String? reason,@JsonKey(name: 'reminder_sent') bool reminderSent
});




}
/// @nodoc
class __$AppointmentCopyWithImpl<$Res>
    implements _$AppointmentCopyWith<$Res> {
  __$AppointmentCopyWithImpl(this._self, this._then);

  final _Appointment _self;
  final $Res Function(_Appointment) _then;

/// Create a copy of Appointment
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? title = null,Object? description = freezed,Object? doctorId = freezed,Object? doctorName = freezed,Object? hospital = freezed,Object? appointmentDate = null,Object? durationMinutes = null,Object? status = null,Object? reason = freezed,Object? reminderSent = null,}) {
  return _then(_Appointment(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,doctorId: freezed == doctorId ? _self.doctorId : doctorId // ignore: cast_nullable_to_non_nullable
as String?,doctorName: freezed == doctorName ? _self.doctorName : doctorName // ignore: cast_nullable_to_non_nullable
as String?,hospital: freezed == hospital ? _self.hospital : hospital // ignore: cast_nullable_to_non_nullable
as String?,appointmentDate: null == appointmentDate ? _self.appointmentDate : appointmentDate // ignore: cast_nullable_to_non_nullable
as String,durationMinutes: null == durationMinutes ? _self.durationMinutes : durationMinutes // ignore: cast_nullable_to_non_nullable
as int,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,reason: freezed == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as String?,reminderSent: null == reminderSent ? _self.reminderSent : reminderSent // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$AppointmentSlot {

@JsonKey(name: 'start_time') String get startTime;@JsonKey(name: 'end_time') String get endTime;
/// Create a copy of AppointmentSlot
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AppointmentSlotCopyWith<AppointmentSlot> get copyWith => _$AppointmentSlotCopyWithImpl<AppointmentSlot>(this as AppointmentSlot, _$identity);

  /// Serializes this AppointmentSlot to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AppointmentSlot&&(identical(other.startTime, startTime) || other.startTime == startTime)&&(identical(other.endTime, endTime) || other.endTime == endTime));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,startTime,endTime);

@override
String toString() {
  return 'AppointmentSlot(startTime: $startTime, endTime: $endTime)';
}


}

/// @nodoc
abstract mixin class $AppointmentSlotCopyWith<$Res>  {
  factory $AppointmentSlotCopyWith(AppointmentSlot value, $Res Function(AppointmentSlot) _then) = _$AppointmentSlotCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'start_time') String startTime,@JsonKey(name: 'end_time') String endTime
});




}
/// @nodoc
class _$AppointmentSlotCopyWithImpl<$Res>
    implements $AppointmentSlotCopyWith<$Res> {
  _$AppointmentSlotCopyWithImpl(this._self, this._then);

  final AppointmentSlot _self;
  final $Res Function(AppointmentSlot) _then;

/// Create a copy of AppointmentSlot
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? startTime = null,Object? endTime = null,}) {
  return _then(_self.copyWith(
startTime: null == startTime ? _self.startTime : startTime // ignore: cast_nullable_to_non_nullable
as String,endTime: null == endTime ? _self.endTime : endTime // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [AppointmentSlot].
extension AppointmentSlotPatterns on AppointmentSlot {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AppointmentSlot value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AppointmentSlot() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AppointmentSlot value)  $default,){
final _that = this;
switch (_that) {
case _AppointmentSlot():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AppointmentSlot value)?  $default,){
final _that = this;
switch (_that) {
case _AppointmentSlot() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'start_time')  String startTime, @JsonKey(name: 'end_time')  String endTime)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AppointmentSlot() when $default != null:
return $default(_that.startTime,_that.endTime);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'start_time')  String startTime, @JsonKey(name: 'end_time')  String endTime)  $default,) {final _that = this;
switch (_that) {
case _AppointmentSlot():
return $default(_that.startTime,_that.endTime);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'start_time')  String startTime, @JsonKey(name: 'end_time')  String endTime)?  $default,) {final _that = this;
switch (_that) {
case _AppointmentSlot() when $default != null:
return $default(_that.startTime,_that.endTime);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AppointmentSlot extends AppointmentSlot {
  const _AppointmentSlot({@JsonKey(name: 'start_time') required this.startTime, @JsonKey(name: 'end_time') required this.endTime}): super._();
  factory _AppointmentSlot.fromJson(Map<String, dynamic> json) => _$AppointmentSlotFromJson(json);

@override@JsonKey(name: 'start_time') final  String startTime;
@override@JsonKey(name: 'end_time') final  String endTime;

/// Create a copy of AppointmentSlot
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AppointmentSlotCopyWith<_AppointmentSlot> get copyWith => __$AppointmentSlotCopyWithImpl<_AppointmentSlot>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AppointmentSlotToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AppointmentSlot&&(identical(other.startTime, startTime) || other.startTime == startTime)&&(identical(other.endTime, endTime) || other.endTime == endTime));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,startTime,endTime);

@override
String toString() {
  return 'AppointmentSlot(startTime: $startTime, endTime: $endTime)';
}


}

/// @nodoc
abstract mixin class _$AppointmentSlotCopyWith<$Res> implements $AppointmentSlotCopyWith<$Res> {
  factory _$AppointmentSlotCopyWith(_AppointmentSlot value, $Res Function(_AppointmentSlot) _then) = __$AppointmentSlotCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'start_time') String startTime,@JsonKey(name: 'end_time') String endTime
});




}
/// @nodoc
class __$AppointmentSlotCopyWithImpl<$Res>
    implements _$AppointmentSlotCopyWith<$Res> {
  __$AppointmentSlotCopyWithImpl(this._self, this._then);

  final _AppointmentSlot _self;
  final $Res Function(_AppointmentSlot) _then;

/// Create a copy of AppointmentSlot
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? startTime = null,Object? endTime = null,}) {
  return _then(_AppointmentSlot(
startTime: null == startTime ? _self.startTime : startTime // ignore: cast_nullable_to_non_nullable
as String,endTime: null == endTime ? _self.endTime : endTime // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
