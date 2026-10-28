import 'package:boretube_mobile/providers/security_providers.dart';
import 'package:boretube_mobile/screens/lock_screen.dart';
import 'package:boretube_mobile/security/app_lock.dart';
import 'package:boretube_mobile/security/pin_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

Future<void> enter(WidgetTester tester, String pin) async {
  for (final d in pin.split('')) {
    await tester.tap(find.byKey(Key('pin-key-$d')));
    await tester.pump();
  }
  await tester.tap(find.byKey(const Key('pin-key-Enter')));
  await settle(tester);
}

AppLockState lockState(WidgetTester tester) {
  final c = ProviderScope.containerOf(
    tester.element(find.byType(Scaffold).first),
  );
  return c.read(appLockProvider);
}

void main() {
  testWidgets('first run: choose PIN, confirm, unlocks', (tester) async {
    final env = await TestEnv.create();
    await pumpScreen(
      tester,
      const SetupPinScreen(),
      overrides: env.overrides(),
    );
    lockState(tester); // the router reads it at startup
    await settle(tester);
    expect(lockState(tester).phase, LockPhase.setup);
    expect(find.text('Choose a parent PIN'), findsOneWidget);

    await enter(tester, '2468');
    expect(find.text('Enter it again'), findsOneWidget);
    await enter(tester, '2468');

    expect(lockState(tester).phase, LockPhase.unlocked);
    expect(await PinStore(store: env.secrets).verify('2468'), isTrue);
    // Stored hashed, never in plain text.
    final raw = env.secrets.values[PinStore.storageKey]!;
    expect(raw, isNot(contains('2468')));
    expect(raw, startsWith('v1:'));
  });

  testWidgets('mismatched confirmation starts over', (tester) async {
    final env = await TestEnv.create();
    await pumpScreen(
      tester,
      const SetupPinScreen(),
      overrides: env.overrides(),
    );
    lockState(tester);
    await settle(tester);
    await enter(tester, '1234');
    await enter(tester, '4321');
    expect(find.text('PINs didn\'t match. Start again.'), findsOneWidget);
    expect(find.text('Choose a parent PIN'), findsOneWidget);
    expect(lockState(tester).phase, LockPhase.setup);
  });

  testWidgets('too short a PIN is refused', (tester) async {
    final env = await TestEnv.create();
    await pumpScreen(
      tester,
      const SetupPinScreen(),
      overrides: env.overrides(),
    );
    await settle(tester);
    await enter(tester, '12');
    expect(find.text('Use 4–6 digits'), findsOneWidget);
  });

  testWidgets('lock screen: wrong PIN shakes, right PIN unlocks',
      (tester) async {
    final env = await TestEnv.create();
    await PinStore(store: env.secrets).setPin('1357');
    await pumpScreen(tester, const LockScreen(), overrides: env.overrides());
    await settle(tester);
    expect(lockState(tester).phase, LockPhase.locked);
    expect(find.text('Use fingerprint'), findsNothing);

    await enter(tester, '0000');
    expect(find.text('Wrong PIN'), findsOneWidget);
    expect(lockState(tester).phase, LockPhase.locked);
    expect(lockState(tester).failedAttempts, 1);

    await enter(tester, '1357');
    expect(lockState(tester).phase, LockPhase.unlocked);
  });

  testWidgets('biometric unlock when enabled', (tester) async {
    final bio = FakeBiometric(available: true, result: true);
    final env = await TestEnv.create(
      biometric: bio,
      prefs: {AppLockController.biometricKey: true},
    );
    await PinStore(store: env.secrets).setPin('1357');
    await pumpScreen(tester, const LockScreen(), overrides: env.overrides());
    await settle(tester);
    expect(find.text('Use fingerprint'), findsOneWidget);
    // The lock screen asks for the fingerprint as soon as it shows.
    expect(bio.calls, greaterThanOrEqualTo(1));
    expect(lockState(tester).phase, LockPhase.unlocked);
  });
}
