/// The medicine list as a user meets it, through the real router and the real
/// controller with only the socket scripted.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medistore/features/medicines/presentation/widgets/interaction_banner.dart';

import 'support/fake_api.dart';
import 'support/harness.dart';

/// A backend with the two calls this screen always makes, plus whatever the
/// dashboard behind it needs.
FakeApi backend({
  List<Map<String, Object?>> medicines = const [],
  List<Map<String, Object?>> interactions = const [],
  int checkedCount = 0,
}) =>
    FakeApi()
      ..json('GET /api/medicines', {'medicines': medicines})
      ..json('GET /api/vitals', {'vitals': const []})
      ..json('GET /api/medicines/interactions', {
        'interactions': interactions,
        'checked_count': checkedCount,
      })
      ..json('GET /api/medicines/intake/log', {'intakes': const []});

Map<String, Object?> interaction({
  String drugA = 'Warfarin',
  String drugB = 'Aspirin',
  String severity = 'severe',
  String description = 'Increased risk of bleeding.',
}) =>
    {
      'drug_a': drugA,
      'drug_b': drugB,
      'severity': severity,
      'description': description,
    };

Future<void> openMedicines(WidgetTester tester, FakeApi api) async {
  await pumpSignedIn(tester, api);
  await openTab(tester, 'Medicines');
}

void main() {
  testWidgets('an empty list explains what the screen is for', (tester) async {
    final api = backend();
    await openMedicines(tester, api);

    expect(find.text('No medicines yet'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Add your first medicine'),
        findsOneWidget);
    // No FAB competing with the empty state's own button.
    expect(find.byType(FloatingActionButton), findsNothing);
    // And no interaction check for a list with nothing in it — the answer is
    // knowable without asking.
    expect(api.calls, isNot(contains('GET /api/medicines/interactions')));
  });

  testWidgets('current and finished courses are separated', (tester) async {
    await openMedicines(
      tester,
      backend(
        medicines: [
          medicineRow(name: 'Amlodipine'),
          medicineRow(
            id: 'med-2',
            name: 'Amoxicillin',
            endDate: '2020-06-01',
            takingTimes: '["06:00","14:00","22:00"]',
          ),
        ],
        checkedCount: 1,
      ),
    );

    expect(find.text('CURRENTLY TAKING'), findsOneWidget);
    expect(find.text('FINISHED'), findsOneWidget);
    expect(
      find.text('Kept for your records. Not included in the interaction '
          'check.'),
      findsOneWidget,
    );
    expect(find.text('Amlodipine'), findsOneWidget);
    expect(find.text('Amoxicillin'), findsOneWidget);
  });

  testWidgets('an interaction is stated with its severity and its limits',
      (tester) async {
    await openMedicines(
      tester,
      backend(
        medicines: [medicineRow(), medicineRow(id: 'med-2', name: 'Aspirin')],
        interactions: [interaction()],
        checkedCount: 2,
      ),
    );

    expect(find.text('1 possible interaction'), findsOneWidget);
    expect(find.text('Increased risk of bleeding.'), findsOneWidget);
    // The disclaimer is carried verbatim from the web app: this is an offline
    // dataset, not a pharmacological service.
    expect(find.text(interactionDisclaimer), findsOneWidget);
    // And the count says what was actually looked at, so "nothing found"
    // cannot be read as "nothing to find".
    expect(
      find.text('Checked 2 medicines you are currently taking. Finished '
          'courses are not included.'),
      findsOneWidget,
    );
  });

  testWidgets('a failed interaction check stays quiet rather than alarming',
      (tester) async {
    // A red card where a warning would go reads as though something is wrong
    // with the medicines themselves.
    final api = FakeApi()
      ..json('GET /api/medicines', {'medicines': [medicineRow()]})
      ..json('GET /api/vitals', {'vitals': const []})
      ..fails('GET /api/medicines/interactions', 500, 'Dataset unavailable');
    await openMedicines(tester, api);

    expect(find.text('Amlodipine'), findsOneWidget);
    expect(find.byType(InteractionBanner), findsNothing);
    expect(find.textContaining('interaction'), findsNothing);
  });

  testWidgets('a corrupt taking_times still renders the medicine',
      (tester) async {
    // The column has never been validated and the server's own parser
    // swallows this. A row the phone refuses to draw would be worse than one
    // drawn without its chips.
    await openMedicines(
      tester,
      backend(
        medicines: [medicineRow(takingTimes: '["25:00", not json')],
        checkedCount: 1,
      ),
    );

    expect(find.text('Amlodipine'), findsOneWidget);
    expect(find.text('5 mg · Once daily'), findsOneWidget);
  });

  testWidgets('removing asks first, deletes softly, and offers Undo',
      (tester) async {
    final api = backend(medicines: [medicineRow()], checkedCount: 1)
      ..json('DELETE /api/medicines/med-1', null)
      ..json('POST /api/medicines/med-1/restore', medicineRow());
    await openMedicines(tester, api);

    await tester.tap(find.byTooltip('More for Amlodipine'));
    await settle(tester);
    await tester.tap(find.text('Remove'));
    await settle(tester);

    // The dialog says what "remove" actually does, because the delete is soft.
    expect(find.text('Remove Amlodipine?'), findsOneWidget);
    expect(
      find.text('It comes off your list and out of the interaction check. '
          'Your record of it is kept, and you can put it back.'),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
    await settle(tester);

    expect(api.requestFor('DELETE /api/medicines/med-1'), isNotNull);
    expect(find.text('Removed Amlodipine'), findsOneWidget);
    expect(find.text('Amlodipine'), findsNothing, reason: 'gone from the list');

    await tester.tap(find.text('Undo'));
    await settle(tester);

    // Undo restores the same row server-side, not a copy with a new id.
    expect(api.requestFor('POST /api/medicines/med-1/restore'), isNotNull);
    expect(find.text('Amlodipine'), findsOneWidget);
    expect(api.unmatched, isEmpty);
  });

  testWidgets('keeping it makes no request at all', (tester) async {
    final api = backend(medicines: [medicineRow()], checkedCount: 1);
    await openMedicines(tester, api);

    await tester.tap(find.byTooltip('More for Amlodipine'));
    await settle(tester);
    await tester.tap(find.text('Remove'));
    await settle(tester);
    await tester.tap(find.widgetWithText(TextButton, 'Keep it'));
    await settle(tester);

    expect(api.calls, isNot(contains('DELETE /api/medicines/med-1')));
    expect(find.text('Amlodipine'), findsOneWidget);
  });

  testWidgets('a caretaker\'s list and the patient\'s never share a cache',
      (tester) async {
    // Phase 6 supplies the caretaker screen; the family key is here from the
    // start so that when it arrives it adds no new code path. What must be
    // true today is that an unscoped list sends no patient_id at all.
    final api = backend(medicines: [medicineRow()], checkedCount: 1);
    await openMedicines(tester, api);

    expect(api.requestFor('GET /api/medicines')!.options.uri.query, isEmpty);
  });
}
