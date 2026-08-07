// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'medicine.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Medicine {

 String get id; String get name; String get dosage; String get frequency;/// `"YYYY-MM-DD"`, and it stays a string. The server compares these
/// lexically, so round-tripping one through a `DateTime` would risk
/// shifting the day and silently changing which medicines count as active.
@JsonKey(name: 'start_date') String get startDate;@JsonKey(name: 'end_date') String? get endDate;/// A JSON array **encoded as a string**: `"[\"08:00\",\"20:00\"]"`.
/// Read it through [times]; never parse it at a call site.
@JsonKey(name: 'taking_times') String? get takingTimes; String? get notes;@JsonKey(name: 'created_at') String? get createdAt;
/// Create a copy of Medicine
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MedicineCopyWith<Medicine> get copyWith => _$MedicineCopyWithImpl<Medicine>(this as Medicine, _$identity);

  /// Serializes this Medicine to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Medicine&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.dosage, dosage) || other.dosage == dosage)&&(identical(other.frequency, frequency) || other.frequency == frequency)&&(identical(other.startDate, startDate) || other.startDate == startDate)&&(identical(other.endDate, endDate) || other.endDate == endDate)&&(identical(other.takingTimes, takingTimes) || other.takingTimes == takingTimes)&&(identical(other.notes, notes) || other.notes == notes)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,dosage,frequency,startDate,endDate,takingTimes,notes,createdAt);

@override
String toString() {
  return 'Medicine(id: $id, name: $name, dosage: $dosage, frequency: $frequency, startDate: $startDate, endDate: $endDate, takingTimes: $takingTimes, notes: $notes, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class $MedicineCopyWith<$Res>  {
  factory $MedicineCopyWith(Medicine value, $Res Function(Medicine) _then) = _$MedicineCopyWithImpl;
@useResult
$Res call({
 String id, String name, String dosage, String frequency,@JsonKey(name: 'start_date') String startDate,@JsonKey(name: 'end_date') String? endDate,@JsonKey(name: 'taking_times') String? takingTimes, String? notes,@JsonKey(name: 'created_at') String? createdAt
});




}
/// @nodoc
class _$MedicineCopyWithImpl<$Res>
    implements $MedicineCopyWith<$Res> {
  _$MedicineCopyWithImpl(this._self, this._then);

  final Medicine _self;
  final $Res Function(Medicine) _then;

/// Create a copy of Medicine
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? dosage = null,Object? frequency = null,Object? startDate = null,Object? endDate = freezed,Object? takingTimes = freezed,Object? notes = freezed,Object? createdAt = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,dosage: null == dosage ? _self.dosage : dosage // ignore: cast_nullable_to_non_nullable
as String,frequency: null == frequency ? _self.frequency : frequency // ignore: cast_nullable_to_non_nullable
as String,startDate: null == startDate ? _self.startDate : startDate // ignore: cast_nullable_to_non_nullable
as String,endDate: freezed == endDate ? _self.endDate : endDate // ignore: cast_nullable_to_non_nullable
as String?,takingTimes: freezed == takingTimes ? _self.takingTimes : takingTimes // ignore: cast_nullable_to_non_nullable
as String?,notes: freezed == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [Medicine].
extension MedicinePatterns on Medicine {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Medicine value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Medicine() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Medicine value)  $default,){
final _that = this;
switch (_that) {
case _Medicine():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Medicine value)?  $default,){
final _that = this;
switch (_that) {
case _Medicine() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  String dosage,  String frequency, @JsonKey(name: 'start_date')  String startDate, @JsonKey(name: 'end_date')  String? endDate, @JsonKey(name: 'taking_times')  String? takingTimes,  String? notes, @JsonKey(name: 'created_at')  String? createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Medicine() when $default != null:
return $default(_that.id,_that.name,_that.dosage,_that.frequency,_that.startDate,_that.endDate,_that.takingTimes,_that.notes,_that.createdAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  String dosage,  String frequency, @JsonKey(name: 'start_date')  String startDate, @JsonKey(name: 'end_date')  String? endDate, @JsonKey(name: 'taking_times')  String? takingTimes,  String? notes, @JsonKey(name: 'created_at')  String? createdAt)  $default,) {final _that = this;
switch (_that) {
case _Medicine():
return $default(_that.id,_that.name,_that.dosage,_that.frequency,_that.startDate,_that.endDate,_that.takingTimes,_that.notes,_that.createdAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  String dosage,  String frequency, @JsonKey(name: 'start_date')  String startDate, @JsonKey(name: 'end_date')  String? endDate, @JsonKey(name: 'taking_times')  String? takingTimes,  String? notes, @JsonKey(name: 'created_at')  String? createdAt)?  $default,) {final _that = this;
switch (_that) {
case _Medicine() when $default != null:
return $default(_that.id,_that.name,_that.dosage,_that.frequency,_that.startDate,_that.endDate,_that.takingTimes,_that.notes,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Medicine extends Medicine {
  const _Medicine({required this.id, required this.name, required this.dosage, required this.frequency, @JsonKey(name: 'start_date') required this.startDate, @JsonKey(name: 'end_date') this.endDate, @JsonKey(name: 'taking_times') this.takingTimes, this.notes, @JsonKey(name: 'created_at') this.createdAt}): super._();
  factory _Medicine.fromJson(Map<String, dynamic> json) => _$MedicineFromJson(json);

@override final  String id;
@override final  String name;
@override final  String dosage;
@override final  String frequency;
/// `"YYYY-MM-DD"`, and it stays a string. The server compares these
/// lexically, so round-tripping one through a `DateTime` would risk
/// shifting the day and silently changing which medicines count as active.
@override@JsonKey(name: 'start_date') final  String startDate;
@override@JsonKey(name: 'end_date') final  String? endDate;
/// A JSON array **encoded as a string**: `"[\"08:00\",\"20:00\"]"`.
/// Read it through [times]; never parse it at a call site.
@override@JsonKey(name: 'taking_times') final  String? takingTimes;
@override final  String? notes;
@override@JsonKey(name: 'created_at') final  String? createdAt;

/// Create a copy of Medicine
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MedicineCopyWith<_Medicine> get copyWith => __$MedicineCopyWithImpl<_Medicine>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MedicineToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Medicine&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.dosage, dosage) || other.dosage == dosage)&&(identical(other.frequency, frequency) || other.frequency == frequency)&&(identical(other.startDate, startDate) || other.startDate == startDate)&&(identical(other.endDate, endDate) || other.endDate == endDate)&&(identical(other.takingTimes, takingTimes) || other.takingTimes == takingTimes)&&(identical(other.notes, notes) || other.notes == notes)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,dosage,frequency,startDate,endDate,takingTimes,notes,createdAt);

@override
String toString() {
  return 'Medicine(id: $id, name: $name, dosage: $dosage, frequency: $frequency, startDate: $startDate, endDate: $endDate, takingTimes: $takingTimes, notes: $notes, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$MedicineCopyWith<$Res> implements $MedicineCopyWith<$Res> {
  factory _$MedicineCopyWith(_Medicine value, $Res Function(_Medicine) _then) = __$MedicineCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, String dosage, String frequency,@JsonKey(name: 'start_date') String startDate,@JsonKey(name: 'end_date') String? endDate,@JsonKey(name: 'taking_times') String? takingTimes, String? notes,@JsonKey(name: 'created_at') String? createdAt
});




}
/// @nodoc
class __$MedicineCopyWithImpl<$Res>
    implements _$MedicineCopyWith<$Res> {
  __$MedicineCopyWithImpl(this._self, this._then);

  final _Medicine _self;
  final $Res Function(_Medicine) _then;

/// Create a copy of Medicine
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? dosage = null,Object? frequency = null,Object? startDate = null,Object? endDate = freezed,Object? takingTimes = freezed,Object? notes = freezed,Object? createdAt = freezed,}) {
  return _then(_Medicine(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,dosage: null == dosage ? _self.dosage : dosage // ignore: cast_nullable_to_non_nullable
as String,frequency: null == frequency ? _self.frequency : frequency // ignore: cast_nullable_to_non_nullable
as String,startDate: null == startDate ? _self.startDate : startDate // ignore: cast_nullable_to_non_nullable
as String,endDate: freezed == endDate ? _self.endDate : endDate // ignore: cast_nullable_to_non_nullable
as String?,takingTimes: freezed == takingTimes ? _self.takingTimes : takingTimes // ignore: cast_nullable_to_non_nullable
as String?,notes: freezed == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$DrugInteraction {

@JsonKey(name: 'drug_a') String get drugA;@JsonKey(name: 'drug_b') String get drugB;/// `severe` · `moderate` · `minor`, lowercase from the offline dataset.
 String get severity; String get description;
/// Create a copy of DrugInteraction
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DrugInteractionCopyWith<DrugInteraction> get copyWith => _$DrugInteractionCopyWithImpl<DrugInteraction>(this as DrugInteraction, _$identity);

  /// Serializes this DrugInteraction to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DrugInteraction&&(identical(other.drugA, drugA) || other.drugA == drugA)&&(identical(other.drugB, drugB) || other.drugB == drugB)&&(identical(other.severity, severity) || other.severity == severity)&&(identical(other.description, description) || other.description == description));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,drugA,drugB,severity,description);

@override
String toString() {
  return 'DrugInteraction(drugA: $drugA, drugB: $drugB, severity: $severity, description: $description)';
}


}

/// @nodoc
abstract mixin class $DrugInteractionCopyWith<$Res>  {
  factory $DrugInteractionCopyWith(DrugInteraction value, $Res Function(DrugInteraction) _then) = _$DrugInteractionCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'drug_a') String drugA,@JsonKey(name: 'drug_b') String drugB, String severity, String description
});




}
/// @nodoc
class _$DrugInteractionCopyWithImpl<$Res>
    implements $DrugInteractionCopyWith<$Res> {
  _$DrugInteractionCopyWithImpl(this._self, this._then);

  final DrugInteraction _self;
  final $Res Function(DrugInteraction) _then;

/// Create a copy of DrugInteraction
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? drugA = null,Object? drugB = null,Object? severity = null,Object? description = null,}) {
  return _then(_self.copyWith(
drugA: null == drugA ? _self.drugA : drugA // ignore: cast_nullable_to_non_nullable
as String,drugB: null == drugB ? _self.drugB : drugB // ignore: cast_nullable_to_non_nullable
as String,severity: null == severity ? _self.severity : severity // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [DrugInteraction].
extension DrugInteractionPatterns on DrugInteraction {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DrugInteraction value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DrugInteraction() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DrugInteraction value)  $default,){
final _that = this;
switch (_that) {
case _DrugInteraction():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DrugInteraction value)?  $default,){
final _that = this;
switch (_that) {
case _DrugInteraction() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'drug_a')  String drugA, @JsonKey(name: 'drug_b')  String drugB,  String severity,  String description)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DrugInteraction() when $default != null:
return $default(_that.drugA,_that.drugB,_that.severity,_that.description);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'drug_a')  String drugA, @JsonKey(name: 'drug_b')  String drugB,  String severity,  String description)  $default,) {final _that = this;
switch (_that) {
case _DrugInteraction():
return $default(_that.drugA,_that.drugB,_that.severity,_that.description);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'drug_a')  String drugA, @JsonKey(name: 'drug_b')  String drugB,  String severity,  String description)?  $default,) {final _that = this;
switch (_that) {
case _DrugInteraction() when $default != null:
return $default(_that.drugA,_that.drugB,_that.severity,_that.description);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _DrugInteraction extends DrugInteraction {
  const _DrugInteraction({@JsonKey(name: 'drug_a') required this.drugA, @JsonKey(name: 'drug_b') required this.drugB, required this.severity, required this.description}): super._();
  factory _DrugInteraction.fromJson(Map<String, dynamic> json) => _$DrugInteractionFromJson(json);

@override@JsonKey(name: 'drug_a') final  String drugA;
@override@JsonKey(name: 'drug_b') final  String drugB;
/// `severe` · `moderate` · `minor`, lowercase from the offline dataset.
@override final  String severity;
@override final  String description;

/// Create a copy of DrugInteraction
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DrugInteractionCopyWith<_DrugInteraction> get copyWith => __$DrugInteractionCopyWithImpl<_DrugInteraction>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DrugInteractionToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DrugInteraction&&(identical(other.drugA, drugA) || other.drugA == drugA)&&(identical(other.drugB, drugB) || other.drugB == drugB)&&(identical(other.severity, severity) || other.severity == severity)&&(identical(other.description, description) || other.description == description));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,drugA,drugB,severity,description);

@override
String toString() {
  return 'DrugInteraction(drugA: $drugA, drugB: $drugB, severity: $severity, description: $description)';
}


}

/// @nodoc
abstract mixin class _$DrugInteractionCopyWith<$Res> implements $DrugInteractionCopyWith<$Res> {
  factory _$DrugInteractionCopyWith(_DrugInteraction value, $Res Function(_DrugInteraction) _then) = __$DrugInteractionCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'drug_a') String drugA,@JsonKey(name: 'drug_b') String drugB, String severity, String description
});




}
/// @nodoc
class __$DrugInteractionCopyWithImpl<$Res>
    implements _$DrugInteractionCopyWith<$Res> {
  __$DrugInteractionCopyWithImpl(this._self, this._then);

  final _DrugInteraction _self;
  final $Res Function(_DrugInteraction) _then;

/// Create a copy of DrugInteraction
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? drugA = null,Object? drugB = null,Object? severity = null,Object? description = null,}) {
  return _then(_DrugInteraction(
drugA: null == drugA ? _self.drugA : drugA // ignore: cast_nullable_to_non_nullable
as String,drugB: null == drugB ? _self.drugB : drugB // ignore: cast_nullable_to_non_nullable
as String,severity: null == severity ? _self.severity : severity // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$InteractionCheck {

 List<DrugInteraction> get interactions;/// How many medicines were considered — active ones only. Shown so "no
/// interactions found" can say what it looked at.
@JsonKey(name: 'checked_count') int get checkedCount;
/// Create a copy of InteractionCheck
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$InteractionCheckCopyWith<InteractionCheck> get copyWith => _$InteractionCheckCopyWithImpl<InteractionCheck>(this as InteractionCheck, _$identity);

  /// Serializes this InteractionCheck to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is InteractionCheck&&const DeepCollectionEquality().equals(other.interactions, interactions)&&(identical(other.checkedCount, checkedCount) || other.checkedCount == checkedCount));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(interactions),checkedCount);

@override
String toString() {
  return 'InteractionCheck(interactions: $interactions, checkedCount: $checkedCount)';
}


}

/// @nodoc
abstract mixin class $InteractionCheckCopyWith<$Res>  {
  factory $InteractionCheckCopyWith(InteractionCheck value, $Res Function(InteractionCheck) _then) = _$InteractionCheckCopyWithImpl;
@useResult
$Res call({
 List<DrugInteraction> interactions,@JsonKey(name: 'checked_count') int checkedCount
});




}
/// @nodoc
class _$InteractionCheckCopyWithImpl<$Res>
    implements $InteractionCheckCopyWith<$Res> {
  _$InteractionCheckCopyWithImpl(this._self, this._then);

  final InteractionCheck _self;
  final $Res Function(InteractionCheck) _then;

/// Create a copy of InteractionCheck
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? interactions = null,Object? checkedCount = null,}) {
  return _then(_self.copyWith(
interactions: null == interactions ? _self.interactions : interactions // ignore: cast_nullable_to_non_nullable
as List<DrugInteraction>,checkedCount: null == checkedCount ? _self.checkedCount : checkedCount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [InteractionCheck].
extension InteractionCheckPatterns on InteractionCheck {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _InteractionCheck value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _InteractionCheck() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _InteractionCheck value)  $default,){
final _that = this;
switch (_that) {
case _InteractionCheck():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _InteractionCheck value)?  $default,){
final _that = this;
switch (_that) {
case _InteractionCheck() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<DrugInteraction> interactions, @JsonKey(name: 'checked_count')  int checkedCount)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _InteractionCheck() when $default != null:
return $default(_that.interactions,_that.checkedCount);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<DrugInteraction> interactions, @JsonKey(name: 'checked_count')  int checkedCount)  $default,) {final _that = this;
switch (_that) {
case _InteractionCheck():
return $default(_that.interactions,_that.checkedCount);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<DrugInteraction> interactions, @JsonKey(name: 'checked_count')  int checkedCount)?  $default,) {final _that = this;
switch (_that) {
case _InteractionCheck() when $default != null:
return $default(_that.interactions,_that.checkedCount);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _InteractionCheck implements InteractionCheck {
  const _InteractionCheck({required final  List<DrugInteraction> interactions, @JsonKey(name: 'checked_count') required this.checkedCount}): _interactions = interactions;
  factory _InteractionCheck.fromJson(Map<String, dynamic> json) => _$InteractionCheckFromJson(json);

 final  List<DrugInteraction> _interactions;
@override List<DrugInteraction> get interactions {
  if (_interactions is EqualUnmodifiableListView) return _interactions;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_interactions);
}

/// How many medicines were considered — active ones only. Shown so "no
/// interactions found" can say what it looked at.
@override@JsonKey(name: 'checked_count') final  int checkedCount;

/// Create a copy of InteractionCheck
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$InteractionCheckCopyWith<_InteractionCheck> get copyWith => __$InteractionCheckCopyWithImpl<_InteractionCheck>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$InteractionCheckToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _InteractionCheck&&const DeepCollectionEquality().equals(other._interactions, _interactions)&&(identical(other.checkedCount, checkedCount) || other.checkedCount == checkedCount));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_interactions),checkedCount);

@override
String toString() {
  return 'InteractionCheck(interactions: $interactions, checkedCount: $checkedCount)';
}


}

/// @nodoc
abstract mixin class _$InteractionCheckCopyWith<$Res> implements $InteractionCheckCopyWith<$Res> {
  factory _$InteractionCheckCopyWith(_InteractionCheck value, $Res Function(_InteractionCheck) _then) = __$InteractionCheckCopyWithImpl;
@override @useResult
$Res call({
 List<DrugInteraction> interactions,@JsonKey(name: 'checked_count') int checkedCount
});




}
/// @nodoc
class __$InteractionCheckCopyWithImpl<$Res>
    implements _$InteractionCheckCopyWith<$Res> {
  __$InteractionCheckCopyWithImpl(this._self, this._then);

  final _InteractionCheck _self;
  final $Res Function(_InteractionCheck) _then;

/// Create a copy of InteractionCheck
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? interactions = null,Object? checkedCount = null,}) {
  return _then(_InteractionCheck(
interactions: null == interactions ? _self._interactions : interactions // ignore: cast_nullable_to_non_nullable
as List<DrugInteraction>,checkedCount: null == checkedCount ? _self.checkedCount : checkedCount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$MedicineIntake {

 String get id;@JsonKey(name: 'medicine_id') String get medicineId;/// The `"08:00"` slot this refers to, not the moment it was recorded.
@JsonKey(name: 'scheduled_time') String get scheduledTime;/// `taken` · `snoozed` · `skipped`.
 String get status;@JsonKey(name: 'recorded_at') String get recordedAt;
/// Create a copy of MedicineIntake
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MedicineIntakeCopyWith<MedicineIntake> get copyWith => _$MedicineIntakeCopyWithImpl<MedicineIntake>(this as MedicineIntake, _$identity);

  /// Serializes this MedicineIntake to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MedicineIntake&&(identical(other.id, id) || other.id == id)&&(identical(other.medicineId, medicineId) || other.medicineId == medicineId)&&(identical(other.scheduledTime, scheduledTime) || other.scheduledTime == scheduledTime)&&(identical(other.status, status) || other.status == status)&&(identical(other.recordedAt, recordedAt) || other.recordedAt == recordedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,medicineId,scheduledTime,status,recordedAt);

@override
String toString() {
  return 'MedicineIntake(id: $id, medicineId: $medicineId, scheduledTime: $scheduledTime, status: $status, recordedAt: $recordedAt)';
}


}

/// @nodoc
abstract mixin class $MedicineIntakeCopyWith<$Res>  {
  factory $MedicineIntakeCopyWith(MedicineIntake value, $Res Function(MedicineIntake) _then) = _$MedicineIntakeCopyWithImpl;
@useResult
$Res call({
 String id,@JsonKey(name: 'medicine_id') String medicineId,@JsonKey(name: 'scheduled_time') String scheduledTime, String status,@JsonKey(name: 'recorded_at') String recordedAt
});




}
/// @nodoc
class _$MedicineIntakeCopyWithImpl<$Res>
    implements $MedicineIntakeCopyWith<$Res> {
  _$MedicineIntakeCopyWithImpl(this._self, this._then);

  final MedicineIntake _self;
  final $Res Function(MedicineIntake) _then;

/// Create a copy of MedicineIntake
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? medicineId = null,Object? scheduledTime = null,Object? status = null,Object? recordedAt = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,medicineId: null == medicineId ? _self.medicineId : medicineId // ignore: cast_nullable_to_non_nullable
as String,scheduledTime: null == scheduledTime ? _self.scheduledTime : scheduledTime // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,recordedAt: null == recordedAt ? _self.recordedAt : recordedAt // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [MedicineIntake].
extension MedicineIntakePatterns on MedicineIntake {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MedicineIntake value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MedicineIntake() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MedicineIntake value)  $default,){
final _that = this;
switch (_that) {
case _MedicineIntake():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MedicineIntake value)?  $default,){
final _that = this;
switch (_that) {
case _MedicineIntake() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'medicine_id')  String medicineId, @JsonKey(name: 'scheduled_time')  String scheduledTime,  String status, @JsonKey(name: 'recorded_at')  String recordedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MedicineIntake() when $default != null:
return $default(_that.id,_that.medicineId,_that.scheduledTime,_that.status,_that.recordedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'medicine_id')  String medicineId, @JsonKey(name: 'scheduled_time')  String scheduledTime,  String status, @JsonKey(name: 'recorded_at')  String recordedAt)  $default,) {final _that = this;
switch (_that) {
case _MedicineIntake():
return $default(_that.id,_that.medicineId,_that.scheduledTime,_that.status,_that.recordedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id, @JsonKey(name: 'medicine_id')  String medicineId, @JsonKey(name: 'scheduled_time')  String scheduledTime,  String status, @JsonKey(name: 'recorded_at')  String recordedAt)?  $default,) {final _that = this;
switch (_that) {
case _MedicineIntake() when $default != null:
return $default(_that.id,_that.medicineId,_that.scheduledTime,_that.status,_that.recordedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MedicineIntake extends MedicineIntake {
  const _MedicineIntake({required this.id, @JsonKey(name: 'medicine_id') required this.medicineId, @JsonKey(name: 'scheduled_time') required this.scheduledTime, required this.status, @JsonKey(name: 'recorded_at') required this.recordedAt}): super._();
  factory _MedicineIntake.fromJson(Map<String, dynamic> json) => _$MedicineIntakeFromJson(json);

@override final  String id;
@override@JsonKey(name: 'medicine_id') final  String medicineId;
/// The `"08:00"` slot this refers to, not the moment it was recorded.
@override@JsonKey(name: 'scheduled_time') final  String scheduledTime;
/// `taken` · `snoozed` · `skipped`.
@override final  String status;
@override@JsonKey(name: 'recorded_at') final  String recordedAt;

/// Create a copy of MedicineIntake
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MedicineIntakeCopyWith<_MedicineIntake> get copyWith => __$MedicineIntakeCopyWithImpl<_MedicineIntake>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MedicineIntakeToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MedicineIntake&&(identical(other.id, id) || other.id == id)&&(identical(other.medicineId, medicineId) || other.medicineId == medicineId)&&(identical(other.scheduledTime, scheduledTime) || other.scheduledTime == scheduledTime)&&(identical(other.status, status) || other.status == status)&&(identical(other.recordedAt, recordedAt) || other.recordedAt == recordedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,medicineId,scheduledTime,status,recordedAt);

@override
String toString() {
  return 'MedicineIntake(id: $id, medicineId: $medicineId, scheduledTime: $scheduledTime, status: $status, recordedAt: $recordedAt)';
}


}

/// @nodoc
abstract mixin class _$MedicineIntakeCopyWith<$Res> implements $MedicineIntakeCopyWith<$Res> {
  factory _$MedicineIntakeCopyWith(_MedicineIntake value, $Res Function(_MedicineIntake) _then) = __$MedicineIntakeCopyWithImpl;
@override @useResult
$Res call({
 String id,@JsonKey(name: 'medicine_id') String medicineId,@JsonKey(name: 'scheduled_time') String scheduledTime, String status,@JsonKey(name: 'recorded_at') String recordedAt
});




}
/// @nodoc
class __$MedicineIntakeCopyWithImpl<$Res>
    implements _$MedicineIntakeCopyWith<$Res> {
  __$MedicineIntakeCopyWithImpl(this._self, this._then);

  final _MedicineIntake _self;
  final $Res Function(_MedicineIntake) _then;

/// Create a copy of MedicineIntake
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? medicineId = null,Object? scheduledTime = null,Object? status = null,Object? recordedAt = null,}) {
  return _then(_MedicineIntake(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,medicineId: null == medicineId ? _self.medicineId : medicineId // ignore: cast_nullable_to_non_nullable
as String,scheduledTime: null == scheduledTime ? _self.scheduledTime : scheduledTime // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,recordedAt: null == recordedAt ? _self.recordedAt : recordedAt // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$MedicineAuditEntry {

 int get id;@JsonKey(name: 'actor_id') String get actorId;@JsonKey(name: 'actor_name') String get actorName;@JsonKey(name: 'medicine_id') String? get medicineId;@JsonKey(name: 'medicine_name') String? get medicineName;/// `create` · `update` · `delete` · `restore`.
 String get action;@JsonKey(name: 'created_at') String get createdAt;@JsonKey(name: 'by_caretaker') bool get byCaretaker;
/// Create a copy of MedicineAuditEntry
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MedicineAuditEntryCopyWith<MedicineAuditEntry> get copyWith => _$MedicineAuditEntryCopyWithImpl<MedicineAuditEntry>(this as MedicineAuditEntry, _$identity);

  /// Serializes this MedicineAuditEntry to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MedicineAuditEntry&&(identical(other.id, id) || other.id == id)&&(identical(other.actorId, actorId) || other.actorId == actorId)&&(identical(other.actorName, actorName) || other.actorName == actorName)&&(identical(other.medicineId, medicineId) || other.medicineId == medicineId)&&(identical(other.medicineName, medicineName) || other.medicineName == medicineName)&&(identical(other.action, action) || other.action == action)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.byCaretaker, byCaretaker) || other.byCaretaker == byCaretaker));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,actorId,actorName,medicineId,medicineName,action,createdAt,byCaretaker);

@override
String toString() {
  return 'MedicineAuditEntry(id: $id, actorId: $actorId, actorName: $actorName, medicineId: $medicineId, medicineName: $medicineName, action: $action, createdAt: $createdAt, byCaretaker: $byCaretaker)';
}


}

/// @nodoc
abstract mixin class $MedicineAuditEntryCopyWith<$Res>  {
  factory $MedicineAuditEntryCopyWith(MedicineAuditEntry value, $Res Function(MedicineAuditEntry) _then) = _$MedicineAuditEntryCopyWithImpl;
@useResult
$Res call({
 int id,@JsonKey(name: 'actor_id') String actorId,@JsonKey(name: 'actor_name') String actorName,@JsonKey(name: 'medicine_id') String? medicineId,@JsonKey(name: 'medicine_name') String? medicineName, String action,@JsonKey(name: 'created_at') String createdAt,@JsonKey(name: 'by_caretaker') bool byCaretaker
});




}
/// @nodoc
class _$MedicineAuditEntryCopyWithImpl<$Res>
    implements $MedicineAuditEntryCopyWith<$Res> {
  _$MedicineAuditEntryCopyWithImpl(this._self, this._then);

  final MedicineAuditEntry _self;
  final $Res Function(MedicineAuditEntry) _then;

/// Create a copy of MedicineAuditEntry
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? actorId = null,Object? actorName = null,Object? medicineId = freezed,Object? medicineName = freezed,Object? action = null,Object? createdAt = null,Object? byCaretaker = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,actorId: null == actorId ? _self.actorId : actorId // ignore: cast_nullable_to_non_nullable
as String,actorName: null == actorName ? _self.actorName : actorName // ignore: cast_nullable_to_non_nullable
as String,medicineId: freezed == medicineId ? _self.medicineId : medicineId // ignore: cast_nullable_to_non_nullable
as String?,medicineName: freezed == medicineName ? _self.medicineName : medicineName // ignore: cast_nullable_to_non_nullable
as String?,action: null == action ? _self.action : action // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String,byCaretaker: null == byCaretaker ? _self.byCaretaker : byCaretaker // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [MedicineAuditEntry].
extension MedicineAuditEntryPatterns on MedicineAuditEntry {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MedicineAuditEntry value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MedicineAuditEntry() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MedicineAuditEntry value)  $default,){
final _that = this;
switch (_that) {
case _MedicineAuditEntry():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MedicineAuditEntry value)?  $default,){
final _that = this;
switch (_that) {
case _MedicineAuditEntry() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id, @JsonKey(name: 'actor_id')  String actorId, @JsonKey(name: 'actor_name')  String actorName, @JsonKey(name: 'medicine_id')  String? medicineId, @JsonKey(name: 'medicine_name')  String? medicineName,  String action, @JsonKey(name: 'created_at')  String createdAt, @JsonKey(name: 'by_caretaker')  bool byCaretaker)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MedicineAuditEntry() when $default != null:
return $default(_that.id,_that.actorId,_that.actorName,_that.medicineId,_that.medicineName,_that.action,_that.createdAt,_that.byCaretaker);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id, @JsonKey(name: 'actor_id')  String actorId, @JsonKey(name: 'actor_name')  String actorName, @JsonKey(name: 'medicine_id')  String? medicineId, @JsonKey(name: 'medicine_name')  String? medicineName,  String action, @JsonKey(name: 'created_at')  String createdAt, @JsonKey(name: 'by_caretaker')  bool byCaretaker)  $default,) {final _that = this;
switch (_that) {
case _MedicineAuditEntry():
return $default(_that.id,_that.actorId,_that.actorName,_that.medicineId,_that.medicineName,_that.action,_that.createdAt,_that.byCaretaker);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id, @JsonKey(name: 'actor_id')  String actorId, @JsonKey(name: 'actor_name')  String actorName, @JsonKey(name: 'medicine_id')  String? medicineId, @JsonKey(name: 'medicine_name')  String? medicineName,  String action, @JsonKey(name: 'created_at')  String createdAt, @JsonKey(name: 'by_caretaker')  bool byCaretaker)?  $default,) {final _that = this;
switch (_that) {
case _MedicineAuditEntry() when $default != null:
return $default(_that.id,_that.actorId,_that.actorName,_that.medicineId,_that.medicineName,_that.action,_that.createdAt,_that.byCaretaker);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MedicineAuditEntry extends MedicineAuditEntry {
  const _MedicineAuditEntry({required this.id, @JsonKey(name: 'actor_id') required this.actorId, @JsonKey(name: 'actor_name') required this.actorName, @JsonKey(name: 'medicine_id') this.medicineId, @JsonKey(name: 'medicine_name') this.medicineName, required this.action, @JsonKey(name: 'created_at') required this.createdAt, @JsonKey(name: 'by_caretaker') required this.byCaretaker}): super._();
  factory _MedicineAuditEntry.fromJson(Map<String, dynamic> json) => _$MedicineAuditEntryFromJson(json);

@override final  int id;
@override@JsonKey(name: 'actor_id') final  String actorId;
@override@JsonKey(name: 'actor_name') final  String actorName;
@override@JsonKey(name: 'medicine_id') final  String? medicineId;
@override@JsonKey(name: 'medicine_name') final  String? medicineName;
/// `create` · `update` · `delete` · `restore`.
@override final  String action;
@override@JsonKey(name: 'created_at') final  String createdAt;
@override@JsonKey(name: 'by_caretaker') final  bool byCaretaker;

/// Create a copy of MedicineAuditEntry
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MedicineAuditEntryCopyWith<_MedicineAuditEntry> get copyWith => __$MedicineAuditEntryCopyWithImpl<_MedicineAuditEntry>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MedicineAuditEntryToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MedicineAuditEntry&&(identical(other.id, id) || other.id == id)&&(identical(other.actorId, actorId) || other.actorId == actorId)&&(identical(other.actorName, actorName) || other.actorName == actorName)&&(identical(other.medicineId, medicineId) || other.medicineId == medicineId)&&(identical(other.medicineName, medicineName) || other.medicineName == medicineName)&&(identical(other.action, action) || other.action == action)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.byCaretaker, byCaretaker) || other.byCaretaker == byCaretaker));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,actorId,actorName,medicineId,medicineName,action,createdAt,byCaretaker);

@override
String toString() {
  return 'MedicineAuditEntry(id: $id, actorId: $actorId, actorName: $actorName, medicineId: $medicineId, medicineName: $medicineName, action: $action, createdAt: $createdAt, byCaretaker: $byCaretaker)';
}


}

/// @nodoc
abstract mixin class _$MedicineAuditEntryCopyWith<$Res> implements $MedicineAuditEntryCopyWith<$Res> {
  factory _$MedicineAuditEntryCopyWith(_MedicineAuditEntry value, $Res Function(_MedicineAuditEntry) _then) = __$MedicineAuditEntryCopyWithImpl;
@override @useResult
$Res call({
 int id,@JsonKey(name: 'actor_id') String actorId,@JsonKey(name: 'actor_name') String actorName,@JsonKey(name: 'medicine_id') String? medicineId,@JsonKey(name: 'medicine_name') String? medicineName, String action,@JsonKey(name: 'created_at') String createdAt,@JsonKey(name: 'by_caretaker') bool byCaretaker
});




}
/// @nodoc
class __$MedicineAuditEntryCopyWithImpl<$Res>
    implements _$MedicineAuditEntryCopyWith<$Res> {
  __$MedicineAuditEntryCopyWithImpl(this._self, this._then);

  final _MedicineAuditEntry _self;
  final $Res Function(_MedicineAuditEntry) _then;

/// Create a copy of MedicineAuditEntry
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? actorId = null,Object? actorName = null,Object? medicineId = freezed,Object? medicineName = freezed,Object? action = null,Object? createdAt = null,Object? byCaretaker = null,}) {
  return _then(_MedicineAuditEntry(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,actorId: null == actorId ? _self.actorId : actorId // ignore: cast_nullable_to_non_nullable
as String,actorName: null == actorName ? _self.actorName : actorName // ignore: cast_nullable_to_non_nullable
as String,medicineId: freezed == medicineId ? _self.medicineId : medicineId // ignore: cast_nullable_to_non_nullable
as String?,medicineName: freezed == medicineName ? _self.medicineName : medicineName // ignore: cast_nullable_to_non_nullable
as String?,action: null == action ? _self.action : action // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String,byCaretaker: null == byCaretaker ? _self.byCaretaker : byCaretaker // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
