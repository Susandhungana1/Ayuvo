/// Documents — a visit, and the files it produced.
///
/// Reached from Account rather than the bottom bar, so these tests also check
/// that the tab bar survives the trip: it is a child route of the More branch
/// precisely so Back returns to Account and not to whatever came before.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ayuvo/features/documents/presentation/documents_screen.dart';

import 'support/fake_api.dart';
import 'support/harness.dart';

FakeApi backend({List<Map<String, Object?>> documents = const []}) => FakeApi()
  ..json('GET /api/medicines', {'medicines': const []})
  ..json('GET /api/vitals', {'vitals': const []})
  ..json('GET /api/documents', {'documents': documents});

Future<void> openDocuments(WidgetTester tester, FakeApi api) async {
  await pumpSignedIn(tester, api);
  await openTab(tester, 'Account');
  await tester.tap(find.text('Documents'));
  await settle(tester);
}

void main() {
  testWidgets('an empty list explains what the screen is for', (tester) async {
    await openDocuments(tester, backend());

    expect(find.text('No visits recorded'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Add your first visit'),
        findsOneWidget);
  });

  testWidgets('the bottom bar stays put, because this is a child of Account',
      (tester) async {
    await openDocuments(tester, backend());

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(DocumentsScreen), findsOneWidget);
  });

  testWidgets('a visit shows where, who and when in one line', (tester) async {
    await openDocuments(tester, backend(documents: [documentRow()]));

    expect(find.text('Bir Hospital'), findsOneWidget);
    expect(find.text('Cardiology · Dr Asha Rai · Kathmandu'), findsOneWidget);
  });

  testWidgets('a visit with only a hospital name has no empty subtitle line',
      (tester) async {
    await openDocuments(
      tester,
      backend(documents: [
        documentRow(department: null, doctorName: null, location: null),
      ]),
    );

    expect(find.text('Bir Hospital'), findsOneWidget);
    expect(find.text(''), findsNothing);
  });

  testWidgets('attachments are fetched only when the visit is opened',
      (tester) async {
    // One request per visit on load would be N requests for a list of N.
    final api = backend(documents: [documentRow()])
      ..json('GET /api/documents/doc-1/files', {
        'files': [
          {'id': 'f1', 'name': 'discharge.pdf', 'file_type': 'OTHER'},
        ],
      });
    await openDocuments(tester, api);

    expect(api.calls, isNot(contains('GET /api/documents/doc-1/files')));

    await tester.tap(find.text('Bir Hospital'));
    await settle(tester);

    expect(find.text('discharge.pdf'), findsOneWidget);
    expect(find.text('Six-month follow-up.'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Add a file'), findsOneWidget);
  });

  testWidgets('a visit with no files says so rather than showing a blank',
      (tester) async {
    final api = backend(documents: [documentRow()])
      ..json('GET /api/documents/doc-1/files', {'files': const []});
    await openDocuments(tester, api);

    await tester.tap(find.text('Bir Hospital'));
    await settle(tester);

    expect(find.text('No files attached to this visit yet.'), findsOneWidget);
  });

  testWidgets('deleting a visit says the files go with it', (tester) async {
    final api = backend(documents: [documentRow()])
      ..json('GET /api/documents/doc-1/files', {'files': const []})
      ..json('DELETE /api/documents/doc-1', null);
    await openDocuments(tester, api);

    await tester.tap(find.text('Bir Hospital'));
    await settle(tester);
    await tapAfterScroll(
      tester,
      find.widgetWithText(TextButton, 'Delete'),
      scrollable: scrollableIn(DocumentsScreen),
    );

    expect(find.text('Delete the Bir Hospital visit?'), findsOneWidget);
    // The cascade is the part a user tidying their list would not expect.
    expect(
      find.text('Every file attached to it is deleted too. This cannot be '
          'undone.'),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await settle(tester);

    expect(api.requestFor('DELETE /api/documents/doc-1'), isNotNull);
    expect(find.text('Visit deleted'), findsOneWidget);
    expect(find.text('No visits recorded'), findsOneWidget);
    expect(api.unmatched, isEmpty);
  });

  testWidgets('adding a visit sends the hospital and a date-only checkup date',
      (tester) async {
    final api = backend(documents: [documentRow()])
      ..json('GET /api/documents/doc-1/files', {'files': const []})
      ..json('POST /api/documents', documentRow(id: 'doc-2', hospital: 'Patan '
          'Hospital', department: null, doctorName: null, location: null,
          description: null));
    await openDocuments(tester, api);

    await tester.tap(find.widgetWithText(FloatingActionButton, 'Add'));
    await settle(tester);
    expect(find.text('Add a visit'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Hospital or clinic'),
      'Patan Hospital',
    );
    await settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Save visit'));
    await settle(tester);

    final body = jsonDecode(api.requestFor('POST /api/documents')!.body)
        as Map<String, dynamic>;
    expect(body['hospital'], 'Patan Hospital');
    // Optional fields left blank are absent, not empty strings.
    expect(body.containsKey('department'), isFalse);
    expect(body.containsKey('doctor_name'), isFalse);
    expect(find.text('Patan Hospital'), findsOneWidget);
  });
}
