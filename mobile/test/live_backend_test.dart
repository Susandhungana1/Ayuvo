/// The client against a **real** local backend — no fakes anywhere.
///
/// Skipped by default so `flutter test` stays offline and deterministic. Run it
/// against a live `uvicorn main:app --port 3001` with:
///
///   flutter test test/live_backend_test.dart --dart-define=LIVE_BACKEND=true
///
/// It registers a throwaway account (unique email per run) in whatever database
/// that server points at, so point it at local Postgres — never production.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:medistore/core/network/api_client.dart';
import 'package:medistore/core/network/api_exception.dart';
import 'package:medistore/core/network/scoped_url.dart';
import 'package:medistore/core/time/medi_time.dart';
import 'package:medistore/features/auth/data/auth_repository.dart';
import 'package:medistore/features/documents/data/document_repository.dart';
import 'package:medistore/features/medicines/data/medicine_repository.dart';
import 'package:medistore/features/medicines/domain/dose_times.dart';
import 'package:medistore/features/reports/data/report_repository.dart';
import 'package:medistore/features/vitals/data/vital_repository.dart';

const _enabled = bool.fromEnvironment('LIVE_BACKEND');
const _baseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://127.0.0.1:3001',
);

void main() {
  if (!_enabled) {
    test(
      'live backend checks',
      () {},
      skip: 'opt-in: --dart-define=LIVE_BACKEND=true, with uvicorn on $_baseUrl',
    );
    return;
  }

  late ApiClient client;
  late AuthRepository auth;
  late String email;
  var expiries = 0;

  const password = 'phase3-live-check';

  setUpAll(() {
    // flutter_test blocks real sockets by default; this test is the one place
    // that genuinely wants the network.
    HttpOverrides.global = null;
  });

  setUp(() {
    client = ApiClient(baseUrl: _baseUrl);
    client.onSessionExpired = () => expiries++;
    auth = AuthRepository(client);
    email = 'phase3+${DateTime.now().microsecondsSinceEpoch}@example.com';
  });

  tearDown(() => client.close());

  test('health reports a database and tells us about caretakers', () async {
    final json =
        await client.get<Map<String, dynamic>>('/health', options: unauthenticated);

    expect(json['status'], 'ok');
    expect(json['database'], isTrue);
    expect(json['caretaker'], isA<bool>());
  });

  test('register, then sign in, then read yourself back', () async {
    final registered = await auth.register(
      name: 'Phase Three',
      email: email,
      password: password,
    );
    expect(registered.user.email, email);
    expect(registered.user.role, 'PATIENT');
    expect(registered.user.id, startsWith('#'));

    final signedIn = await auth.login(email: email, password: password);
    expect(signedIn.token, isNotEmpty);

    client.useToken(signedIn.token);
    final me = await auth.me();
    expect(me.id, registered.user.id);
    expect(me.email, email);
    expect(expiries, 0);
  });

  test('a short password is refused in the server\'s own words', () async {
    await expectLater(
      auth.register(name: 'Too Short', email: email, password: 'short'),
      throwsA(
        isA<ApiException>()
            .having((e) => e.kind, 'kind', ApiErrorKind.invalid)
            .having((e) => e.message, 'message', contains('8 characters')),
      ),
    );
  });

  test('the wrong password is a credentials failure, not a dead session',
      () async {
    await auth.register(name: 'Phase Three', email: email, password: password);

    await expectLater(
      auth.login(email: email, password: 'not-the-password'),
      throwsA(isA<ApiException>()
          .having((e) => e.kind, 'kind', ApiErrorKind.credentials)),
    );
    expect(expiries, 0);
  });

  test('a dead token ends the session exactly once', () async {
    client.useToken('this.is.not-a-token');

    await expectLater(
      auth.me(),
      throwsA(isA<ApiException>()
          .having((e) => e.kind, 'kind', ApiErrorKind.unauthorized)),
    );
    expect(expiries, 1);
  });

  test('an authenticated data call works, # in the id and all', () async {
    final session = await auth.register(
      name: 'Phase Three',
      email: email,
      password: password,
    );
    client.useToken(session.token);

    // The id in the JWT contains a `#`; this proves the round trip survives it
    // and that ScopedUrl produces something the server accepts.
    final url = ScopedUrl.build('/api/medicines');
    final json = await client.get<Map<String, dynamic>>(url);

    expect(json['medicines'], isA<List<dynamic>>());
    expect(session.user.id, contains('#'));
  });

  // ── Phase 4 ───────────────────────────────────────────────────────────────
  //
  // These are the claims a fake adapter cannot make. Everything here is a
  // round trip: what the client writes, read back off the wire, decoded by the
  // same code the screens use.

  group('phase 4, signed in', () {
    // One account for the whole group, and its own client. `/api/auth/register`
    // is rate-limited, so a fresh registration per test 429s after the third —
    // which is the server behaving correctly, not a failure worth chasing.
    // Each test therefore cleans up what it creates and asserts on ids rather
    // than on an empty list.
    late ApiClient scoped;
    late MedicineRepository medicines;
    late VitalRepository vitals;
    late ReportRepository reports;
    late DocumentRepository documents;

    setUpAll(() async {
      scoped = ApiClient(baseUrl: _baseUrl);
      final session = await AuthRepository(scoped).register(
        name: 'Phase Four',
        email: 'phase4+${DateTime.now().microsecondsSinceEpoch}@example.com',
        password: password,
      );
      scoped.useToken(session.token);
      medicines = MedicineRepository(scoped);
      vitals = VitalRepository(scoped);
      reports = ReportRepository(scoped);
      documents = DocumentRepository(scoped);
    });

    tearDownAll(() => scoped.close());

    /// Retires every medicine on the account, so the next test starts from a
    /// list it can reason about.
    Future<void> clearMedicines() async {
      for (final medicine in await medicines.list()) {
        await medicines.remove(medicine.id);
      }
    }

    tearDown(clearMedicines);

    test('taking_times survives the round trip as a string-wrapped array',
        () async {
      final created = await medicines.create(
        name: 'Amlodipine',
        dosage: '5 mg',
        frequency: 'Once daily',
        startDate: '2026-01-01',
        times: ['20:00', '08:00'],
      );

      // Sorted on the way out, and the column holds the encoded string rather
      // than a JSON array — the shape the web app also writes.
      expect(created.takingTimes, '["08:00","20:00"]');
      expect(created.times, ['08:00', '20:00']);
      expect(DoseTimes.decode(created.takingTimes), ['08:00', '20:00']);

      final listed = await medicines.list();
      expect(listed.single.times, ['08:00', '20:00']);
    });

    test('"[]" clears the dose times where null would leave them alone',
        () async {
      final created = await medicines.create(
        name: 'Amlodipine',
        dosage: '5 mg',
        frequency: 'Once daily',
        startDate: '2026-01-01',
        times: ['08:00'],
      );

      // null means "leave unchanged" server-side, so the notes-only update
      // must not disturb the schedule.
      final renamed = await medicines.update(created.id, notes: 'With food');
      expect(renamed.times, ['08:00']);

      final cleared = await medicines.update(created.id, times: const []);
      expect(cleared.times, isEmpty);
    });

    test('delete is soft and restore brings back the same row', () async {
      final created = await medicines.create(
        name: 'Amoxicillin',
        dosage: '500 mg',
        frequency: 'Three times daily',
        startDate: '2026-01-01',
      );

      await medicines.remove(created.id);
      expect(await medicines.list(), isEmpty);

      final restored = await medicines.restore(created.id);
      // The same id, not a copy: this is what makes the snackbar's Undo honest.
      expect(restored.id, created.id);
      expect((await medicines.list()).single.id, created.id);
    });

    test('recording a dose is accepted with no patient_id and no undo',
        () async {
      final created = await medicines.create(
        name: 'Amlodipine',
        dosage: '5 mg',
        frequency: 'Once daily',
        startDate: '2026-01-01',
        times: ['08:00'],
      );

      final intake =
          await medicines.recordIntake(created.id, scheduledTime: '08:00');
      expect(intake.status, 'taken');
      expect(intake.medicineId, created.id);

      final log = await medicines.intakeLog();
      expect(log.map((entry) => entry.medicineId), contains(created.id));
    });

    test('the audit trail carries a Z-marked timestamp and the actor',
        () async {
      final created = await medicines.create(
        name: 'Amlodipine',
        dosage: '5 mg',
        frequency: 'Once daily',
        startDate: '2026-01-01',
      );

      final entries = await medicines.audit();
      final entry = entries.firstWhere((e) => e.medicineId == created.id);
      expect(entry.action, 'create');
      expect(entry.byCaretaker, isFalse);
      // One of only three timestamps in the API that arrives with a marker.
      expect(entry.createdAt, contains('Z'));
      expect(entry.created, isNotNull);
    });

    test('interactions answers with a count of what it actually checked',
        () async {
      await medicines.create(
        name: 'Warfarin',
        dosage: '5 mg',
        frequency: 'Once daily',
        startDate: '2026-01-01',
      );
      await medicines.create(
        name: 'Aspirin',
        dosage: '75 mg',
        frequency: 'Once daily',
        startDate: '2026-01-01',
      );

      final check = await medicines.interactions();
      expect(check.checkedCount, 2);
      expect(check.interactions, isA<List<Object?>>());
    });

    test('measured_at goes out naive UTC and comes back the same instant',
        () async {
      // The whole timestamp trap in one assertion. The column has no zone, so
      // a client that sends local time or reads the value as local is wrong by
      // its own offset — 5h45m here — and nothing in the response says so.
      final moment = DateTime.utc(2026, 8, 6, 3, 15);
      final created = await vitals.create(
        systolic: 118,
        diastolic: 76,
        measuredAt: moment,
      );

      expect(MediTime.parseUtc(created.measuredAt), moment.toLocal());
      expect(created.measuredAt, isNot(endsWith('Z')));

      final listed = await vitals.list();
      final readBack = listed.firstWhere((row) => row.id == created.id);
      expect(MediTime.parseUtc(readBack.measuredAt), moment.toLocal());

      await vitals.remove(created.id);
    });

    test('a vitals row with every measurement null is accepted, and empty',
        () async {
      // Which is why the form guards it client-side and `latestVitalProvider`
      // skips it: the server will store a row that says nothing.
      final created = await vitals.create(notes: 'Nothing measured');
      expect(created.isEmpty, isTrue);

      await vitals.remove(created.id);
    });

    test('the vitals page cap is real: 201 is refused', () async {
      // `list` clamps to 200 for this reason. Going round it should 422.
      await expectLater(
        scoped.get<Map<String, dynamic>>('/api/vitals?limit=201'),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 422)),
      );
    });

    test('reports and trends are empty for a new account, not an error',
        () async {
      expect(await reports.list(), isEmpty);
      expect(await reports.trends(), isEmpty);
    });

    test('a visit round-trips, and deleting it takes its files with it',
        () async {
      final created = await documents.create(
        hospital: 'Bir Hospital',
        department: 'Cardiology',
        visitedOn: DateTime(2026, 5, 2),
      );
      expect(created.hospital, 'Bir Hospital');
      // checkup_date is a plain date in meaning; reading it as a datetime and
      // converting would move it a day for anyone west of UTC.
      expect(MediTime.parseDate(created.checkupDate), DateTime(2026, 5, 2));

      expect(await documents.files(created.id), isEmpty);

      await documents.remove(created.id);
      expect(await documents.list(), isEmpty);
    });
  });
}
