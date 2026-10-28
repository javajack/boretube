import 'package:boretube_mobile/adb/adb_identity.dart';
import 'package:boretube_mobile/app.dart';
import 'package:boretube_mobile/security/app_lock.dart';
import 'package:boretube_mobile/security/pin_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../widget/helpers.dart';

void main() {
  group('PinStore', () {
    test('salted hash: same PIN, different stored values', () async {
      final a = PinStore(store: MemorySecretStore());
      final b = PinStore(store: MemorySecretStore());
      await a.setPin('1234');
      await b.setPin('1234');
      expect(
        a.store is MemorySecretStore &&
            (a.store as MemorySecretStore).values[PinStore.storageKey] !=
                (b.store as MemorySecretStore).values[PinStore.storageKey],
        isTrue,
      );
      expect(await a.verify('1234'), isTrue);
      expect(await a.verify('1235'), isFalse);
    });

    test('accepts 4–6 digits only', () async {
      final s = PinStore(store: MemorySecretStore());
      for (final bad in ['123', '1234567', '12a4', '']) {
        expect(PinStore.isValid(bad), isFalse, reason: bad);
        expect(() => s.setPin(bad), throwsArgumentError);
      }
      expect(PinStore.isValid('123456'), isTrue);
      expect(await s.hasPin(), isFalse);
    });

    test('corrupt stored value never verifies', () async {
      final mem = MemorySecretStore()..values[PinStore.storageKey] = 'x';
      expect(await PinStore(store: mem).verify('1234'), isFalse);
    });
  });

  group('AppLockController', () {
    late SharedPreferences prefs;
    late PinStore pins;
    var now = DateTime(2026, 10, 28, 19);

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      pins = PinStore(store: MemorySecretStore());
      now = DateTime(2026, 10, 28, 19);
    });

    Future<AppLockController> make() async {
      final c = AppLockController(
        pins: pins,
        prefs: prefs,
        biometric: FakeBiometric(),
        clock: () => now,
      );
      await Future<void>.delayed(Duration.zero);
      return c;
    }

    test('no PIN → setup; PIN → locked on cold start', () async {
      expect((await make()).state.phase, LockPhase.setup);
      await pins.setPin('1111');
      expect((await make()).state.phase, LockPhase.locked);
    });

    test('relocks after 5 minutes in the background', () async {
      await pins.setPin('1111');
      final c = await make();
      await c.unlock('1111');
      c.onBackground();
      now = now.add(const Duration(minutes: 4));
      c.onForeground();
      expect(c.state.phase, LockPhase.unlocked);
      c.onBackground();
      now = now.add(const Duration(minutes: 5));
      c.onForeground();
      expect(c.state.phase, LockPhase.locked);
    });

    test('cools down after 5 wrong PINs', () async {
      await pins.setPin('1111');
      final c = await make();
      for (var i = 0; i < 5; i++) {
        expect(await c.unlock('0000'), isFalse);
      }
      expect(c.coolingDown, isTrue);
      expect(await c.unlock('1111'), isFalse);
      now = now.add(const Duration(seconds: 31));
      expect(await c.unlock('1111'), isTrue);
    });

    test('changePin needs the current PIN', () async {
      await pins.setPin('1111');
      final c = await make();
      expect(await c.changePin('2222', '3333'), isFalse);
      expect(await c.changePin('1111', '3333'), isTrue);
      expect(await pins.verify('3333'), isTrue);
    });
  });

  group('appRedirect', () {
    String? r(LockPhase p, bool tvs, String loc) =>
        appRedirect(phase: p, hasTvs: tvs, location: loc);

    test('locked always goes to /lock', () {
      expect(r(LockPhase.locked, true, '/'), '/lock');
      expect(r(LockPhase.locked, false, '/onboarding'), '/lock');
      expect(r(LockPhase.locked, true, '/lock'), isNull);
    });

    test('first run: onboarding, or PIN setup for migrated v1 users', () {
      expect(r(LockPhase.setup, false, '/'), '/onboarding');
      expect(r(LockPhase.setup, true, '/'), '/setup-pin');
      // Saving a TV mid-onboarding doesn't kick you out.
      expect(r(LockPhase.setup, true, '/onboarding'), isNull);
    });

    test('unlocked: gates bounce home; no TVs → onboarding', () {
      expect(r(LockPhase.unlocked, true, '/lock'), '/');
      expect(r(LockPhase.unlocked, true, '/whitelist'), isNull);
      expect(r(LockPhase.unlocked, false, '/'), '/onboarding');
      expect(r(LockPhase.loading, true, '/'), '/splash');
    });
  });
}
