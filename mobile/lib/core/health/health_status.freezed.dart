// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'health_status.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$HealthStatus {

 String get status; bool get database;/// Which mail transport is live: `brevo`, `smtp`, or `none`. Names the
/// transport, never the credential.
 String get email;/// Whether the caretaker feature is switched on.
 bool get caretaker;
/// Create a copy of HealthStatus
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$HealthStatusCopyWith<HealthStatus> get copyWith => _$HealthStatusCopyWithImpl<HealthStatus>(this as HealthStatus, _$identity);

  /// Serializes this HealthStatus to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is HealthStatus&&(identical(other.status, status) || other.status == status)&&(identical(other.database, database) || other.database == database)&&(identical(other.email, email) || other.email == email)&&(identical(other.caretaker, caretaker) || other.caretaker == caretaker));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,status,database,email,caretaker);

@override
String toString() {
  return 'HealthStatus(status: $status, database: $database, email: $email, caretaker: $caretaker)';
}


}

/// @nodoc
abstract mixin class $HealthStatusCopyWith<$Res>  {
  factory $HealthStatusCopyWith(HealthStatus value, $Res Function(HealthStatus) _then) = _$HealthStatusCopyWithImpl;
@useResult
$Res call({
 String status, bool database, String email, bool caretaker
});




}
/// @nodoc
class _$HealthStatusCopyWithImpl<$Res>
    implements $HealthStatusCopyWith<$Res> {
  _$HealthStatusCopyWithImpl(this._self, this._then);

  final HealthStatus _self;
  final $Res Function(HealthStatus) _then;

/// Create a copy of HealthStatus
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? status = null,Object? database = null,Object? email = null,Object? caretaker = null,}) {
  return _then(_self.copyWith(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,database: null == database ? _self.database : database // ignore: cast_nullable_to_non_nullable
as bool,email: null == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String,caretaker: null == caretaker ? _self.caretaker : caretaker // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [HealthStatus].
extension HealthStatusPatterns on HealthStatus {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _HealthStatus value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _HealthStatus() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _HealthStatus value)  $default,){
final _that = this;
switch (_that) {
case _HealthStatus():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _HealthStatus value)?  $default,){
final _that = this;
switch (_that) {
case _HealthStatus() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String status,  bool database,  String email,  bool caretaker)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _HealthStatus() when $default != null:
return $default(_that.status,_that.database,_that.email,_that.caretaker);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String status,  bool database,  String email,  bool caretaker)  $default,) {final _that = this;
switch (_that) {
case _HealthStatus():
return $default(_that.status,_that.database,_that.email,_that.caretaker);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String status,  bool database,  String email,  bool caretaker)?  $default,) {final _that = this;
switch (_that) {
case _HealthStatus() when $default != null:
return $default(_that.status,_that.database,_that.email,_that.caretaker);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _HealthStatus extends HealthStatus {
  const _HealthStatus({required this.status, required this.database, required this.email, required this.caretaker}): super._();
  factory _HealthStatus.fromJson(Map<String, dynamic> json) => _$HealthStatusFromJson(json);

@override final  String status;
@override final  bool database;
/// Which mail transport is live: `brevo`, `smtp`, or `none`. Names the
/// transport, never the credential.
@override final  String email;
/// Whether the caretaker feature is switched on.
@override final  bool caretaker;

/// Create a copy of HealthStatus
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$HealthStatusCopyWith<_HealthStatus> get copyWith => __$HealthStatusCopyWithImpl<_HealthStatus>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$HealthStatusToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _HealthStatus&&(identical(other.status, status) || other.status == status)&&(identical(other.database, database) || other.database == database)&&(identical(other.email, email) || other.email == email)&&(identical(other.caretaker, caretaker) || other.caretaker == caretaker));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,status,database,email,caretaker);

@override
String toString() {
  return 'HealthStatus(status: $status, database: $database, email: $email, caretaker: $caretaker)';
}


}

/// @nodoc
abstract mixin class _$HealthStatusCopyWith<$Res> implements $HealthStatusCopyWith<$Res> {
  factory _$HealthStatusCopyWith(_HealthStatus value, $Res Function(_HealthStatus) _then) = __$HealthStatusCopyWithImpl;
@override @useResult
$Res call({
 String status, bool database, String email, bool caretaker
});




}
/// @nodoc
class __$HealthStatusCopyWithImpl<$Res>
    implements _$HealthStatusCopyWith<$Res> {
  __$HealthStatusCopyWithImpl(this._self, this._then);

  final _HealthStatus _self;
  final $Res Function(_HealthStatus) _then;

/// Create a copy of HealthStatus
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? status = null,Object? database = null,Object? email = null,Object? caretaker = null,}) {
  return _then(_HealthStatus(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,database: null == database ? _self.database : database // ignore: cast_nullable_to_non_nullable
as bool,email: null == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String,caretaker: null == caretaker ? _self.caretaker : caretaker // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
