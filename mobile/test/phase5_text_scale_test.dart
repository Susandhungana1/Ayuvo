/// Every phase 5 screen on a small phone at 2× text, in both themes.
///
/// `DESIGN.md` claims the system survives text scaling to 2.0 with no
/// clipping. `design_review_test.dart` proves that for the design gallery;
/// this proves it for the four screens phase 5 added, which the gallery does
/// not contain.
///
/// No error plumbing here on purpose: the test binding already turns a
/// RenderFlex overflow into a failure, and intercepting `FlutterError.onError`
/// to collect them would hide the very thing being checked.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_api.dart';
import 'support/fakes.dart';
import 'support/harness.dart';

/// The narrowest phone worth supporting. Tall so a lazy list builds every row
/// in one pass — scrolling at 2× is a ballistic simulation that never settles.
const _viewport = Size(320, 4000);

Future<void> _pumpAt(
  WidgetTester tester,
  FakeApi api, {
  required Brightness brightness,
  bool doctor = false,
}) async {
  tester.view.physicalSize = _viewport;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  // On the platform dispatcher, not in a MediaQuery wrapper: MaterialApp builds
  // its own from the view and would discard the wrapper, so the scale under
  // test would silently always be 1.0.
  tester.platformDispatcher.textScaleFactorTestValue = 2.0;
  tester.platformDispatcher.platformBrightnessTestValue = brightness;
  addTearDown(tester.platformDispatcher.clearAllTestValues);

  await pumpSignedIn(tester, api, user: doctor ? testDoctor : testUser);
}

FakeApi _patientBackend() => FakeApi()
  ..json('GET /api/medicines', {'medicines': const []})
  ..json('GET /api/vitals', {'vitals': const []})
  ..json('GET /api/reports', {
    'reports': [reportRow()],
  })
  ..json('GET /api/share', {
    'links': [
      shareLinkRow(token: 'live-one', expiresAt: '2030-08-08T09:14:22'),
      shareLinkRow(token: 'dead-one', expiresAt: '2020-01-01T00:00:00'),
    ],
  })
  ..json('GET /api/emergency/profile', {
    'blood_type': 'AB-',
    'allergies': 'Penicillin, sulfa drugs, latex and shellfish',
    'medical_conditions': 'Type 2 diabetes, hypertension',
    'emergency_contacts': [emergencyContactRow()],
  })
  ..json('GET /api/appointments', {
    'appointments': [
      appointmentRow(
        title: 'Cardiology follow-up with a long enough title to wrap',
        hospital: 'Bir Hospital',
      ),
      appointmentRow(
        id: 'apt-2',
        title: 'Blood test',
        doctorId: null,
        doctorName: 'Dr Someone Else',
        status: 'PENDING',
      ),
    ],
  });

FakeApi _doctorBackend() => FakeApi()
  ..json('GET /api/appointments/doctor/my-appointments', {
    'appointments': [
      appointmentRow(status: 'PENDING'),
      appointmentRow(id: 'apt-2', title: 'Post-op review'),
    ],
  })
  ..json('GET /api/doctors/availability', {
    'availability': [
      availabilityRow(),
      availabilityRow(
        id: 'avail-2',
        startTime: '14:00:00',
        endTime: '17:30:00',
        slotDurationMinutes: 45,
        isAvailable: false,
      ),
    ],
  })
  ..json('GET /api/doctors/doctors/me', doctorRow(verified: false));

/// Opens one of Account's tiles, scrolling to it first — at 2× the list is
/// twice as long and the last tile starts well below the fold.
Future<void> _openFromAccount(WidgetTester tester, String label) async {
  await openTab(tester, 'Account');
  await tapAfterScroll(
    tester,
    find.text(label),
    scrollable: find
        .descendant(of: find.byType(ListView), matching: find.byType(Scrollable))
        .first,
  );
}

void main() {
  for (final brightness in Brightness.values) {
    final theme = brightness.name;

    testWidgets('appointments survive 2x text in $theme', (tester) async {
      await _pumpAt(tester, _patientBackend(), brightness: brightness);
      await _openFromAccount(tester, 'Appointments');

      expect(find.text('Coming up'), findsOneWidget);
    });

    testWidgets('sharing survives 2x text in $theme', (tester) async {
      await _pumpAt(tester, _patientBackend(), brightness: brightness);
      await _openFromAccount(tester, 'Sharing');

      expect(find.text('Your whole record'), findsOneWidget);
    });

    testWidgets('the emergency card survives 2x text in $theme',
        (tester) async {
      await _pumpAt(tester, _patientBackend(), brightness: brightness);
      await _openFromAccount(tester, 'Emergency ID');

      expect(find.text('AB-'), findsOneWidget);
    });

    testWidgets('the doctor inbox survives 2x text in $theme', (tester) async {
      await _pumpAt(
        tester,
        _doctorBackend(),
        brightness: brightness,
        doctor: true,
      );

      expect(find.text('Waiting on you'), findsOneWidget);
    });

    testWidgets('the availability editor survives 2x text in $theme',
        (tester) async {
      await _pumpAt(
        tester,
        _doctorBackend(),
        brightness: brightness,
        doctor: true,
      );
      await openTab(tester, 'Availability');

      // Two windows on one day, one of them paused — the widest row on the
      // screen, and the one with a switch and two icon buttons beside it.
      expect(find.text('Paused — nobody can book this'), findsOneWidget);
    });
  }
}
