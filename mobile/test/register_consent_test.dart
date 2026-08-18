/// Sign-up demands explicit consent.
///
/// The Create account button stays disabled until the Terms/Privacy checkbox
/// is ticked, and both links open their screens — a passive "by registering
/// you agree" line is not consent.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medistore/app.dart';
import 'package:medistore/core/health/health_providers.dart';
import 'package:medistore/core/network/network_providers.dart';
import 'package:medistore/core/notifications/reminders.dart';
import 'package:medistore/core/session/session_controller.dart';
import 'package:medistore/core/storage/local_store.dart';
import 'package:medistore/core/storage/session_store.dart';
import 'package:medistore/features/auth/data/auth_repository.dart';
import 'package:medistore/features/legal/presentation/privacy_screen.dart';
import 'package:medistore/features/legal/presentation/terms_screen.dart';

import 'support/fake_api.dart';
import 'support/fakes.dart';
import 'support/harness.dart';

Future<void> pumpToRegister(WidgetTester tester) async {
  final api = FakeApi()
    ..json('GET /api/medicines', {'medicines': const []})
    ..json('GET /api/vitals', {'vitals': const []});
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sessionStoreProvider.overrideWithValue(InMemorySessionStore(null)),
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
      child: const MediStoreApp(),
    ),
  );
  await settle(tester);
  await tester.tap(find.widgetWithText(TextButton, 'Create an account'));
  await settle(tester);
}

/// Taps the exact coordinates of one link inside the consent RichText — the
/// recognizer only fires on the span itself, not on the surrounding sentence.
Future<void> tapLink(WidgetTester tester, String linkText) async {
  final richText = tester.widget<RichText>(
    find.byKey(const ValueKey('consent-text')),
  );
  final root = richText.text as TextSpan;
  var full = '';
  var start = 0;
  var end = 0;
  for (final child in root.children!) {
    final s = (child as TextSpan).text!;
    if (s == linkText) {
      start = full.length;
      end = full.length + s.length;
    }
    full += s;
  }
  final rect = tester.getRect(find.byKey(const ValueKey('consent-text')));
  // The painter must lay out at the widget's real width or wrapped lines
  // land at the wrong coordinates.
  final painter = TextPainter(text: richText.text, textDirection: TextDirection.ltr)
    ..layout(maxWidth: rect.width);
  // Glyph boxes carry the span's true position, wrapped lines included.
  final box = painter
      .getBoxesForSelection(TextSelection(baseOffset: start, extentOffset: end))
      .first;
  await tester.tapAt(rect.topLeft + Offset(
    (box.left + box.right) / 2,
    (box.top + box.bottom) / 2,
  ));
}

void main() {
  testWidgets('Create account stays disabled until the consent checkbox',
      (tester) async {
    await pumpToRegister(tester);

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Create account'),
    );
    expect(button.onPressed, isNull);

    await tester.tap(find.byType(Checkbox));
    await settle(tester);

    final enabled = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Create account'),
    );
    expect(enabled.onPressed, isNotNull);
  });

  testWidgets('tapping Terms of Service opens the screen', (tester) async {
    await pumpToRegister(tester);

    await tapLink(tester, 'Terms of Service');
    await settle(tester);
    expect(find.byType(TermsScreen), findsOneWidget);
  });

  testWidgets('tapping Privacy Policy opens the screen', (tester) async {
    await pumpToRegister(tester);

    await tapLink(tester, 'Privacy Policy');
    await settle(tester);
    expect(find.byType(PrivacyScreen), findsOneWidget);
  });
}