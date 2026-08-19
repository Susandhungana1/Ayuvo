// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'report.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$MedicalReport {

 String get id;@JsonKey(name: 'report_type') String get reportType;/// Date-only in meaning, datetime in transport. Never shift it.
@JsonKey(name: 'report_date') String? get reportDate;@JsonKey(name: 'file_name') String get fileName; String? get notes;/// The OCR output. **Every list response carries this in full** for every
/// report — see `BACKEND_NOTES.md` §3.
@JsonKey(name: 'extracted_text') String? get extractedText;/// `PENDING` while the server's background OCR runs after an upload;
/// `DONE`/`FAILED` once it has. The detail screen uses it to wait for
/// lab values instead of showing "none found".
@JsonKey(name: 'ocr_status') String? get ocrStatus;@JsonKey(name: 'document_id') String? get documentId;/// Falls back to the linked document's values when unset server-side.
@JsonKey(name: 'doctor_name') String? get doctorName; String? get hospital;
/// Create a copy of MedicalReport
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MedicalReportCopyWith<MedicalReport> get copyWith => _$MedicalReportCopyWithImpl<MedicalReport>(this as MedicalReport, _$identity);

  /// Serializes this MedicalReport to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MedicalReport&&(identical(other.id, id) || other.id == id)&&(identical(other.reportType, reportType) || other.reportType == reportType)&&(identical(other.reportDate, reportDate) || other.reportDate == reportDate)&&(identical(other.fileName, fileName) || other.fileName == fileName)&&(identical(other.notes, notes) || other.notes == notes)&&(identical(other.extractedText, extractedText) || other.extractedText == extractedText)&&(identical(other.ocrStatus, ocrStatus) || other.ocrStatus == ocrStatus)&&(identical(other.documentId, documentId) || other.documentId == documentId)&&(identical(other.doctorName, doctorName) || other.doctorName == doctorName)&&(identical(other.hospital, hospital) || other.hospital == hospital));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,reportType,reportDate,fileName,notes,extractedText,ocrStatus,documentId,doctorName,hospital);

@override
String toString() {
  return 'MedicalReport(id: $id, reportType: $reportType, reportDate: $reportDate, fileName: $fileName, notes: $notes, extractedText: $extractedText, ocrStatus: $ocrStatus, documentId: $documentId, doctorName: $doctorName, hospital: $hospital)';
}


}

/// @nodoc
abstract mixin class $MedicalReportCopyWith<$Res>  {
  factory $MedicalReportCopyWith(MedicalReport value, $Res Function(MedicalReport) _then) = _$MedicalReportCopyWithImpl;
@useResult
$Res call({
 String id,@JsonKey(name: 'report_type') String reportType,@JsonKey(name: 'report_date') String? reportDate,@JsonKey(name: 'file_name') String fileName, String? notes,@JsonKey(name: 'extracted_text') String? extractedText,@JsonKey(name: 'ocr_status') String? ocrStatus,@JsonKey(name: 'document_id') String? documentId,@JsonKey(name: 'doctor_name') String? doctorName, String? hospital
});




}
/// @nodoc
class _$MedicalReportCopyWithImpl<$Res>
    implements $MedicalReportCopyWith<$Res> {
  _$MedicalReportCopyWithImpl(this._self, this._then);

  final MedicalReport _self;
  final $Res Function(MedicalReport) _then;

/// Create a copy of MedicalReport
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? reportType = null,Object? reportDate = freezed,Object? fileName = null,Object? notes = freezed,Object? extractedText = freezed,Object? ocrStatus = freezed,Object? documentId = freezed,Object? doctorName = freezed,Object? hospital = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,reportType: null == reportType ? _self.reportType : reportType // ignore: cast_nullable_to_non_nullable
as String,reportDate: freezed == reportDate ? _self.reportDate : reportDate // ignore: cast_nullable_to_non_nullable
as String?,fileName: null == fileName ? _self.fileName : fileName // ignore: cast_nullable_to_non_nullable
as String,notes: freezed == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String?,extractedText: freezed == extractedText ? _self.extractedText : extractedText // ignore: cast_nullable_to_non_nullable
as String?,ocrStatus: freezed == ocrStatus ? _self.ocrStatus : ocrStatus // ignore: cast_nullable_to_non_nullable
as String?,documentId: freezed == documentId ? _self.documentId : documentId // ignore: cast_nullable_to_non_nullable
as String?,doctorName: freezed == doctorName ? _self.doctorName : doctorName // ignore: cast_nullable_to_non_nullable
as String?,hospital: freezed == hospital ? _self.hospital : hospital // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [MedicalReport].
extension MedicalReportPatterns on MedicalReport {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MedicalReport value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MedicalReport() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MedicalReport value)  $default,){
final _that = this;
switch (_that) {
case _MedicalReport():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MedicalReport value)?  $default,){
final _that = this;
switch (_that) {
case _MedicalReport() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'report_type')  String reportType, @JsonKey(name: 'report_date')  String? reportDate, @JsonKey(name: 'file_name')  String fileName,  String? notes, @JsonKey(name: 'extracted_text')  String? extractedText, @JsonKey(name: 'ocr_status')  String? ocrStatus, @JsonKey(name: 'document_id')  String? documentId, @JsonKey(name: 'doctor_name')  String? doctorName,  String? hospital)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MedicalReport() when $default != null:
return $default(_that.id,_that.reportType,_that.reportDate,_that.fileName,_that.notes,_that.extractedText,_that.ocrStatus,_that.documentId,_that.doctorName,_that.hospital);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'report_type')  String reportType, @JsonKey(name: 'report_date')  String? reportDate, @JsonKey(name: 'file_name')  String fileName,  String? notes, @JsonKey(name: 'extracted_text')  String? extractedText, @JsonKey(name: 'ocr_status')  String? ocrStatus, @JsonKey(name: 'document_id')  String? documentId, @JsonKey(name: 'doctor_name')  String? doctorName,  String? hospital)  $default,) {final _that = this;
switch (_that) {
case _MedicalReport():
return $default(_that.id,_that.reportType,_that.reportDate,_that.fileName,_that.notes,_that.extractedText,_that.ocrStatus,_that.documentId,_that.doctorName,_that.hospital);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id, @JsonKey(name: 'report_type')  String reportType, @JsonKey(name: 'report_date')  String? reportDate, @JsonKey(name: 'file_name')  String fileName,  String? notes, @JsonKey(name: 'extracted_text')  String? extractedText, @JsonKey(name: 'ocr_status')  String? ocrStatus, @JsonKey(name: 'document_id')  String? documentId, @JsonKey(name: 'doctor_name')  String? doctorName,  String? hospital)?  $default,) {final _that = this;
switch (_that) {
case _MedicalReport() when $default != null:
return $default(_that.id,_that.reportType,_that.reportDate,_that.fileName,_that.notes,_that.extractedText,_that.ocrStatus,_that.documentId,_that.doctorName,_that.hospital);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MedicalReport extends MedicalReport {
  const _MedicalReport({required this.id, @JsonKey(name: 'report_type') required this.reportType, @JsonKey(name: 'report_date') this.reportDate, @JsonKey(name: 'file_name') required this.fileName, this.notes, @JsonKey(name: 'extracted_text') this.extractedText, @JsonKey(name: 'ocr_status') this.ocrStatus, @JsonKey(name: 'document_id') this.documentId, @JsonKey(name: 'doctor_name') this.doctorName, this.hospital}): super._();
  factory _MedicalReport.fromJson(Map<String, dynamic> json) => _$MedicalReportFromJson(json);

@override final  String id;
@override@JsonKey(name: 'report_type') final  String reportType;
/// Date-only in meaning, datetime in transport. Never shift it.
@override@JsonKey(name: 'report_date') final  String? reportDate;
@override@JsonKey(name: 'file_name') final  String fileName;
@override final  String? notes;
/// The OCR output. **Every list response carries this in full** for every
/// report — see `BACKEND_NOTES.md` §3.
@override@JsonKey(name: 'extracted_text') final  String? extractedText;
/// `PENDING` while the server's background OCR runs after an upload;
/// `DONE`/`FAILED` once it has. The detail screen uses it to wait for
/// lab values instead of showing "none found".
@override@JsonKey(name: 'ocr_status') final  String? ocrStatus;
@override@JsonKey(name: 'document_id') final  String? documentId;
/// Falls back to the linked document's values when unset server-side.
@override@JsonKey(name: 'doctor_name') final  String? doctorName;
@override final  String? hospital;

/// Create a copy of MedicalReport
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MedicalReportCopyWith<_MedicalReport> get copyWith => __$MedicalReportCopyWithImpl<_MedicalReport>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MedicalReportToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MedicalReport&&(identical(other.id, id) || other.id == id)&&(identical(other.reportType, reportType) || other.reportType == reportType)&&(identical(other.reportDate, reportDate) || other.reportDate == reportDate)&&(identical(other.fileName, fileName) || other.fileName == fileName)&&(identical(other.notes, notes) || other.notes == notes)&&(identical(other.extractedText, extractedText) || other.extractedText == extractedText)&&(identical(other.ocrStatus, ocrStatus) || other.ocrStatus == ocrStatus)&&(identical(other.documentId, documentId) || other.documentId == documentId)&&(identical(other.doctorName, doctorName) || other.doctorName == doctorName)&&(identical(other.hospital, hospital) || other.hospital == hospital));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,reportType,reportDate,fileName,notes,extractedText,ocrStatus,documentId,doctorName,hospital);

@override
String toString() {
  return 'MedicalReport(id: $id, reportType: $reportType, reportDate: $reportDate, fileName: $fileName, notes: $notes, extractedText: $extractedText, ocrStatus: $ocrStatus, documentId: $documentId, doctorName: $doctorName, hospital: $hospital)';
}


}

/// @nodoc
abstract mixin class _$MedicalReportCopyWith<$Res> implements $MedicalReportCopyWith<$Res> {
  factory _$MedicalReportCopyWith(_MedicalReport value, $Res Function(_MedicalReport) _then) = __$MedicalReportCopyWithImpl;
@override @useResult
$Res call({
 String id,@JsonKey(name: 'report_type') String reportType,@JsonKey(name: 'report_date') String? reportDate,@JsonKey(name: 'file_name') String fileName, String? notes,@JsonKey(name: 'extracted_text') String? extractedText,@JsonKey(name: 'ocr_status') String? ocrStatus,@JsonKey(name: 'document_id') String? documentId,@JsonKey(name: 'doctor_name') String? doctorName, String? hospital
});




}
/// @nodoc
class __$MedicalReportCopyWithImpl<$Res>
    implements _$MedicalReportCopyWith<$Res> {
  __$MedicalReportCopyWithImpl(this._self, this._then);

  final _MedicalReport _self;
  final $Res Function(_MedicalReport) _then;

/// Create a copy of MedicalReport
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? reportType = null,Object? reportDate = freezed,Object? fileName = null,Object? notes = freezed,Object? extractedText = freezed,Object? ocrStatus = freezed,Object? documentId = freezed,Object? doctorName = freezed,Object? hospital = freezed,}) {
  return _then(_MedicalReport(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,reportType: null == reportType ? _self.reportType : reportType // ignore: cast_nullable_to_non_nullable
as String,reportDate: freezed == reportDate ? _self.reportDate : reportDate // ignore: cast_nullable_to_non_nullable
as String?,fileName: null == fileName ? _self.fileName : fileName // ignore: cast_nullable_to_non_nullable
as String,notes: freezed == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String?,extractedText: freezed == extractedText ? _self.extractedText : extractedText // ignore: cast_nullable_to_non_nullable
as String?,ocrStatus: freezed == ocrStatus ? _self.ocrStatus : ocrStatus // ignore: cast_nullable_to_non_nullable
as String?,documentId: freezed == documentId ? _self.documentId : documentId // ignore: cast_nullable_to_non_nullable
as String?,doctorName: freezed == doctorName ? _self.doctorName : doctorName // ignore: cast_nullable_to_non_nullable
as String?,hospital: freezed == hospital ? _self.hospital : hospital // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$LabFinding {

 String get name; double get value; String get unit;/// `HIGH` · `LOW` · `NORMAL`.
 String get status;@JsonKey(name: 'reference_range') String get referenceRange;/// Blood Count · Metabolic · Lipids · Kidney · Electrolytes · Liver ·
/// Thyroid · Vitamins.
 String get category;
/// Create a copy of LabFinding
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LabFindingCopyWith<LabFinding> get copyWith => _$LabFindingCopyWithImpl<LabFinding>(this as LabFinding, _$identity);

  /// Serializes this LabFinding to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LabFinding&&(identical(other.name, name) || other.name == name)&&(identical(other.value, value) || other.value == value)&&(identical(other.unit, unit) || other.unit == unit)&&(identical(other.status, status) || other.status == status)&&(identical(other.referenceRange, referenceRange) || other.referenceRange == referenceRange)&&(identical(other.category, category) || other.category == category));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,value,unit,status,referenceRange,category);

@override
String toString() {
  return 'LabFinding(name: $name, value: $value, unit: $unit, status: $status, referenceRange: $referenceRange, category: $category)';
}


}

/// @nodoc
abstract mixin class $LabFindingCopyWith<$Res>  {
  factory $LabFindingCopyWith(LabFinding value, $Res Function(LabFinding) _then) = _$LabFindingCopyWithImpl;
@useResult
$Res call({
 String name, double value, String unit, String status,@JsonKey(name: 'reference_range') String referenceRange, String category
});




}
/// @nodoc
class _$LabFindingCopyWithImpl<$Res>
    implements $LabFindingCopyWith<$Res> {
  _$LabFindingCopyWithImpl(this._self, this._then);

  final LabFinding _self;
  final $Res Function(LabFinding) _then;

/// Create a copy of LabFinding
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? value = null,Object? unit = null,Object? status = null,Object? referenceRange = null,Object? category = null,}) {
  return _then(_self.copyWith(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,value: null == value ? _self.value : value // ignore: cast_nullable_to_non_nullable
as double,unit: null == unit ? _self.unit : unit // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,referenceRange: null == referenceRange ? _self.referenceRange : referenceRange // ignore: cast_nullable_to_non_nullable
as String,category: null == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [LabFinding].
extension LabFindingPatterns on LabFinding {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LabFinding value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LabFinding() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LabFinding value)  $default,){
final _that = this;
switch (_that) {
case _LabFinding():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LabFinding value)?  $default,){
final _that = this;
switch (_that) {
case _LabFinding() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  double value,  String unit,  String status, @JsonKey(name: 'reference_range')  String referenceRange,  String category)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LabFinding() when $default != null:
return $default(_that.name,_that.value,_that.unit,_that.status,_that.referenceRange,_that.category);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  double value,  String unit,  String status, @JsonKey(name: 'reference_range')  String referenceRange,  String category)  $default,) {final _that = this;
switch (_that) {
case _LabFinding():
return $default(_that.name,_that.value,_that.unit,_that.status,_that.referenceRange,_that.category);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  double value,  String unit,  String status, @JsonKey(name: 'reference_range')  String referenceRange,  String category)?  $default,) {final _that = this;
switch (_that) {
case _LabFinding() when $default != null:
return $default(_that.name,_that.value,_that.unit,_that.status,_that.referenceRange,_that.category);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LabFinding extends LabFinding {
  const _LabFinding({required this.name, required this.value, required this.unit, required this.status, @JsonKey(name: 'reference_range') required this.referenceRange, required this.category}): super._();
  factory _LabFinding.fromJson(Map<String, dynamic> json) => _$LabFindingFromJson(json);

@override final  String name;
@override final  double value;
@override final  String unit;
/// `HIGH` · `LOW` · `NORMAL`.
@override final  String status;
@override@JsonKey(name: 'reference_range') final  String referenceRange;
/// Blood Count · Metabolic · Lipids · Kidney · Electrolytes · Liver ·
/// Thyroid · Vitamins.
@override final  String category;

/// Create a copy of LabFinding
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LabFindingCopyWith<_LabFinding> get copyWith => __$LabFindingCopyWithImpl<_LabFinding>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LabFindingToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LabFinding&&(identical(other.name, name) || other.name == name)&&(identical(other.value, value) || other.value == value)&&(identical(other.unit, unit) || other.unit == unit)&&(identical(other.status, status) || other.status == status)&&(identical(other.referenceRange, referenceRange) || other.referenceRange == referenceRange)&&(identical(other.category, category) || other.category == category));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,value,unit,status,referenceRange,category);

@override
String toString() {
  return 'LabFinding(name: $name, value: $value, unit: $unit, status: $status, referenceRange: $referenceRange, category: $category)';
}


}

/// @nodoc
abstract mixin class _$LabFindingCopyWith<$Res> implements $LabFindingCopyWith<$Res> {
  factory _$LabFindingCopyWith(_LabFinding value, $Res Function(_LabFinding) _then) = __$LabFindingCopyWithImpl;
@override @useResult
$Res call({
 String name, double value, String unit, String status,@JsonKey(name: 'reference_range') String referenceRange, String category
});




}
/// @nodoc
class __$LabFindingCopyWithImpl<$Res>
    implements _$LabFindingCopyWith<$Res> {
  __$LabFindingCopyWithImpl(this._self, this._then);

  final _LabFinding _self;
  final $Res Function(_LabFinding) _then;

/// Create a copy of LabFinding
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? value = null,Object? unit = null,Object? status = null,Object? referenceRange = null,Object? category = null,}) {
  return _then(_LabFinding(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,value: null == value ? _self.value : value // ignore: cast_nullable_to_non_nullable
as double,unit: null == unit ? _self.unit : unit // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,referenceRange: null == referenceRange ? _self.referenceRange : referenceRange // ignore: cast_nullable_to_non_nullable
as String,category: null == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$LabAnalysis {

/// `NORMAL` · `ABNORMAL` · `NO_DATA`.
 String get overall; int get total;@JsonKey(name: 'abnormal_count') int get abnormalCount; List<LabFinding> get findings;
/// Create a copy of LabAnalysis
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LabAnalysisCopyWith<LabAnalysis> get copyWith => _$LabAnalysisCopyWithImpl<LabAnalysis>(this as LabAnalysis, _$identity);

  /// Serializes this LabAnalysis to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LabAnalysis&&(identical(other.overall, overall) || other.overall == overall)&&(identical(other.total, total) || other.total == total)&&(identical(other.abnormalCount, abnormalCount) || other.abnormalCount == abnormalCount)&&const DeepCollectionEquality().equals(other.findings, findings));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,overall,total,abnormalCount,const DeepCollectionEquality().hash(findings));

@override
String toString() {
  return 'LabAnalysis(overall: $overall, total: $total, abnormalCount: $abnormalCount, findings: $findings)';
}


}

/// @nodoc
abstract mixin class $LabAnalysisCopyWith<$Res>  {
  factory $LabAnalysisCopyWith(LabAnalysis value, $Res Function(LabAnalysis) _then) = _$LabAnalysisCopyWithImpl;
@useResult
$Res call({
 String overall, int total,@JsonKey(name: 'abnormal_count') int abnormalCount, List<LabFinding> findings
});




}
/// @nodoc
class _$LabAnalysisCopyWithImpl<$Res>
    implements $LabAnalysisCopyWith<$Res> {
  _$LabAnalysisCopyWithImpl(this._self, this._then);

  final LabAnalysis _self;
  final $Res Function(LabAnalysis) _then;

/// Create a copy of LabAnalysis
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? overall = null,Object? total = null,Object? abnormalCount = null,Object? findings = null,}) {
  return _then(_self.copyWith(
overall: null == overall ? _self.overall : overall // ignore: cast_nullable_to_non_nullable
as String,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int,abnormalCount: null == abnormalCount ? _self.abnormalCount : abnormalCount // ignore: cast_nullable_to_non_nullable
as int,findings: null == findings ? _self.findings : findings // ignore: cast_nullable_to_non_nullable
as List<LabFinding>,
  ));
}

}


/// Adds pattern-matching-related methods to [LabAnalysis].
extension LabAnalysisPatterns on LabAnalysis {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LabAnalysis value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LabAnalysis() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LabAnalysis value)  $default,){
final _that = this;
switch (_that) {
case _LabAnalysis():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LabAnalysis value)?  $default,){
final _that = this;
switch (_that) {
case _LabAnalysis() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String overall,  int total, @JsonKey(name: 'abnormal_count')  int abnormalCount,  List<LabFinding> findings)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LabAnalysis() when $default != null:
return $default(_that.overall,_that.total,_that.abnormalCount,_that.findings);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String overall,  int total, @JsonKey(name: 'abnormal_count')  int abnormalCount,  List<LabFinding> findings)  $default,) {final _that = this;
switch (_that) {
case _LabAnalysis():
return $default(_that.overall,_that.total,_that.abnormalCount,_that.findings);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String overall,  int total, @JsonKey(name: 'abnormal_count')  int abnormalCount,  List<LabFinding> findings)?  $default,) {final _that = this;
switch (_that) {
case _LabAnalysis() when $default != null:
return $default(_that.overall,_that.total,_that.abnormalCount,_that.findings);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LabAnalysis extends LabAnalysis {
  const _LabAnalysis({required this.overall, required this.total, @JsonKey(name: 'abnormal_count') required this.abnormalCount, required final  List<LabFinding> findings}): _findings = findings,super._();
  factory _LabAnalysis.fromJson(Map<String, dynamic> json) => _$LabAnalysisFromJson(json);

/// `NORMAL` · `ABNORMAL` · `NO_DATA`.
@override final  String overall;
@override final  int total;
@override@JsonKey(name: 'abnormal_count') final  int abnormalCount;
 final  List<LabFinding> _findings;
@override List<LabFinding> get findings {
  if (_findings is EqualUnmodifiableListView) return _findings;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_findings);
}


/// Create a copy of LabAnalysis
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LabAnalysisCopyWith<_LabAnalysis> get copyWith => __$LabAnalysisCopyWithImpl<_LabAnalysis>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LabAnalysisToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LabAnalysis&&(identical(other.overall, overall) || other.overall == overall)&&(identical(other.total, total) || other.total == total)&&(identical(other.abnormalCount, abnormalCount) || other.abnormalCount == abnormalCount)&&const DeepCollectionEquality().equals(other._findings, _findings));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,overall,total,abnormalCount,const DeepCollectionEquality().hash(_findings));

@override
String toString() {
  return 'LabAnalysis(overall: $overall, total: $total, abnormalCount: $abnormalCount, findings: $findings)';
}


}

/// @nodoc
abstract mixin class _$LabAnalysisCopyWith<$Res> implements $LabAnalysisCopyWith<$Res> {
  factory _$LabAnalysisCopyWith(_LabAnalysis value, $Res Function(_LabAnalysis) _then) = __$LabAnalysisCopyWithImpl;
@override @useResult
$Res call({
 String overall, int total,@JsonKey(name: 'abnormal_count') int abnormalCount, List<LabFinding> findings
});




}
/// @nodoc
class __$LabAnalysisCopyWithImpl<$Res>
    implements _$LabAnalysisCopyWith<$Res> {
  __$LabAnalysisCopyWithImpl(this._self, this._then);

  final _LabAnalysis _self;
  final $Res Function(_LabAnalysis) _then;

/// Create a copy of LabAnalysis
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? overall = null,Object? total = null,Object? abnormalCount = null,Object? findings = null,}) {
  return _then(_LabAnalysis(
overall: null == overall ? _self.overall : overall // ignore: cast_nullable_to_non_nullable
as String,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int,abnormalCount: null == abnormalCount ? _self.abnormalCount : abnormalCount // ignore: cast_nullable_to_non_nullable
as int,findings: null == findings ? _self._findings : findings // ignore: cast_nullable_to_non_nullable
as List<LabFinding>,
  ));
}


}


/// @nodoc
mixin _$TrendPoint {

 String get date; double get value; String? get status;
/// Create a copy of TrendPoint
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TrendPointCopyWith<TrendPoint> get copyWith => _$TrendPointCopyWithImpl<TrendPoint>(this as TrendPoint, _$identity);

  /// Serializes this TrendPoint to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TrendPoint&&(identical(other.date, date) || other.date == date)&&(identical(other.value, value) || other.value == value)&&(identical(other.status, status) || other.status == status));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,date,value,status);

@override
String toString() {
  return 'TrendPoint(date: $date, value: $value, status: $status)';
}


}

/// @nodoc
abstract mixin class $TrendPointCopyWith<$Res>  {
  factory $TrendPointCopyWith(TrendPoint value, $Res Function(TrendPoint) _then) = _$TrendPointCopyWithImpl;
@useResult
$Res call({
 String date, double value, String? status
});




}
/// @nodoc
class _$TrendPointCopyWithImpl<$Res>
    implements $TrendPointCopyWith<$Res> {
  _$TrendPointCopyWithImpl(this._self, this._then);

  final TrendPoint _self;
  final $Res Function(TrendPoint) _then;

/// Create a copy of TrendPoint
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? date = null,Object? value = null,Object? status = freezed,}) {
  return _then(_self.copyWith(
date: null == date ? _self.date : date // ignore: cast_nullable_to_non_nullable
as String,value: null == value ? _self.value : value // ignore: cast_nullable_to_non_nullable
as double,status: freezed == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [TrendPoint].
extension TrendPointPatterns on TrendPoint {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TrendPoint value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TrendPoint() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TrendPoint value)  $default,){
final _that = this;
switch (_that) {
case _TrendPoint():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TrendPoint value)?  $default,){
final _that = this;
switch (_that) {
case _TrendPoint() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String date,  double value,  String? status)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TrendPoint() when $default != null:
return $default(_that.date,_that.value,_that.status);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String date,  double value,  String? status)  $default,) {final _that = this;
switch (_that) {
case _TrendPoint():
return $default(_that.date,_that.value,_that.status);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String date,  double value,  String? status)?  $default,) {final _that = this;
switch (_that) {
case _TrendPoint() when $default != null:
return $default(_that.date,_that.value,_that.status);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TrendPoint extends TrendPoint {
  const _TrendPoint({required this.date, required this.value, this.status}): super._();
  factory _TrendPoint.fromJson(Map<String, dynamic> json) => _$TrendPointFromJson(json);

@override final  String date;
@override final  double value;
@override final  String? status;

/// Create a copy of TrendPoint
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TrendPointCopyWith<_TrendPoint> get copyWith => __$TrendPointCopyWithImpl<_TrendPoint>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TrendPointToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TrendPoint&&(identical(other.date, date) || other.date == date)&&(identical(other.value, value) || other.value == value)&&(identical(other.status, status) || other.status == status));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,date,value,status);

@override
String toString() {
  return 'TrendPoint(date: $date, value: $value, status: $status)';
}


}

/// @nodoc
abstract mixin class _$TrendPointCopyWith<$Res> implements $TrendPointCopyWith<$Res> {
  factory _$TrendPointCopyWith(_TrendPoint value, $Res Function(_TrendPoint) _then) = __$TrendPointCopyWithImpl;
@override @useResult
$Res call({
 String date, double value, String? status
});




}
/// @nodoc
class __$TrendPointCopyWithImpl<$Res>
    implements _$TrendPointCopyWith<$Res> {
  __$TrendPointCopyWithImpl(this._self, this._then);

  final _TrendPoint _self;
  final $Res Function(_TrendPoint) _then;

/// Create a copy of TrendPoint
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? date = null,Object? value = null,Object? status = freezed,}) {
  return _then(_TrendPoint(
date: null == date ? _self.date : date // ignore: cast_nullable_to_non_nullable
as String,value: null == value ? _self.value : value // ignore: cast_nullable_to_non_nullable
as double,status: freezed == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$TrendSeries {

 String get name; String get unit;@JsonKey(name: 'reference_range') String get referenceRange; List<TrendPoint> get points;@JsonKey(name: 'first_value') double get firstValue;@JsonKey(name: 'last_value') double get lastValue; double get change;@JsonKey(name: 'percent_change') double? get percentChange;/// `up` · `down` · `flat`.
 String get direction;/// `HIGH` · `LOW` · `NORMAL`.
@JsonKey(name: 'latest_status') String get latestStatus;
/// Create a copy of TrendSeries
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TrendSeriesCopyWith<TrendSeries> get copyWith => _$TrendSeriesCopyWithImpl<TrendSeries>(this as TrendSeries, _$identity);

  /// Serializes this TrendSeries to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TrendSeries&&(identical(other.name, name) || other.name == name)&&(identical(other.unit, unit) || other.unit == unit)&&(identical(other.referenceRange, referenceRange) || other.referenceRange == referenceRange)&&const DeepCollectionEquality().equals(other.points, points)&&(identical(other.firstValue, firstValue) || other.firstValue == firstValue)&&(identical(other.lastValue, lastValue) || other.lastValue == lastValue)&&(identical(other.change, change) || other.change == change)&&(identical(other.percentChange, percentChange) || other.percentChange == percentChange)&&(identical(other.direction, direction) || other.direction == direction)&&(identical(other.latestStatus, latestStatus) || other.latestStatus == latestStatus));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,unit,referenceRange,const DeepCollectionEquality().hash(points),firstValue,lastValue,change,percentChange,direction,latestStatus);

@override
String toString() {
  return 'TrendSeries(name: $name, unit: $unit, referenceRange: $referenceRange, points: $points, firstValue: $firstValue, lastValue: $lastValue, change: $change, percentChange: $percentChange, direction: $direction, latestStatus: $latestStatus)';
}


}

/// @nodoc
abstract mixin class $TrendSeriesCopyWith<$Res>  {
  factory $TrendSeriesCopyWith(TrendSeries value, $Res Function(TrendSeries) _then) = _$TrendSeriesCopyWithImpl;
@useResult
$Res call({
 String name, String unit,@JsonKey(name: 'reference_range') String referenceRange, List<TrendPoint> points,@JsonKey(name: 'first_value') double firstValue,@JsonKey(name: 'last_value') double lastValue, double change,@JsonKey(name: 'percent_change') double? percentChange, String direction,@JsonKey(name: 'latest_status') String latestStatus
});




}
/// @nodoc
class _$TrendSeriesCopyWithImpl<$Res>
    implements $TrendSeriesCopyWith<$Res> {
  _$TrendSeriesCopyWithImpl(this._self, this._then);

  final TrendSeries _self;
  final $Res Function(TrendSeries) _then;

/// Create a copy of TrendSeries
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? unit = null,Object? referenceRange = null,Object? points = null,Object? firstValue = null,Object? lastValue = null,Object? change = null,Object? percentChange = freezed,Object? direction = null,Object? latestStatus = null,}) {
  return _then(_self.copyWith(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,unit: null == unit ? _self.unit : unit // ignore: cast_nullable_to_non_nullable
as String,referenceRange: null == referenceRange ? _self.referenceRange : referenceRange // ignore: cast_nullable_to_non_nullable
as String,points: null == points ? _self.points : points // ignore: cast_nullable_to_non_nullable
as List<TrendPoint>,firstValue: null == firstValue ? _self.firstValue : firstValue // ignore: cast_nullable_to_non_nullable
as double,lastValue: null == lastValue ? _self.lastValue : lastValue // ignore: cast_nullable_to_non_nullable
as double,change: null == change ? _self.change : change // ignore: cast_nullable_to_non_nullable
as double,percentChange: freezed == percentChange ? _self.percentChange : percentChange // ignore: cast_nullable_to_non_nullable
as double?,direction: null == direction ? _self.direction : direction // ignore: cast_nullable_to_non_nullable
as String,latestStatus: null == latestStatus ? _self.latestStatus : latestStatus // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [TrendSeries].
extension TrendSeriesPatterns on TrendSeries {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TrendSeries value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TrendSeries() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TrendSeries value)  $default,){
final _that = this;
switch (_that) {
case _TrendSeries():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TrendSeries value)?  $default,){
final _that = this;
switch (_that) {
case _TrendSeries() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  String unit, @JsonKey(name: 'reference_range')  String referenceRange,  List<TrendPoint> points, @JsonKey(name: 'first_value')  double firstValue, @JsonKey(name: 'last_value')  double lastValue,  double change, @JsonKey(name: 'percent_change')  double? percentChange,  String direction, @JsonKey(name: 'latest_status')  String latestStatus)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TrendSeries() when $default != null:
return $default(_that.name,_that.unit,_that.referenceRange,_that.points,_that.firstValue,_that.lastValue,_that.change,_that.percentChange,_that.direction,_that.latestStatus);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  String unit, @JsonKey(name: 'reference_range')  String referenceRange,  List<TrendPoint> points, @JsonKey(name: 'first_value')  double firstValue, @JsonKey(name: 'last_value')  double lastValue,  double change, @JsonKey(name: 'percent_change')  double? percentChange,  String direction, @JsonKey(name: 'latest_status')  String latestStatus)  $default,) {final _that = this;
switch (_that) {
case _TrendSeries():
return $default(_that.name,_that.unit,_that.referenceRange,_that.points,_that.firstValue,_that.lastValue,_that.change,_that.percentChange,_that.direction,_that.latestStatus);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  String unit, @JsonKey(name: 'reference_range')  String referenceRange,  List<TrendPoint> points, @JsonKey(name: 'first_value')  double firstValue, @JsonKey(name: 'last_value')  double lastValue,  double change, @JsonKey(name: 'percent_change')  double? percentChange,  String direction, @JsonKey(name: 'latest_status')  String latestStatus)?  $default,) {final _that = this;
switch (_that) {
case _TrendSeries() when $default != null:
return $default(_that.name,_that.unit,_that.referenceRange,_that.points,_that.firstValue,_that.lastValue,_that.change,_that.percentChange,_that.direction,_that.latestStatus);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TrendSeries extends TrendSeries {
  const _TrendSeries({required this.name, required this.unit, @JsonKey(name: 'reference_range') required this.referenceRange, required final  List<TrendPoint> points, @JsonKey(name: 'first_value') required this.firstValue, @JsonKey(name: 'last_value') required this.lastValue, required this.change, @JsonKey(name: 'percent_change') this.percentChange, required this.direction, @JsonKey(name: 'latest_status') required this.latestStatus}): _points = points,super._();
  factory _TrendSeries.fromJson(Map<String, dynamic> json) => _$TrendSeriesFromJson(json);

@override final  String name;
@override final  String unit;
@override@JsonKey(name: 'reference_range') final  String referenceRange;
 final  List<TrendPoint> _points;
@override List<TrendPoint> get points {
  if (_points is EqualUnmodifiableListView) return _points;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_points);
}

@override@JsonKey(name: 'first_value') final  double firstValue;
@override@JsonKey(name: 'last_value') final  double lastValue;
@override final  double change;
@override@JsonKey(name: 'percent_change') final  double? percentChange;
/// `up` · `down` · `flat`.
@override final  String direction;
/// `HIGH` · `LOW` · `NORMAL`.
@override@JsonKey(name: 'latest_status') final  String latestStatus;

/// Create a copy of TrendSeries
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TrendSeriesCopyWith<_TrendSeries> get copyWith => __$TrendSeriesCopyWithImpl<_TrendSeries>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TrendSeriesToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TrendSeries&&(identical(other.name, name) || other.name == name)&&(identical(other.unit, unit) || other.unit == unit)&&(identical(other.referenceRange, referenceRange) || other.referenceRange == referenceRange)&&const DeepCollectionEquality().equals(other._points, _points)&&(identical(other.firstValue, firstValue) || other.firstValue == firstValue)&&(identical(other.lastValue, lastValue) || other.lastValue == lastValue)&&(identical(other.change, change) || other.change == change)&&(identical(other.percentChange, percentChange) || other.percentChange == percentChange)&&(identical(other.direction, direction) || other.direction == direction)&&(identical(other.latestStatus, latestStatus) || other.latestStatus == latestStatus));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,unit,referenceRange,const DeepCollectionEquality().hash(_points),firstValue,lastValue,change,percentChange,direction,latestStatus);

@override
String toString() {
  return 'TrendSeries(name: $name, unit: $unit, referenceRange: $referenceRange, points: $points, firstValue: $firstValue, lastValue: $lastValue, change: $change, percentChange: $percentChange, direction: $direction, latestStatus: $latestStatus)';
}


}

/// @nodoc
abstract mixin class _$TrendSeriesCopyWith<$Res> implements $TrendSeriesCopyWith<$Res> {
  factory _$TrendSeriesCopyWith(_TrendSeries value, $Res Function(_TrendSeries) _then) = __$TrendSeriesCopyWithImpl;
@override @useResult
$Res call({
 String name, String unit,@JsonKey(name: 'reference_range') String referenceRange, List<TrendPoint> points,@JsonKey(name: 'first_value') double firstValue,@JsonKey(name: 'last_value') double lastValue, double change,@JsonKey(name: 'percent_change') double? percentChange, String direction,@JsonKey(name: 'latest_status') String latestStatus
});




}
/// @nodoc
class __$TrendSeriesCopyWithImpl<$Res>
    implements _$TrendSeriesCopyWith<$Res> {
  __$TrendSeriesCopyWithImpl(this._self, this._then);

  final _TrendSeries _self;
  final $Res Function(_TrendSeries) _then;

/// Create a copy of TrendSeries
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? unit = null,Object? referenceRange = null,Object? points = null,Object? firstValue = null,Object? lastValue = null,Object? change = null,Object? percentChange = freezed,Object? direction = null,Object? latestStatus = null,}) {
  return _then(_TrendSeries(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,unit: null == unit ? _self.unit : unit // ignore: cast_nullable_to_non_nullable
as String,referenceRange: null == referenceRange ? _self.referenceRange : referenceRange // ignore: cast_nullable_to_non_nullable
as String,points: null == points ? _self._points : points // ignore: cast_nullable_to_non_nullable
as List<TrendPoint>,firstValue: null == firstValue ? _self.firstValue : firstValue // ignore: cast_nullable_to_non_nullable
as double,lastValue: null == lastValue ? _self.lastValue : lastValue // ignore: cast_nullable_to_non_nullable
as double,change: null == change ? _self.change : change // ignore: cast_nullable_to_non_nullable
as double,percentChange: freezed == percentChange ? _self.percentChange : percentChange // ignore: cast_nullable_to_non_nullable
as double?,direction: null == direction ? _self.direction : direction // ignore: cast_nullable_to_non_nullable
as String,latestStatus: null == latestStatus ? _self.latestStatus : latestStatus // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
