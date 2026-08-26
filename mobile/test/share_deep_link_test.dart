/// Regression test for the public share deep links.
///
/// A recipient follows a QR or an "Open in App" link without ever signing in —
/// the token *is* the credential. The redirect must therefore let a signed-out
/// visitor land straight on the reader and never divert them to the sign-in
/// screen. This is exactly what regressed once: the public-route check compared
/// `matchedLocation` (a resolved path like `/share/qr-code/ABC`) against the
/// route *patterns* (`/share/qr-code/:token`), so it never matched and the
/// reader was unreachable — a share "opened in the app" took the recipient to
/// the login.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ayuvo/app.dart';
import 'package:ayuvo/core/health/health_providers.dart';
import 'package:ayuvo/core/network/network_providers.dart';
import 'package:ayuvo/core/notifications/reminders.dart';
import 'package:ayuvo/core/router/app_router.dart';
import 'package:ayuvo/core/session/session_controller.dart';
import 'package:ayuvo/core/storage/local_store.dart';
import 'package:ayuvo/core/storage/session_store.dart';
import 'package:ayuvo/features/auth/data/auth_repository.dart';

import 'support/fake_api.dart';
import 'support/fakes.dart';
import 'support/harness.dart';

const _wholeRecordJson = {
  'user_name': 'Hari Prasad',
  'emergency': {
    'blood_type': 'O+',
    'emergency_contacts': [
      {'name': 'Sita', 'phone': '9812345678'},
    ],
  },
  'reports': [
    {
      'id': 'rep-1',
      'report_type': 'BLOOD_TEST',
      'file_name': 'cbc.pdf',
      'file_content': 'aGVsbG8=',
      'notes': null,
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
      'notes': null,
    },
  ],
};

Future<void> _pumpAnonymous(
  WidgetTester tester,
  FakeApi api,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        // No stored session → signed out.
        sessionStoreProvider.overrideWithValue(InMemorySessionStore()),
        authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
        healthProvider.overrideWith((ref) async => testHealth),
        localStoreProvider.overrideWithValue(InMemoryLocalStore()),
        remindersProvider.overrideWithValue(NoReminders()),
        apiClientProvider.overrideWith((ref) {
          final client = api.client();
          ref.onDispose(client.close);
          return client;
        }),
      ],
      child: const AyuvoApp(),
    ),
  );
  await settle(tester);
}

void main() {
  testWidgets('signed-out deep link lands on the reader, not the login',
      (tester) async {
    final api = FakeApi();
    api.json('GET /api/share/qr-code/abc-123', _wholeRecordJson);

    await _pumpAnonymous(tester, api);

    ProviderScope.containerOf(tester.element(find.byType(AyuvoApp)))
        .read(routerProvider)
        .go('/share/qr-code/abc-123');
    await settle(tester);

    expect(find.text('Shared medical record'), findsOneWidget);
    expect(find.text('Aspirin'), findsOneWidget);
    expect(find.text('Sita · 9812345678'), findsOneWidget);
  });

  testWidgets('single-report deep link parses and renders an item',
      (tester) async {
    final api = FakeApi();
    api.json(
      'GET /api/share/xyz-456',
      const {
        'report': {
          'id': 'rep-2',
          'report_type': 'MRI',
          'file_name': 'mri.pdf',
          'file_content': 'aGVsbG8=',
          'notes': 'checkup',
          'created_at': '2026-08-10T09:00:00',
        },
        'emergency': {
          'blood_type': 'O+',
          'emergency_contacts': [],
        },
        'user_name': 'Hari Prasad',
      },
    );

    await _pumpAnonymous(tester, api);

    ProviderScope.containerOf(tester.element(find.byType(AyuvoApp)))
        .read(routerProvider)
        .go('/share/xyz-456');
    await settle(tester);

    expect(find.text('MRI'), findsOneWidget);
    expect(find.text('mri.pdf'), findsOneWidget);
  });
}