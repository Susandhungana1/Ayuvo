/// The whole-record reader's PIN gate, driven through the real `ApiClient`.
///
/// Whole-record links are PIN-guarded, so the reader's first fetch answers
/// 401; the screen must ask for the PIN and resend it as a query parameter —
/// and a wrong PIN must keep the prompt up rather than fall into the generic
/// error card.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medistore/core/network/network_providers.dart';
import 'package:medistore/features/sharing/presentation/shared_record_screen.dart';

import 'support/fake_api.dart';
import 'support/fake_http.dart';
import 'support/harness.dart';

const _record = {
  'user_name': 'Hari Prasad',
  'user_id': '#hos014',
  'user_blood_type': 'O+',
  'emergency': {'blood_type': 'O+', 'emergency_contacts': []},
  'reports': [],
  'medicines': [],
};

FakeApi pinBackend({String? wrongPin}) => FakeApi()
  ..on('GET /api/share/qr-code/tok-1', (request) {
    final pin = request.options.uri.queryParameters['pin'];
    if (pin != null && pin != wrongPin) return _record;
    return jsonResponse(
      {
        'detail': 'This health record is PIN-protected. Ask the owner for the '
            '6-digit PIN.',
      },
      statusCode: 401,
    );
  });

Future<void> pumpReader(WidgetTester tester, FakeApi api) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        apiClientProvider.overrideWith((ref) {
          final client = api.client();
          ref.onDispose(client.close);
          return client;
        }),
      ],
      child: const MaterialApp(home: SharedRecordScreen(token: 'tok-1')),
    ),
  );
  await settle(tester);
}

void main() {
  testWidgets('a PIN-guarded record first asks for the PIN', (tester) async {
    final api = pinBackend();
    await pumpReader(tester, api);

    expect(find.text('This record is PIN-protected'), findsOneWidget);
    expect(find.text('Shared medical record'), findsNothing);
    expect(
      find.textContaining('never sent with the link'),
      findsOneWidget,
    );
  });

  testWidgets('the PIN is resent as a query parameter and the record opens',
      (tester) async {
    final api = pinBackend();
    await pumpReader(tester, api);

    await tester.enterText(find.byType(TextField), '123456');
    await settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'View health record'));
    await settle(tester);

    final request = api.requestFor('GET /api/share/qr-code/tok-1')!;
    expect(request.options.uri.queryParameters['pin'], '123456');
    expect(find.text('Shared medical record'), findsOneWidget);
    expect(find.text('0 report(s) · 0 medicine(s)'), findsOneWidget);
    expect(api.unmatched, isEmpty);
  });

  testWidgets('a wrong PIN keeps the prompt up and says so', (tester) async {
    final api = pinBackend(wrongPin: '123456');
    await pumpReader(tester, api);

    await tester.enterText(find.byType(TextField), '123456');
    await settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'View health record'));
    await settle(tester);

    expect(find.text('Incorrect PIN — try again.'), findsOneWidget);
    expect(find.text('Shared medical record'), findsNothing);
    expect(find.widgetWithText(FilledButton, 'View health record'), findsOneWidget);
  });

  testWidgets('the button stays disabled until six digits are typed',
      (tester) async {
    final api = pinBackend();
    await pumpReader(tester, api);

    await tester.enterText(find.byType(TextField), '12345');
    await settle(tester);
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'View health record'),
    );
    expect(button.onPressed, isNull);

    await tester.enterText(find.byType(TextField), '123456');
    await settle(tester);
    final enabled = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'View health record'),
    );
    expect(enabled.onPressed, isNotNull);
  });
}
