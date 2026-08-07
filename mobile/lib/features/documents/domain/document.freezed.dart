// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'document.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$MedicalDocument {

 String get id; String get hospital; String? get location;@JsonKey(name: 'doctor_name') String? get doctorName; String? get department; String? get description;/// When the visit happened — **for rows created since that field existed**.
/// Older rows carry the moment they were uploaded, because the server
/// stamped `utcnow()` and the web app's date input was discarded. Treated
/// as a plain date for exactly that reason: showing a time on it would
/// claim a precision the value does not have.
@JsonKey(name: 'checkup_date') String get checkupDate;
/// Create a copy of MedicalDocument
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MedicalDocumentCopyWith<MedicalDocument> get copyWith => _$MedicalDocumentCopyWithImpl<MedicalDocument>(this as MedicalDocument, _$identity);

  /// Serializes this MedicalDocument to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MedicalDocument&&(identical(other.id, id) || other.id == id)&&(identical(other.hospital, hospital) || other.hospital == hospital)&&(identical(other.location, location) || other.location == location)&&(identical(other.doctorName, doctorName) || other.doctorName == doctorName)&&(identical(other.department, department) || other.department == department)&&(identical(other.description, description) || other.description == description)&&(identical(other.checkupDate, checkupDate) || other.checkupDate == checkupDate));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,hospital,location,doctorName,department,description,checkupDate);

@override
String toString() {
  return 'MedicalDocument(id: $id, hospital: $hospital, location: $location, doctorName: $doctorName, department: $department, description: $description, checkupDate: $checkupDate)';
}


}

/// @nodoc
abstract mixin class $MedicalDocumentCopyWith<$Res>  {
  factory $MedicalDocumentCopyWith(MedicalDocument value, $Res Function(MedicalDocument) _then) = _$MedicalDocumentCopyWithImpl;
@useResult
$Res call({
 String id, String hospital, String? location,@JsonKey(name: 'doctor_name') String? doctorName, String? department, String? description,@JsonKey(name: 'checkup_date') String checkupDate
});




}
/// @nodoc
class _$MedicalDocumentCopyWithImpl<$Res>
    implements $MedicalDocumentCopyWith<$Res> {
  _$MedicalDocumentCopyWithImpl(this._self, this._then);

  final MedicalDocument _self;
  final $Res Function(MedicalDocument) _then;

/// Create a copy of MedicalDocument
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? hospital = null,Object? location = freezed,Object? doctorName = freezed,Object? department = freezed,Object? description = freezed,Object? checkupDate = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,hospital: null == hospital ? _self.hospital : hospital // ignore: cast_nullable_to_non_nullable
as String,location: freezed == location ? _self.location : location // ignore: cast_nullable_to_non_nullable
as String?,doctorName: freezed == doctorName ? _self.doctorName : doctorName // ignore: cast_nullable_to_non_nullable
as String?,department: freezed == department ? _self.department : department // ignore: cast_nullable_to_non_nullable
as String?,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,checkupDate: null == checkupDate ? _self.checkupDate : checkupDate // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [MedicalDocument].
extension MedicalDocumentPatterns on MedicalDocument {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MedicalDocument value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MedicalDocument() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MedicalDocument value)  $default,){
final _that = this;
switch (_that) {
case _MedicalDocument():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MedicalDocument value)?  $default,){
final _that = this;
switch (_that) {
case _MedicalDocument() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String hospital,  String? location, @JsonKey(name: 'doctor_name')  String? doctorName,  String? department,  String? description, @JsonKey(name: 'checkup_date')  String checkupDate)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MedicalDocument() when $default != null:
return $default(_that.id,_that.hospital,_that.location,_that.doctorName,_that.department,_that.description,_that.checkupDate);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String hospital,  String? location, @JsonKey(name: 'doctor_name')  String? doctorName,  String? department,  String? description, @JsonKey(name: 'checkup_date')  String checkupDate)  $default,) {final _that = this;
switch (_that) {
case _MedicalDocument():
return $default(_that.id,_that.hospital,_that.location,_that.doctorName,_that.department,_that.description,_that.checkupDate);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String hospital,  String? location, @JsonKey(name: 'doctor_name')  String? doctorName,  String? department,  String? description, @JsonKey(name: 'checkup_date')  String checkupDate)?  $default,) {final _that = this;
switch (_that) {
case _MedicalDocument() when $default != null:
return $default(_that.id,_that.hospital,_that.location,_that.doctorName,_that.department,_that.description,_that.checkupDate);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MedicalDocument extends MedicalDocument {
  const _MedicalDocument({required this.id, required this.hospital, this.location, @JsonKey(name: 'doctor_name') this.doctorName, this.department, this.description, @JsonKey(name: 'checkup_date') required this.checkupDate}): super._();
  factory _MedicalDocument.fromJson(Map<String, dynamic> json) => _$MedicalDocumentFromJson(json);

@override final  String id;
@override final  String hospital;
@override final  String? location;
@override@JsonKey(name: 'doctor_name') final  String? doctorName;
@override final  String? department;
@override final  String? description;
/// When the visit happened — **for rows created since that field existed**.
/// Older rows carry the moment they were uploaded, because the server
/// stamped `utcnow()` and the web app's date input was discarded. Treated
/// as a plain date for exactly that reason: showing a time on it would
/// claim a precision the value does not have.
@override@JsonKey(name: 'checkup_date') final  String checkupDate;

/// Create a copy of MedicalDocument
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MedicalDocumentCopyWith<_MedicalDocument> get copyWith => __$MedicalDocumentCopyWithImpl<_MedicalDocument>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MedicalDocumentToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MedicalDocument&&(identical(other.id, id) || other.id == id)&&(identical(other.hospital, hospital) || other.hospital == hospital)&&(identical(other.location, location) || other.location == location)&&(identical(other.doctorName, doctorName) || other.doctorName == doctorName)&&(identical(other.department, department) || other.department == department)&&(identical(other.description, description) || other.description == description)&&(identical(other.checkupDate, checkupDate) || other.checkupDate == checkupDate));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,hospital,location,doctorName,department,description,checkupDate);

@override
String toString() {
  return 'MedicalDocument(id: $id, hospital: $hospital, location: $location, doctorName: $doctorName, department: $department, description: $description, checkupDate: $checkupDate)';
}


}

/// @nodoc
abstract mixin class _$MedicalDocumentCopyWith<$Res> implements $MedicalDocumentCopyWith<$Res> {
  factory _$MedicalDocumentCopyWith(_MedicalDocument value, $Res Function(_MedicalDocument) _then) = __$MedicalDocumentCopyWithImpl;
@override @useResult
$Res call({
 String id, String hospital, String? location,@JsonKey(name: 'doctor_name') String? doctorName, String? department, String? description,@JsonKey(name: 'checkup_date') String checkupDate
});




}
/// @nodoc
class __$MedicalDocumentCopyWithImpl<$Res>
    implements _$MedicalDocumentCopyWith<$Res> {
  __$MedicalDocumentCopyWithImpl(this._self, this._then);

  final _MedicalDocument _self;
  final $Res Function(_MedicalDocument) _then;

/// Create a copy of MedicalDocument
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? hospital = null,Object? location = freezed,Object? doctorName = freezed,Object? department = freezed,Object? description = freezed,Object? checkupDate = null,}) {
  return _then(_MedicalDocument(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,hospital: null == hospital ? _self.hospital : hospital // ignore: cast_nullable_to_non_nullable
as String,location: freezed == location ? _self.location : location // ignore: cast_nullable_to_non_nullable
as String?,doctorName: freezed == doctorName ? _self.doctorName : doctorName // ignore: cast_nullable_to_non_nullable
as String?,department: freezed == department ? _self.department : department // ignore: cast_nullable_to_non_nullable
as String?,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,checkupDate: null == checkupDate ? _self.checkupDate : checkupDate // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$DocumentFile {

 String get id; String get name;@JsonKey(name: 'file_type') String get fileType;
/// Create a copy of DocumentFile
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DocumentFileCopyWith<DocumentFile> get copyWith => _$DocumentFileCopyWithImpl<DocumentFile>(this as DocumentFile, _$identity);

  /// Serializes this DocumentFile to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DocumentFile&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.fileType, fileType) || other.fileType == fileType));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,fileType);

@override
String toString() {
  return 'DocumentFile(id: $id, name: $name, fileType: $fileType)';
}


}

/// @nodoc
abstract mixin class $DocumentFileCopyWith<$Res>  {
  factory $DocumentFileCopyWith(DocumentFile value, $Res Function(DocumentFile) _then) = _$DocumentFileCopyWithImpl;
@useResult
$Res call({
 String id, String name,@JsonKey(name: 'file_type') String fileType
});




}
/// @nodoc
class _$DocumentFileCopyWithImpl<$Res>
    implements $DocumentFileCopyWith<$Res> {
  _$DocumentFileCopyWithImpl(this._self, this._then);

  final DocumentFile _self;
  final $Res Function(DocumentFile) _then;

/// Create a copy of DocumentFile
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? fileType = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,fileType: null == fileType ? _self.fileType : fileType // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [DocumentFile].
extension DocumentFilePatterns on DocumentFile {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DocumentFile value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DocumentFile() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DocumentFile value)  $default,){
final _that = this;
switch (_that) {
case _DocumentFile():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DocumentFile value)?  $default,){
final _that = this;
switch (_that) {
case _DocumentFile() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name, @JsonKey(name: 'file_type')  String fileType)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DocumentFile() when $default != null:
return $default(_that.id,_that.name,_that.fileType);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name, @JsonKey(name: 'file_type')  String fileType)  $default,) {final _that = this;
switch (_that) {
case _DocumentFile():
return $default(_that.id,_that.name,_that.fileType);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name, @JsonKey(name: 'file_type')  String fileType)?  $default,) {final _that = this;
switch (_that) {
case _DocumentFile() when $default != null:
return $default(_that.id,_that.name,_that.fileType);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _DocumentFile implements DocumentFile {
  const _DocumentFile({required this.id, required this.name, @JsonKey(name: 'file_type') required this.fileType});
  factory _DocumentFile.fromJson(Map<String, dynamic> json) => _$DocumentFileFromJson(json);

@override final  String id;
@override final  String name;
@override@JsonKey(name: 'file_type') final  String fileType;

/// Create a copy of DocumentFile
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DocumentFileCopyWith<_DocumentFile> get copyWith => __$DocumentFileCopyWithImpl<_DocumentFile>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DocumentFileToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DocumentFile&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.fileType, fileType) || other.fileType == fileType));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,fileType);

@override
String toString() {
  return 'DocumentFile(id: $id, name: $name, fileType: $fileType)';
}


}

/// @nodoc
abstract mixin class _$DocumentFileCopyWith<$Res> implements $DocumentFileCopyWith<$Res> {
  factory _$DocumentFileCopyWith(_DocumentFile value, $Res Function(_DocumentFile) _then) = __$DocumentFileCopyWithImpl;
@override @useResult
$Res call({
 String id, String name,@JsonKey(name: 'file_type') String fileType
});




}
/// @nodoc
class __$DocumentFileCopyWithImpl<$Res>
    implements _$DocumentFileCopyWith<$Res> {
  __$DocumentFileCopyWithImpl(this._self, this._then);

  final _DocumentFile _self;
  final $Res Function(_DocumentFile) _then;

/// Create a copy of DocumentFile
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? fileType = null,}) {
  return _then(_DocumentFile(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,fileType: null == fileType ? _self.fileType : fileType // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
