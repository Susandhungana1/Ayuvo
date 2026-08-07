/// `/api/documents` in Dart — a visit, and the files that came out of it.
library;

import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/time/medi_time.dart';

part 'document.freezed.dart';
part 'document.g.dart';

@freezed
abstract class MedicalDocument with _$MedicalDocument {
  const factory MedicalDocument({
    required String id,
    required String hospital,
    String? location,
    @JsonKey(name: 'doctor_name') String? doctorName,
    String? department,
    String? description,

    /// When the visit happened — **for rows created since that field existed**.
    /// Older rows carry the moment they were uploaded, because the server
    /// stamped `utcnow()` and the web app's date input was discarded. Treated
    /// as a plain date for exactly that reason: showing a time on it would
    /// claim a precision the value does not have.
    @JsonKey(name: 'checkup_date') required String checkupDate,
  }) = _MedicalDocument;

  const MedicalDocument._();

  factory MedicalDocument.fromJson(Map<String, dynamic> json) =>
      _$MedicalDocumentFromJson(json);

  DateTime? get visited => MediTime.parseDate(checkupDate);

  /// Everything below the hospital name, in one line.
  String get subtitle => [
        if (department?.trim().isNotEmpty ?? false) department!.trim(),
        if (doctorName?.trim().isNotEmpty ?? false) doctorName!.trim(),
        if (location?.trim().isNotEmpty ?? false) location!.trim(),
      ].join(' · ');
}

/// One attachment. `file_type` is always `"OTHER"` — the upload path hardcodes
/// it despite the enum having four values — so it is read but never displayed.
@freezed
abstract class DocumentFile with _$DocumentFile {
  const factory DocumentFile({
    required String id,
    required String name,
    @JsonKey(name: 'file_type') required String fileType,
  }) = _DocumentFile;

  factory DocumentFile.fromJson(Map<String, dynamic> json) =>
      _$DocumentFileFromJson(json);
}
