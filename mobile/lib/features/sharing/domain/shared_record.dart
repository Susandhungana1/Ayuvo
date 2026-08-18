/// The public reader's payloads — `GET /api/share/qr-code/{token}` (the whole
/// record) and `GET /api/share/{token}` (one report).
///
/// These are the response shapes the web reader (`front/`) renders. The app
/// needs its own copies because sharing is meant to reach people *without* the
/// app, and now that the deep link can land here the app is a recipient too.
/// Field names are the server's, verbatim.
library;

import '../../../core/time/medi_time.dart';

/// One emergency-contact row of a shared record.
class SharedEmergencyContact {
  const SharedEmergencyContact({
    required this.name,
    required this.relationship,
    required this.phone,
  });

  final String name;
  final String relationship;
  final String phone;
}

/// The emergency card of a shared record: blood type, allergies, conditions,
/// and who to call.
class SharedEmergency {
  const SharedEmergency({
    this.bloodType,
    this.allergies,
    this.medicalConditions,
    this.contacts = const [],
  });

  factory SharedEmergency.fromJson(Map<String, dynamic> json) {
    final contactsJson =
        json['emergency_contacts'] as List<dynamic>? ?? const [];
    return SharedEmergency(
      bloodType: json['blood_type'] as String?,
      allergies: json['allergies'] as String?,
      medicalConditions: json['medical_conditions'] as String?,
      contacts: [
        for (final c in contactsJson)
          if (c is Map)
            SharedEmergencyContact(
              name: (c['name'] as String?) ?? '',
              relationship: (c['relationship'] as String?) ?? '',
              phone: (c['phone'] as String?) ?? '',
            ),
      ],
    );
  }

  final String? bloodType;
  final String? allergies;
  final String? medicalConditions;
  final List<SharedEmergencyContact> contacts;

  bool get hasAnything =>
      (bloodType?.trim().isNotEmpty ?? false) ||
      (allergies?.trim().isNotEmpty ?? false) ||
      (medicalConditions?.trim().isNotEmpty ?? false) ||
      contacts.isNotEmpty;
}

/// One report row inside a shared record.
class SharedReportItem {
  const SharedReportItem({
    required this.id,
    required this.reportType,
    required this.fileName,
    required this.fileContentB64,
    this.notes,
    this.extractedText,
    this.doctorName,
    this.hospital,
    this.createdAt,
  });

  factory SharedReportItem.fromJson(Map<String, dynamic> json) =>
      SharedReportItem(
        id: json['id'] as String? ?? '',
        reportType: json['report_type'] as String? ?? 'OTHER',
        fileName: json['file_name'] as String? ?? 'Report',
        fileContentB64: json['file_content'] as String? ?? '',
        notes: json['notes'] as String?,
        extractedText: json['extracted_text'] as String?,
        doctorName: json['doctor_name'] as String?,
        hospital: json['hospital'] as String?,
        createdAt: json['created_at'] as String?,
      );

  final String id;
  final String reportType;
  final String fileName;

  /// Base64-encoded original file, possibly empty when the server has no blob.
  final String fileContentB64;
  final String? notes;
  final String? extractedText;
  final String? doctorName;
  final String? hospital;
  final String? createdAt;

  DateTime? get created => MediTime.parseUtc(createdAt);
  bool get hasFile => fileContentB64.isNotEmpty;
}

/// One medicine row of a shared record.
class SharedMedicine {
  const SharedMedicine({
    required this.id,
    required this.name,
    required this.dosage,
    required this.frequency,
    required this.startDate,
    this.endDate,
    this.notes,
  });

  factory SharedMedicine.fromJson(Map<String, dynamic> json) => SharedMedicine(
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? '',
    dosage: json['dosage'] as String? ?? '',
    frequency: json['frequency'] as String? ?? '',
    startDate: json['start_date'] as String? ?? '',
    endDate: json['end_date'] as String?,
    notes: json['notes'] as String?,
  );

  final String id;
  final String name;
  final String dosage;
  final String frequency;
  final String startDate;
  final String? endDate;
  final String? notes;
}

/// `GET /api/share/qr-code/{token}` — the whole record: every report, every
/// medicine, and the emergency profile, behind one token.
class SharedRecord {
  const SharedRecord({
    required this.userName,
    this.userId,
    this.userBloodType,
    required this.emergency,
    required this.reports,
    required this.medicines,
  });

  factory SharedRecord.fromJson(Map<String, dynamic> json) => SharedRecord(
    userName: json['user_name'] as String? ?? 'Patient',
    userId: json['user_id'] as String?,
    userBloodType: json['user_blood_type'] as String?,
    emergency: SharedEmergency.fromJson(
      (json['emergency'] as Map?)?.cast<String, dynamic>() ?? const {},
    ),
    reports: [
      for (final r in (json['reports'] as List? ?? const []))
        if (r is Map) SharedReportItem.fromJson(r.cast<String, dynamic>()),
    ],
    medicines: [
      for (final m in (json['medicines'] as List? ?? const []))
        if (m is Map) SharedMedicine.fromJson(m.cast<String, dynamic>()),
    ],
  );

  final String userName;
  final String? userId;
  final String? userBloodType;
  final SharedEmergency emergency;
  final List<SharedReportItem> reports;
  final List<SharedMedicine> medicines;
}

/// `GET /api/share/{token}` — one report plus the patient's emergency context.
class SharedReportPage {
  const SharedReportPage({
    required this.report,
    required this.emergency,
    this.userName,
  });

  factory SharedReportPage.fromJson(Map<String, dynamic> json) =>
      SharedReportPage(
        report: SharedReportItem.fromJson(
          (json['report'] as Map?)?.cast<String, dynamic>() ?? const {},
        ),
        emergency: SharedEmergency.fromJson(
          (json['emergency'] as Map?)?.cast<String, dynamic>() ?? const {},
        ),
        userName: json['user_name'] as String?,
      );

  final SharedReportItem report;
  final SharedEmergency emergency;
  final String? userName;
}
