/// Care links: the wall-clock dose time that must never be localised, and the
/// four failures a caretaker screen has to tell apart.
library;

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ayuvo/core/network/api_client.dart';
import 'package:ayuvo/core/network/api_exception.dart';
import 'package:ayuvo/features/care/data/care_repository.dart';
import 'package:ayuvo/features/care/domain/care_link.dart';

import 'support/fake_http.dart';

Map<String, Object?> careLinkRow({
  String id = 'link-1',
  String userId = '#hos014',
  String name = 'Ram Bahadur',
  String createdAt = '2026-08-01T04:00:00Z',
  bool notify = true,
  int? medicineCount = 3,
  String? nextDoseName = 'Amlodipine',
  String? nextDoseLocal = '08:00',
  bool? nextDoseIsToday = true,
  String? nextDoseTimezone = 'Asia/Kathmandu',
}) =>
    {
      'id': id,
      'user_id': userId,
      'name': name,
      'created_at': createdAt,
      'notify': notify,
      'medicine_count': medicineCount,
      'next_dose_name': nextDoseName,
      'next_dose_local': nextDoseLocal,
      'next_dose_is_today': nextDoseIsToday,
      'next_dose_timezone': nextDoseTimezone,
    };

CareRepository repositoryThat(
  ResponseBody Function(RecordedRequest request) respond, {
  FakeAdapter? adapter,
}) {
  final dio = Dio()..httpClientAdapter = adapter ?? FakeAdapter(respond);
  return CareRepository(ApiClient(baseUrl: 'http://127.0.0.1:3001', dio: dio));
}

void main() {
  group('the dose time', () {
    test('stays the patient\'s own wall clock', () {
      // A caretaker in Sydney needs to know their father takes it at 8am
      // *there*. Parsing "08:00" into a DateTime would show 1:15pm and be
      // useless to both of them — so the model exposes no such getter.
      final link = CareLink.fromJson(careLinkRow(nextDoseLocal: '08:00'));

      expect(link.nextDoseLocal, '08:00');
      expect(link.hasNextDose, isTrue);
    });

    test('a patient with no schedule has no next dose', () {
      final link = CareLink.fromJson(
        careLinkRow(nextDoseName: null, nextDoseLocal: null),
      );

      expect(link.hasNextDose, isFalse);
    });
  });

  group('timestamps', () {
    test('created_at already carries a Z and is not shifted twice', () {
      // These go through `app/core/care.py::utc_iso`, unlike most of the API.
      final link = CareLink.fromJson(
        careLinkRow(createdAt: '2026-08-01T04:00:00Z'),
      );

      expect(link.created!.toUtc(), DateTime.utc(2026, 8, 1, 4));
    });

    test('an invite counts down and then dies', () {
      const invite = CareInvite(
        code: 'ABCD-EFGH',
        expiresAt: '2026-08-06T10:15:00Z',
      );
      final tenPast = DateTime.utc(2026, 8, 6, 10, 5);
      final later = DateTime.utc(2026, 8, 6, 10, 20);

      expect(invite.remaining(tenPast), const Duration(minutes: 10));
      expect(invite.isDead(tenPast), isFalse);
      expect(invite.remaining(later), Duration.zero);
      expect(invite.isDead(later), isTrue);
    });
  });

  group('the error taxonomy', () {
    test('403 means the patient revoked the link', () async {
      final repository = repositoryThat(
        (_) => jsonResponse({'detail': 'Forbidden'}, statusCode: 403),
      );

      await expectLater(
        repository.links(CareRole.caretaker),
        throwsA(
          isA<CareFailure>()
              .having((f) => f.kind, 'kind', CareFailureKind.revoked),
        ),
      );
    });

    test('404 means the feature is switched off, not "your account"', () async {
      // The whole router 404s while CARETAKER_ENABLED is false. Reporting that
      // as "not available on your account" would be wrong and unactionable.
      final repository = repositoryThat(
        (_) => jsonResponse({'detail': 'Not Found'}, statusCode: 404),
      );

      await expectLater(
        repository.links(CareRole.patient),
        throwsA(
          isA<CareFailure>()
              .having((f) => f.kind, 'kind', CareFailureKind.featureOff),
        ),
      );
    });

    test('a 400 passes through with the server\'s own wording', () async {
      // Wrong, expired and already-used codes all return one identical
      // message on purpose — nothing here tries to guess which.
      final repository = repositoryThat(
        (_) => jsonResponse(
          {'detail': 'That code is not valid.'},
          statusCode: 400,
        ),
      );

      await expectLater(
        repository.redeem('ABCD-EFGH'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.message, 'message', 'That code is not valid.'),
        ),
      );
    });

    test('a 500 is not dressed up as a care failure', () async {
      final repository = repositoryThat(
        (_) => jsonResponse({'detail': 'boom'}, statusCode: 500),
      );

      await expectLater(
        repository.links(CareRole.patient),
        throwsA(isA<ApiException>()),
      );
    });
  });

  group('requests', () {
    test('the role goes in the query string', () async {
      final adapter = FakeAdapter((_) => jsonResponse({'links': []}));
      await repositoryThat((_) => jsonResponse({}), adapter: adapter)
          .links(CareRole.caretaker);

      expect(adapter.requests.single.options.uri.query, 'role=caretaker');
    });

    test('a code is upper-cased and trimmed before it is sent', () async {
      final adapter = FakeAdapter((_) => jsonResponse(careLinkRow()));
      await repositoryThat((_) => jsonResponse({}), adapter: adapter)
          .redeem('  abcd-efgh  ');

      expect(adapter.requests.single.body, contains('ABCD-EFGH'));
    });

    test('an empty list is an empty list, not a null', () async {
      final repository = repositoryThat((_) => jsonResponse({}));

      expect(await repository.links(CareRole.patient), isEmpty);
    });
  });
}
