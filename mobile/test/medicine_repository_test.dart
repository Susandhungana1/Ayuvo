/// What the medicine repository actually puts on the wire.
///
/// The caretaker rules are the point of these: a `#` in a patient id must
/// survive, and the two intake routes must never carry a `patient_id` at all.
library;

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ayuvo/core/network/api_client.dart';
import 'package:ayuvo/features/medicines/data/medicine_repository.dart';

import 'support/fake_http.dart';

void main() {
  late FakeAdapter adapter;
  late MedicineRepository repository;

  RecordedRequest lastRequest() => adapter.requests.last;

  Map<String, dynamic> lastBody() =>
      jsonDecode(lastRequest().body) as Map<String, dynamic>;

  void arrange(ResponseBody Function(RecordedRequest) respond) {
    adapter = FakeAdapter(respond);
    final dio = Dio()..httpClientAdapter = adapter;
    repository = MedicineRepository(
      ApiClient(baseUrl: 'http://127.0.0.1:3001', dio: dio)..useToken('t'),
    );
  }

  const medicineJson = {
    'id': 'med-1',
    'name': 'Amlodipine',
    'dosage': '5 mg',
    'frequency': 'Once daily',
    'start_date': '2026-01-01',
    'end_date': null,
    'taking_times': '["08:00"]',
    'notes': null,
    'created_at': '2026-01-01 09:00:00',
  };

  group('list', () {
    test('unscoped, there is no patient_id at all', () async {
      arrange((_) => jsonResponse({'medicines': [medicineJson], 'total': 1}));
      final result = await repository.list();

      expect(result.medicines, hasLength(1));
      expect(result.medicines.first.times, ['08:00']);
      expect(lastRequest().options.uri.query, contains('offset=0'));
      expect(lastRequest().options.uri.query, contains('limit=20'));
    });

    test('a patient id containing # survives as a query parameter', () async {
      // The trap this whole chokepoint exists for: interpolated raw, "#hos014"
      // becomes a fragment, the server sees no patient_id, and answers with
      // the *caller's* medicines instead of the patient's.
      arrange((_) => jsonResponse({'medicines': const []}));
      await repository.list(patientId: '#hos014');

      expect(lastRequest().options.uri.queryParameters['patient_id'], '#hos014');
      expect(lastRequest().options.uri.fragment, isEmpty);
      expect(lastRequest().options.uri.toString(), contains('patient_id=%23hos014'));
    });
  });

  group('create', () {
    test('encodes dose times into the string-wrapped array', () async {
      arrange((_) => jsonResponse(medicineJson));
      await repository.create(
        name: 'Amlodipine',
        dosage: '5 mg',
        frequency: 'Once daily',
        startDate: '2026-01-01',
        times: ['20:00', '08:00'],
      );

      expect(lastBody()['taking_times'], '["08:00","20:00"]');
    });

    test('blank optional fields go as null, not empty strings', () async {
      arrange((_) => jsonResponse(medicineJson));
      await repository.create(
        name: 'Amlodipine',
        dosage: '5 mg',
        frequency: 'Once daily',
        startDate: '2026-01-01',
        endDate: '   ',
        notes: '',
      );

      expect(lastBody()['end_date'], isNull);
      expect(lastBody()['notes'], isNull);
      expect(lastBody()['taking_times'], isNull);
    });
  });

  group('update', () {
    test('omits every field the caller did not pass', () async {
      // The server skips nulls, so an absent key and a null key mean the same
      // thing — but sending only what changed keeps the audit diff honest.
      arrange((_) => jsonResponse(medicineJson));
      await repository.update('med-1', notes: 'Take with food');

      expect(lastBody().keys, ['notes']);
      expect(lastRequest().options.method, 'PUT');
    });

    test('clearing every dose time sends "[]" rather than null', () async {
      // null would mean "leave unchanged" and the times would silently stay.
      arrange((_) => jsonResponse(medicineJson));
      await repository.update('med-1', times: const []);

      expect(lastBody()['taking_times'], '[]');
    });

    test('scopes to the patient when one is given', () async {
      arrange((_) => jsonResponse(medicineJson));
      await repository.update('med-1', name: 'X', patientId: '#hos014');

      expect(lastRequest().options.uri.path, '/api/medicines/med-1');
      expect(lastRequest().options.uri.queryParameters['patient_id'], '#hos014');
    });
  });

  group('intake', () {
    test('recording a dose carries no patient_id, ever', () async {
      // Self-only by design: a caretaker manages the list, but only the
      // patient can assert that a tablet was swallowed. The server refuses a
      // patient_id here and the client must not try to send one.
      arrange((_) => jsonResponse({
            'id': 'log-1',
            'medicine_id': 'med-1',
            'scheduled_time': '08:00',
            'status': 'taken',
            'recorded_at': '2026-08-06 08:02:00',
          }));
      final intake =
          await repository.recordIntake('med-1', scheduledTime: '08:00');

      expect(intake.status, 'taken');
      expect(lastRequest().options.uri.query, isEmpty);
      expect(lastBody(), {'scheduled_time': '08:00', 'status': 'taken'});
    });

    test('the log route is self-only too', () async {
      arrange((_) => jsonResponse({'intakes': const []}));
      await repository.intakeLog();

      expect(lastRequest().options.uri.queryParameters.containsKey('patient_id'),
          isFalse);
    });
  });

  group('interactions', () {
    test('decodes and reports how many medicines were checked', () async {
      arrange((_) => jsonResponse({
            'interactions': [
              {
                'drug_a': 'Warfarin',
                'drug_b': 'Aspirin',
                'severity': 'severe',
                'description': 'Increased bleeding risk.',
              },
            ],
            'checked_count': 4,
          }));
      final check = await repository.interactions();

      expect(check.checkedCount, 4);
      expect(check.interactions.single.rank, 0);
    });
  });

  group('audit', () {
    test('reads the Z-bearing timestamp without shifting it again', () async {
      // medicine_audit.created_at is one of only three fields that already
      // carries a marker, because it goes through care.py::utc_iso.
      arrange((_) => jsonResponse({
            'entries': [
              {
                'id': 1,
                'actor_id': '#hos014',
                'actor_name': 'Sita',
                'medicine_id': 'med-1',
                'medicine_name': 'Amlodipine',
                'action': 'create',
                'created_at': '2026-08-06T09:14:22Z',
                'by_caretaker': true,
              },
            ],
          }));
      final entries = await repository.audit();

      expect(entries.single.created!.toUtc().hour, 9);
      expect(entries.single.byCaretaker, isTrue);
    });
  });
}
