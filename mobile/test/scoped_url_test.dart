/// The caretaker chokepoint, tested at the character level.
///
/// This is the bug the brief singles out: ids look like `#hos014`, and a `#`
/// pasted straight into a URL turns everything after it into a fragment. The
/// server then sees no `patient_id`, scopes the call to the caller's own
/// records, and answers 200 — a caretaker's edit silently lands on their own
/// medicine list. Nothing fails loudly, so it has to fail here instead.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:ayuvo/core/network/scoped_url.dart';

void main() {
  group('ScopedUrl', () {
    test('percent-encodes a # in the patient id', () {
      final url = ScopedUrl.build('/api/medicines', patientId: '#hos014');

      expect(url, '/api/medicines?patient_id=%23hos014');
      expect(Uri.parse(url).queryParameters['patient_id'], '#hos014');
      expect(Uri.parse(url).fragment, isEmpty);
    });

    test('the naive version of the same URL loses the id entirely', () {
      // Not testing our code — pinning the reason our code exists. If this ever
      // stops being true, the comment above is out of date.
      final naive = Uri.parse('/api/medicines?patient_id=#hos014');

      expect(naive.queryParameters['patient_id'], '');
      expect(naive.fragment, 'hos014');
    });

    test('omits the parameter when there is no patient', () {
      expect(ScopedUrl.build('/api/medicines'), '/api/medicines');
      expect(ScopedUrl.build('/api/medicines', patientId: null),
          '/api/medicines');
      expect(ScopedUrl.build('/api/medicines', patientId: '   '),
          '/api/medicines');
    });

    test('keeps other query parameters and encodes them too', () {
      final url = ScopedUrl.build(
        '/api/medicines/intake/log',
        patientId: '#hos014',
        query: {'date': '2026-08-06', 'note': 'after food'},
      );

      final parsed = Uri.parse(url);
      expect(parsed.path, '/api/medicines/intake/log');
      expect(parsed.queryParameters, {
        'date': '2026-08-06',
        'note': 'after food',
        'patient_id': '#hos014',
      });
      // A space becomes `+`, which is the form encoding for a query component
      // and what Starlette's parse_qsl reads back as a space.
      expect(url, contains('note=after+food'));
    });

    test('drops null values rather than sending the string "null"', () {
      final url = ScopedUrl.build(
        '/api/medicines',
        query: {'limit': 20, 'cursor': null},
      );

      expect(url, '/api/medicines?limit=20');
    });

    test('an id with no # is left readable', () {
      expect(
        ScopedUrl.build('/api/medicines', patientId: 'hos014'),
        '/api/medicines?patient_id=hos014',
      );
    });
  });
}
