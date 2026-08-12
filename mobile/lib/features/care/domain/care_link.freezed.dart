// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'care_link.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$CareLink {

 String get id;/// The **other** party's account id: the caretaker when listing as a
/// patient, the patient when listing as a caretaker. This is the value that
/// becomes `?patient_id=` — and it contains a `#`, so it only ever reaches
/// a URL through `ScopedUrl`.
@JsonKey(name: 'user_id') String get userId; String get name;/// Carries a real `Z` — it goes through `app/core/care.py::utc_iso`.
@JsonKey(name: 'created_at') String get createdAt; bool get notify;// Populated for role=caretaker only.
@JsonKey(name: 'medicine_count') int? get medicineCount;@JsonKey(name: 'next_dose_name') String? get nextDoseName;/// **The patient's own wall clock**, e.g. `"08:00"`. Deliberately not an
/// instant. Parsing it into a `DateTime` would re-express it in the
/// caretaker's zone and show a time neither party acts on — which is why
/// there is no getter here that returns one.
@JsonKey(name: 'next_dose_local') String? get nextDoseLocal;@JsonKey(name: 'next_dose_is_today') bool? get nextDoseIsToday;/// The patient's IANA zone. Compared against the device's to decide
/// whether the time needs "(their time)" after it.
@JsonKey(name: 'next_dose_timezone') String? get nextDoseTimezone;
/// Create a copy of CareLink
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CareLinkCopyWith<CareLink> get copyWith => _$CareLinkCopyWithImpl<CareLink>(this as CareLink, _$identity);

  /// Serializes this CareLink to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CareLink&&(identical(other.id, id) || other.id == id)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.name, name) || other.name == name)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.notify, notify) || other.notify == notify)&&(identical(other.medicineCount, medicineCount) || other.medicineCount == medicineCount)&&(identical(other.nextDoseName, nextDoseName) || other.nextDoseName == nextDoseName)&&(identical(other.nextDoseLocal, nextDoseLocal) || other.nextDoseLocal == nextDoseLocal)&&(identical(other.nextDoseIsToday, nextDoseIsToday) || other.nextDoseIsToday == nextDoseIsToday)&&(identical(other.nextDoseTimezone, nextDoseTimezone) || other.nextDoseTimezone == nextDoseTimezone));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,userId,name,createdAt,notify,medicineCount,nextDoseName,nextDoseLocal,nextDoseIsToday,nextDoseTimezone);

@override
String toString() {
  return 'CareLink(id: $id, userId: $userId, name: $name, createdAt: $createdAt, notify: $notify, medicineCount: $medicineCount, nextDoseName: $nextDoseName, nextDoseLocal: $nextDoseLocal, nextDoseIsToday: $nextDoseIsToday, nextDoseTimezone: $nextDoseTimezone)';
}


}

/// @nodoc
abstract mixin class $CareLinkCopyWith<$Res>  {
  factory $CareLinkCopyWith(CareLink value, $Res Function(CareLink) _then) = _$CareLinkCopyWithImpl;
@useResult
$Res call({
 String id,@JsonKey(name: 'user_id') String userId, String name,@JsonKey(name: 'created_at') String createdAt, bool notify,@JsonKey(name: 'medicine_count') int? medicineCount,@JsonKey(name: 'next_dose_name') String? nextDoseName,@JsonKey(name: 'next_dose_local') String? nextDoseLocal,@JsonKey(name: 'next_dose_is_today') bool? nextDoseIsToday,@JsonKey(name: 'next_dose_timezone') String? nextDoseTimezone
});




}
/// @nodoc
class _$CareLinkCopyWithImpl<$Res>
    implements $CareLinkCopyWith<$Res> {
  _$CareLinkCopyWithImpl(this._self, this._then);

  final CareLink _self;
  final $Res Function(CareLink) _then;

/// Create a copy of CareLink
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? userId = null,Object? name = null,Object? createdAt = null,Object? notify = null,Object? medicineCount = freezed,Object? nextDoseName = freezed,Object? nextDoseLocal = freezed,Object? nextDoseIsToday = freezed,Object? nextDoseTimezone = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String,notify: null == notify ? _self.notify : notify // ignore: cast_nullable_to_non_nullable
as bool,medicineCount: freezed == medicineCount ? _self.medicineCount : medicineCount // ignore: cast_nullable_to_non_nullable
as int?,nextDoseName: freezed == nextDoseName ? _self.nextDoseName : nextDoseName // ignore: cast_nullable_to_non_nullable
as String?,nextDoseLocal: freezed == nextDoseLocal ? _self.nextDoseLocal : nextDoseLocal // ignore: cast_nullable_to_non_nullable
as String?,nextDoseIsToday: freezed == nextDoseIsToday ? _self.nextDoseIsToday : nextDoseIsToday // ignore: cast_nullable_to_non_nullable
as bool?,nextDoseTimezone: freezed == nextDoseTimezone ? _self.nextDoseTimezone : nextDoseTimezone // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [CareLink].
extension CareLinkPatterns on CareLink {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CareLink value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CareLink() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CareLink value)  $default,){
final _that = this;
switch (_that) {
case _CareLink():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CareLink value)?  $default,){
final _that = this;
switch (_that) {
case _CareLink() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'user_id')  String userId,  String name, @JsonKey(name: 'created_at')  String createdAt,  bool notify, @JsonKey(name: 'medicine_count')  int? medicineCount, @JsonKey(name: 'next_dose_name')  String? nextDoseName, @JsonKey(name: 'next_dose_local')  String? nextDoseLocal, @JsonKey(name: 'next_dose_is_today')  bool? nextDoseIsToday, @JsonKey(name: 'next_dose_timezone')  String? nextDoseTimezone)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CareLink() when $default != null:
return $default(_that.id,_that.userId,_that.name,_that.createdAt,_that.notify,_that.medicineCount,_that.nextDoseName,_that.nextDoseLocal,_that.nextDoseIsToday,_that.nextDoseTimezone);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'user_id')  String userId,  String name, @JsonKey(name: 'created_at')  String createdAt,  bool notify, @JsonKey(name: 'medicine_count')  int? medicineCount, @JsonKey(name: 'next_dose_name')  String? nextDoseName, @JsonKey(name: 'next_dose_local')  String? nextDoseLocal, @JsonKey(name: 'next_dose_is_today')  bool? nextDoseIsToday, @JsonKey(name: 'next_dose_timezone')  String? nextDoseTimezone)  $default,) {final _that = this;
switch (_that) {
case _CareLink():
return $default(_that.id,_that.userId,_that.name,_that.createdAt,_that.notify,_that.medicineCount,_that.nextDoseName,_that.nextDoseLocal,_that.nextDoseIsToday,_that.nextDoseTimezone);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id, @JsonKey(name: 'user_id')  String userId,  String name, @JsonKey(name: 'created_at')  String createdAt,  bool notify, @JsonKey(name: 'medicine_count')  int? medicineCount, @JsonKey(name: 'next_dose_name')  String? nextDoseName, @JsonKey(name: 'next_dose_local')  String? nextDoseLocal, @JsonKey(name: 'next_dose_is_today')  bool? nextDoseIsToday, @JsonKey(name: 'next_dose_timezone')  String? nextDoseTimezone)?  $default,) {final _that = this;
switch (_that) {
case _CareLink() when $default != null:
return $default(_that.id,_that.userId,_that.name,_that.createdAt,_that.notify,_that.medicineCount,_that.nextDoseName,_that.nextDoseLocal,_that.nextDoseIsToday,_that.nextDoseTimezone);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _CareLink extends CareLink {
  const _CareLink({required this.id, @JsonKey(name: 'user_id') required this.userId, required this.name, @JsonKey(name: 'created_at') required this.createdAt, required this.notify, @JsonKey(name: 'medicine_count') this.medicineCount, @JsonKey(name: 'next_dose_name') this.nextDoseName, @JsonKey(name: 'next_dose_local') this.nextDoseLocal, @JsonKey(name: 'next_dose_is_today') this.nextDoseIsToday, @JsonKey(name: 'next_dose_timezone') this.nextDoseTimezone}): super._();
  factory _CareLink.fromJson(Map<String, dynamic> json) => _$CareLinkFromJson(json);

@override final  String id;
/// The **other** party's account id: the caretaker when listing as a
/// patient, the patient when listing as a caretaker. This is the value that
/// becomes `?patient_id=` — and it contains a `#`, so it only ever reaches
/// a URL through `ScopedUrl`.
@override@JsonKey(name: 'user_id') final  String userId;
@override final  String name;
/// Carries a real `Z` — it goes through `app/core/care.py::utc_iso`.
@override@JsonKey(name: 'created_at') final  String createdAt;
@override final  bool notify;
// Populated for role=caretaker only.
@override@JsonKey(name: 'medicine_count') final  int? medicineCount;
@override@JsonKey(name: 'next_dose_name') final  String? nextDoseName;
/// **The patient's own wall clock**, e.g. `"08:00"`. Deliberately not an
/// instant. Parsing it into a `DateTime` would re-express it in the
/// caretaker's zone and show a time neither party acts on — which is why
/// there is no getter here that returns one.
@override@JsonKey(name: 'next_dose_local') final  String? nextDoseLocal;
@override@JsonKey(name: 'next_dose_is_today') final  bool? nextDoseIsToday;
/// The patient's IANA zone. Compared against the device's to decide
/// whether the time needs "(their time)" after it.
@override@JsonKey(name: 'next_dose_timezone') final  String? nextDoseTimezone;

/// Create a copy of CareLink
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CareLinkCopyWith<_CareLink> get copyWith => __$CareLinkCopyWithImpl<_CareLink>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CareLinkToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CareLink&&(identical(other.id, id) || other.id == id)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.name, name) || other.name == name)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.notify, notify) || other.notify == notify)&&(identical(other.medicineCount, medicineCount) || other.medicineCount == medicineCount)&&(identical(other.nextDoseName, nextDoseName) || other.nextDoseName == nextDoseName)&&(identical(other.nextDoseLocal, nextDoseLocal) || other.nextDoseLocal == nextDoseLocal)&&(identical(other.nextDoseIsToday, nextDoseIsToday) || other.nextDoseIsToday == nextDoseIsToday)&&(identical(other.nextDoseTimezone, nextDoseTimezone) || other.nextDoseTimezone == nextDoseTimezone));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,userId,name,createdAt,notify,medicineCount,nextDoseName,nextDoseLocal,nextDoseIsToday,nextDoseTimezone);

@override
String toString() {
  return 'CareLink(id: $id, userId: $userId, name: $name, createdAt: $createdAt, notify: $notify, medicineCount: $medicineCount, nextDoseName: $nextDoseName, nextDoseLocal: $nextDoseLocal, nextDoseIsToday: $nextDoseIsToday, nextDoseTimezone: $nextDoseTimezone)';
}


}

/// @nodoc
abstract mixin class _$CareLinkCopyWith<$Res> implements $CareLinkCopyWith<$Res> {
  factory _$CareLinkCopyWith(_CareLink value, $Res Function(_CareLink) _then) = __$CareLinkCopyWithImpl;
@override @useResult
$Res call({
 String id,@JsonKey(name: 'user_id') String userId, String name,@JsonKey(name: 'created_at') String createdAt, bool notify,@JsonKey(name: 'medicine_count') int? medicineCount,@JsonKey(name: 'next_dose_name') String? nextDoseName,@JsonKey(name: 'next_dose_local') String? nextDoseLocal,@JsonKey(name: 'next_dose_is_today') bool? nextDoseIsToday,@JsonKey(name: 'next_dose_timezone') String? nextDoseTimezone
});




}
/// @nodoc
class __$CareLinkCopyWithImpl<$Res>
    implements _$CareLinkCopyWith<$Res> {
  __$CareLinkCopyWithImpl(this._self, this._then);

  final _CareLink _self;
  final $Res Function(_CareLink) _then;

/// Create a copy of CareLink
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? userId = null,Object? name = null,Object? createdAt = null,Object? notify = null,Object? medicineCount = freezed,Object? nextDoseName = freezed,Object? nextDoseLocal = freezed,Object? nextDoseIsToday = freezed,Object? nextDoseTimezone = freezed,}) {
  return _then(_CareLink(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String,notify: null == notify ? _self.notify : notify // ignore: cast_nullable_to_non_nullable
as bool,medicineCount: freezed == medicineCount ? _self.medicineCount : medicineCount // ignore: cast_nullable_to_non_nullable
as int?,nextDoseName: freezed == nextDoseName ? _self.nextDoseName : nextDoseName // ignore: cast_nullable_to_non_nullable
as String?,nextDoseLocal: freezed == nextDoseLocal ? _self.nextDoseLocal : nextDoseLocal // ignore: cast_nullable_to_non_nullable
as String?,nextDoseIsToday: freezed == nextDoseIsToday ? _self.nextDoseIsToday : nextDoseIsToday // ignore: cast_nullable_to_non_nullable
as bool?,nextDoseTimezone: freezed == nextDoseTimezone ? _self.nextDoseTimezone : nextDoseTimezone // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$CareInvite {

 String get code;/// UTC with a marker, via `utc_iso`. 15 minutes out.
@JsonKey(name: 'expires_at') String get expiresAt;
/// Create a copy of CareInvite
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CareInviteCopyWith<CareInvite> get copyWith => _$CareInviteCopyWithImpl<CareInvite>(this as CareInvite, _$identity);

  /// Serializes this CareInvite to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CareInvite&&(identical(other.code, code) || other.code == code)&&(identical(other.expiresAt, expiresAt) || other.expiresAt == expiresAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,code,expiresAt);

@override
String toString() {
  return 'CareInvite(code: $code, expiresAt: $expiresAt)';
}


}

/// @nodoc
abstract mixin class $CareInviteCopyWith<$Res>  {
  factory $CareInviteCopyWith(CareInvite value, $Res Function(CareInvite) _then) = _$CareInviteCopyWithImpl;
@useResult
$Res call({
 String code,@JsonKey(name: 'expires_at') String expiresAt
});




}
/// @nodoc
class _$CareInviteCopyWithImpl<$Res>
    implements $CareInviteCopyWith<$Res> {
  _$CareInviteCopyWithImpl(this._self, this._then);

  final CareInvite _self;
  final $Res Function(CareInvite) _then;

/// Create a copy of CareInvite
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? code = null,Object? expiresAt = null,}) {
  return _then(_self.copyWith(
code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,expiresAt: null == expiresAt ? _self.expiresAt : expiresAt // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [CareInvite].
extension CareInvitePatterns on CareInvite {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CareInvite value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CareInvite() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CareInvite value)  $default,){
final _that = this;
switch (_that) {
case _CareInvite():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CareInvite value)?  $default,){
final _that = this;
switch (_that) {
case _CareInvite() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String code, @JsonKey(name: 'expires_at')  String expiresAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CareInvite() when $default != null:
return $default(_that.code,_that.expiresAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String code, @JsonKey(name: 'expires_at')  String expiresAt)  $default,) {final _that = this;
switch (_that) {
case _CareInvite():
return $default(_that.code,_that.expiresAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String code, @JsonKey(name: 'expires_at')  String expiresAt)?  $default,) {final _that = this;
switch (_that) {
case _CareInvite() when $default != null:
return $default(_that.code,_that.expiresAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _CareInvite extends CareInvite {
  const _CareInvite({required this.code, @JsonKey(name: 'expires_at') required this.expiresAt}): super._();
  factory _CareInvite.fromJson(Map<String, dynamic> json) => _$CareInviteFromJson(json);

@override final  String code;
/// UTC with a marker, via `utc_iso`. 15 minutes out.
@override@JsonKey(name: 'expires_at') final  String expiresAt;

/// Create a copy of CareInvite
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CareInviteCopyWith<_CareInvite> get copyWith => __$CareInviteCopyWithImpl<_CareInvite>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CareInviteToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CareInvite&&(identical(other.code, code) || other.code == code)&&(identical(other.expiresAt, expiresAt) || other.expiresAt == expiresAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,code,expiresAt);

@override
String toString() {
  return 'CareInvite(code: $code, expiresAt: $expiresAt)';
}


}

/// @nodoc
abstract mixin class _$CareInviteCopyWith<$Res> implements $CareInviteCopyWith<$Res> {
  factory _$CareInviteCopyWith(_CareInvite value, $Res Function(_CareInvite) _then) = __$CareInviteCopyWithImpl;
@override @useResult
$Res call({
 String code,@JsonKey(name: 'expires_at') String expiresAt
});




}
/// @nodoc
class __$CareInviteCopyWithImpl<$Res>
    implements _$CareInviteCopyWith<$Res> {
  __$CareInviteCopyWithImpl(this._self, this._then);

  final _CareInvite _self;
  final $Res Function(_CareInvite) _then;

/// Create a copy of CareInvite
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? code = null,Object? expiresAt = null,}) {
  return _then(_CareInvite(
code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,expiresAt: null == expiresAt ? _self.expiresAt : expiresAt // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
