/// Schema tests for the public share readers: the whole-record and single-report
/// payloads as the server shapes them. These guard the new deep-linked readers
/// (`/share/qr-code/:token` and `/share/:token`) against a field renamed — a
/// reader that silently shows "Patient" or zero medicines is worse than one
/// that fails loudly.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:medistore/features/sharing/domain/shared_record.dart';

const _wholeRecordJson = {
  'user_name': 'Hari Prasad',
  'user_id': '#hos014',
  'user_blood_type': 'O+',
  'emergency': {
    'blood_type': 'O+',
    'allergies': 'Penicillin',
    'medical_conditions': 'Diabetes',
    'emergency_contacts': [
      {'name': 'Sita', 'relationship': 'Wife', 'phone': '9812345678'},
    ],
  },
  'reports': [
    {
      'id': 'rep-1',
      'report_type': 'BLOOD_TEST',
      'file_name': 'cbc.pdf',
      'file_content': 'aGVsbG8=',
      'notes': 'fasting sample',
      'extracted_text': 'CBC ...',
      'doctor_name': 'Dr. Shrestha',
      'hospital': 'Grande Hospital',
      'created_at': '2026-08-10T09:00:00',
    },
  ],
  'medicines': [
    {
      'id': 'med-1',
      'name': 'Aspirin',
      'dosage': '75mg',
      'frequency': 'Once daily',
      'start_date': '2026-08-01',
      'end_date': '2026-09-01',
      'notes': 'after food',
    },
  ],
};

const _singleReportJson = {
  'report': {
    'id': 'rep-1',
    'report_type': 'MRI',
    'file_name': 'mri.pdf',
    'file_content': 'aGVsbG8=',
    'notes': null,
    'extracted_text': null,
    'doctor_name': 'Dr. Sharma',
    'hospital': null,
    'created_at': '2026-08-10T09:00:00',
  },
  'emergency': {
    'blood_type': 'O+',
    'allergies': null,
    'medical_conditions': null,
    'emergency_contacts': [],
  },
  'user_name': 'Hari Prasad',
  'user_id': '#hos014',
  'user_blood_type': 'O+',
};

void main() {
  group('SharedRecord.fromJson — whole-record share', () {
    test('parses every field the web reader renders', () {
      final record = SharedRecord.fromJson(_wholeRecordJson);

      expect(record.userName, 'Hari Prasad');
      expect(record.userId, '#hos014');
      expect(record.userBloodType, 'O+');

      expect(record.emergency.bloodType, 'O+');
      expect(record.emergency.allergies, 'Penicillin');
      expect(record.emergency.medicalConditions, 'Diabetes');
      expect(record.emergency.contacts.single.name, 'Sita');
      expect(record.emergency.hasAnything, isTrue);

      expect(record.medicines.single.name, 'Aspirin');
      expect(record.medicines.single.dosage, '75mg');
      expect(record.medicines.single.frequency, 'Once daily');
      expect(record.medicines.single.startDate, '2026-08-01');
      expect(record.medicines.single.notes, 'after food');

      final report = record.reports.single;
      expect(report.reportType, 'BLOOD_TEST');
      expect(report.fileName, 'cbc.pdf');
      expect(report.hasFile, isTrue);
      expect(report.notes, 'fasting sample');
      expect(report.doctorName, 'Dr. Shrestha');
      expect(report.created, isNotNull);
    });

    test('missing maps degrade to empty lists, not a crash', () {
      final record = SharedRecord.fromJson({'user_name': 'Nobody'});

      expect(record.reports, isEmpty);
      expect(record.medicines, isEmpty);
      expect(record.emergency.hasAnything, isFalse);
    });
  });

  group('SharedReportPage.fromJson — single-report share', () {
    test('parses the report and its emergency context', () {
      final page = SharedReportPage.fromJson(_singleReportJson);

      expect(page.userName, 'Hari Prasad');
      expect(page.report.reportType, 'MRI');
      expect(page.report.doctorName, 'Dr. Sharma');
      expect(page.report.hasFile, isTrue);
      expect(page.emergency.bloodType, 'O+');
      expect(page.emergency.hasAnything, isTrue);
    });
  });
}
