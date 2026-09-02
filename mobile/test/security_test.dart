/// The three layers that sit above every route: the medical disclaimer, the
/// biometric offer, and the lock screen a restored session opens behind.
///
/// All three are rendered as layers rather than pushed as routes, so they are
/// asserted the same way any other widget is — no navigator observers, no
/// `showDialog` timing.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ayuvo/core/security/biometric_service.dart';
import 'package:ayuvo/core/storage/local_store.dart';

import 'support/fake_api.dart';
import 'support/harness.dart';

/// A device with an enrolled sensor, and a record of what was asked of it.
class FakeBiometrics implements BiometricService {
  FakeBiometrics({
    this.available = BiometricAvailability.ready,
    this.succeeds = true,
  });

  final BiometricAvailability available;
  bool succeeds;
  int prompts = 0;

  @override
  Future<BiometricAvailability> availability() async => available;

  @override
  Future<bool> authenticate({required String reason}) async {
    prompts++;
    return succeeds;
  }
}

FakeApi backend() => FakeApi()
  ..json('GET /api/medicines', {'medicines': const []})
  ..json('GET /api/vitals', {'vitals': const []});

void main() {
  group('medical disclaimer', () {
    testWidgets('a first launch has to acknowledge it before anything else',
        (tester) async {
      await pumpSignedIn(tester, backend(), disclaimerAccepted: false);

      expect(find.text('Medical Disclaimer'), findsOneWidget);
      expect(
        find.textContaining('educational summaries of your health records'),
        findsOneWidget,
      );
      expect(find.widgetWithText(FilledButton, 'I understand'), findsOneWidget);
    });

    testWidgets('tapping outside it does nothing; the button dismisses it',
        (tester) async {
      await pumpSignedIn(tester, backend(), disclaimerAccepted: false);

      // The scrim is the whole screen and swallows the tap without closing.
      await tester.tapAt(const Offset(10, 10));
      await settle(tester);
      expect(find.text('Medical Disclaimer'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'I understand'));
      await settle(tester);
      expect(find.text('Medical Disclaimer'), findsNothing);
    });

    testWidgets('an acknowledgement already on disk is not asked for again',
        (tester) async {
      await pumpSignedIn(tester, backend());
      expect(find.text('Medical Disclaimer'), findsNothing);
    });
  });

  group('biometric offer', () {
    testWidgets('a phone with an enrolled sensor is offered faster sign-in',
        (tester) async {
      final biometrics = FakeBiometrics();
      await pumpSignedIn(tester, backend(), biometrics: biometrics);

      expect(find.text('Faster sign-in'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Turn it on'));
      await settle(tester);
      expect(find.text('Faster sign-in'), findsNothing);
    });

    testWidgets('a phone with no sensor is never offered it', (tester) async {
      await pumpSignedIn(tester, backend());
      expect(find.text('Faster sign-in'), findsNothing);
    });

    testWidgets('declining is remembered, so it is asked exactly once',
        (tester) async {
      final store = InMemoryLocalStore();
      await pumpSignedIn(
        tester,
        backend(),
        store: store,
        biometrics: FakeBiometrics(),
      );

      await tester.tap(find.widgetWithText(TextButton, 'Not now'));
      await settle(tester);
      expect(find.text('Faster sign-in'), findsNothing);
      // The answer is on disk, not merely in this widget's state.
      expect(store.contents['security.v1'], contains('"biometric_asked":true'));
    });

    testWidgets('the offer waits behind the disclaimer', (tester) async {
      await pumpSignedIn(
        tester,
        backend(),
        disclaimerAccepted: false,
        biometrics: FakeBiometrics(),
      );

      expect(find.text('Medical Disclaimer'), findsOneWidget);
      expect(find.text('Faster sign-in'), findsNothing);
    });
  });

  group('launch lock', () {
    /// A store that already has biometrics turned on, as a returning user's
    /// would.
    Future<InMemoryLocalStore> unlockedStore() async {
      final store = InMemoryLocalStore();
      await store.write(
        'security.v1',
        '{"biometric_enabled":true,"biometric_asked":true,'
            '"disclaimer_accepted":true}',
      );
      return store;
    }

    testWidgets('a restored session opens locked and prompts once',
        (tester) async {
      final biometrics = FakeBiometrics();
      await pumpSignedIn(
        tester,
        backend(),
        store: await unlockedStore(),
        biometrics: biometrics,
      );

      expect(biometrics.prompts, 1);
      // The scan succeeded, so the lock is already gone.
      expect(find.text('Ayuvo is locked'), findsNothing);
    });

    testWidgets('a failed scan leaves the record covered, not open',
        (tester) async {
      final biometrics = FakeBiometrics(succeeds: false);
      await pumpSignedIn(
        tester,
        backend(),
        store: await unlockedStore(),
        biometrics: biometrics,
      );

      expect(find.text('Ayuvo is locked'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Use my password instead'),
          findsOneWidget);
    });

    testWidgets('the password is always the way out', (tester) async {
      await pumpSignedIn(
        tester,
        backend(),
        store: await unlockedStore(),
        biometrics: FakeBiometrics(succeeds: false),
      );

      await tester.tap(
        find.widgetWithText(TextButton, 'Use my password instead'),
      );
      await settle(tester);

      expect(find.text('Ayuvo is locked'), findsNothing);
      expect(find.widgetWithText(FilledButton, 'Sign in'), findsWidgets);
    });

    testWidgets('biometrics off means no lock and no prompt', (tester) async {
      final biometrics = FakeBiometrics();
      await pumpSignedIn(tester, backend(), biometrics: biometrics);

      expect(find.text('Ayuvo is locked'), findsNothing);
      expect(biometrics.prompts, 0);
    });
  });
}
