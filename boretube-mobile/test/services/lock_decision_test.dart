import 'package:flutter_test/flutter_test.dart';

import 'package:boretube_mobile/models/tv_status.dart';
import 'package:boretube_mobile/models/whitelist_entry.dart';
import 'package:boretube_mobile/services/lock_decision.dart';

void main() {
  const backdrop = WhitelistEntry.backdrop;
  const youtube = WhitelistEntry(
    appId: 'CC1AD845',
    friendlyName: 'YouTube',
  );
  final whitelist = [backdrop, youtube];

  group('LockDecision.evaluate — timer', () {
    test('expired when remaining <= 0', () {
      final d = LockDecision.evaluate(
        remainingSeconds: 0,
        status: const TvStatus(
          volume: 10,
          muted: false,
          appId: '',
          appName: '',
          isIdle: true,
        ),
        lockApps: true,
        lockVolume: true,
        maxVolume: 15,
        whitelist: whitelist,
      );
      expect(d.action, LockAction.expired);
    });

    test('expired when remaining negative', () {
      final d = LockDecision.evaluate(
        remainingSeconds: -5,
        status: null,
        lockApps: false,
        lockVolume: false,
        maxVolume: 15,
        whitelist: whitelist,
      );
      expect(d.action, LockAction.expired);
    });
  });

  group('LockDecision.evaluate — TV offline', () {
    test('tvOffline when status is null', () {
      final d = LockDecision.evaluate(
        remainingSeconds: 300,
        status: null,
        lockApps: true,
        lockVolume: true,
        maxVolume: 15,
        whitelist: whitelist,
      );
      expect(d.action, LockAction.tvOffline);
    });
  });

  group('LockDecision.evaluate — app lock', () {
    test(
      'bore when non-whitelisted app running',
      () {
        final d = LockDecision.evaluate(
          remainingSeconds: 300,
          status: const TvStatus(
            volume: 10,
            muted: false,
            appId: 'NETFLIX_ID',
            appName: 'Netflix',
            isIdle: false,
          ),
          lockApps: true,
          lockVolume: false,
          maxVolume: 15,
          whitelist: whitelist,
        );
        expect(d.action, LockAction.bore);
        expect(d.message, contains('STOPPED'));
        expect(d.message, contains('Netflix'));
      },
    );

    test(
      'ok when whitelisted app running',
      () {
        final d = LockDecision.evaluate(
          remainingSeconds: 300,
          status: const TvStatus(
            volume: 10,
            muted: false,
            appId: 'CC1AD845',
            appName: 'YouTube',
            isIdle: false,
          ),
          lockApps: true,
          lockVolume: false,
          maxVolume: 15,
          whitelist: whitelist,
        );
        expect(d.action, LockAction.ok);
        expect(d.message, contains('whitelisted'));
      },
    );

    test(
      'ok when TV is idle (even with lockApps)',
      () {
        final d = LockDecision.evaluate(
          remainingSeconds: 300,
          status: const TvStatus(
            volume: 10,
            muted: false,
            appId: 'E8C28D3C',
            appName: 'Backdrop',
            isIdle: true,
          ),
          lockApps: true,
          lockVolume: false,
          maxVolume: 15,
          whitelist: whitelist,
        );
        expect(d.action, LockAction.ok);
        expect(d.message, contains('idle'));
      },
    );

    test(
      'no bore when lockApps is false',
      () {
        final d = LockDecision.evaluate(
          remainingSeconds: 300,
          status: const TvStatus(
            volume: 10,
            muted: false,
            appId: 'NETFLIX_ID',
            appName: 'Netflix',
            isIdle: false,
          ),
          lockApps: false,
          lockVolume: false,
          maxVolume: 15,
          whitelist: whitelist,
        );
        expect(d.action, LockAction.ok);
      },
    );
  });

  group('LockDecision.evaluate — volume lock', () {
    test(
      'capVolume when volume exceeds max',
      () {
        final d = LockDecision.evaluate(
          remainingSeconds: 300,
          status: const TvStatus(
            volume: 50,
            muted: false,
            appId: 'CC1AD845',
            appName: 'YouTube',
            isIdle: false,
          ),
          lockApps: false,
          lockVolume: true,
          maxVolume: 15,
          whitelist: whitelist,
        );
        expect(d.action, LockAction.capVolume);
        expect(d.message, contains('50%'));
      },
    );

    test(
      'ok when volume equals max (boundary)',
      () {
        final d = LockDecision.evaluate(
          remainingSeconds: 300,
          status: const TvStatus(
            volume: 15,
            muted: false,
            appId: '',
            appName: '',
            isIdle: true,
          ),
          lockApps: false,
          lockVolume: true,
          maxVolume: 15,
          whitelist: whitelist,
        );
        expect(d.action, LockAction.ok);
      },
    );

    test(
      'ok when volume below max',
      () {
        final d = LockDecision.evaluate(
          remainingSeconds: 300,
          status: const TvStatus(
            volume: 10,
            muted: false,
            appId: '',
            appName: '',
            isIdle: true,
          ),
          lockApps: false,
          lockVolume: true,
          maxVolume: 15,
          whitelist: whitelist,
        );
        expect(d.action, LockAction.ok);
      },
    );

    test(
      'skip cap when muted (even if volume high)',
      () {
        final d = LockDecision.evaluate(
          remainingSeconds: 300,
          status: const TvStatus(
            volume: 100,
            muted: true,
            appId: '',
            appName: '',
            isIdle: true,
          ),
          lockApps: false,
          lockVolume: true,
          maxVolume: 15,
          whitelist: whitelist,
        );
        expect(d.action, LockAction.ok);
        expect(d.message, contains('MUTED'));
      },
    );

    test(
      'no cap when lockVolume is false',
      () {
        final d = LockDecision.evaluate(
          remainingSeconds: 300,
          status: const TvStatus(
            volume: 100,
            muted: false,
            appId: '',
            appName: '',
            isIdle: true,
          ),
          lockApps: false,
          lockVolume: false,
          maxVolume: 15,
          whitelist: whitelist,
        );
        expect(d.action, LockAction.ok);
      },
    );
  });

  group(
    'LockDecision.evaluate — app lock takes '
    'priority over volume lock',
    () {
      test(
        'bore fires before capVolume for '
        'non-whitelisted app with high volume',
        () {
          final d = LockDecision.evaluate(
            remainingSeconds: 300,
            status: const TvStatus(
              volume: 100,
              muted: false,
              appId: 'NETFLIX_ID',
              appName: 'Netflix',
              isIdle: false,
            ),
            lockApps: true,
            lockVolume: true,
            maxVolume: 15,
            whitelist: whitelist,
          );
          // App lock takes priority — bore, don't cap
          expect(d.action, LockAction.bore);
        },
      );

      test(
        'capVolume for whitelisted app with '
        'high volume',
        () {
          final d = LockDecision.evaluate(
            remainingSeconds: 300,
            status: const TvStatus(
              volume: 50,
              muted: false,
              appId: 'CC1AD845',
              appName: 'YouTube',
              isIdle: false,
            ),
            lockApps: true,
            lockVolume: true,
            maxVolume: 15,
            whitelist: whitelist,
          );
          expect(d.action, LockAction.capVolume);
        },
      );
    },
  );

  group('LockDecision.evaluate — edge cases', () {
    test('empty whitelist — all apps get bored', () {
      final d = LockDecision.evaluate(
        remainingSeconds: 300,
        status: const TvStatus(
          volume: 10,
          muted: false,
          appId: 'CC1AD845',
          appName: 'YouTube',
          isIdle: false,
        ),
        lockApps: true,
        lockVolume: false,
        maxVolume: 15,
        whitelist: const [],
      );
      expect(d.action, LockAction.bore);
    });

    test(
      'empty appName shows idle label in capVolume',
      () {
        final d = LockDecision.evaluate(
          remainingSeconds: 300,
          status: const TvStatus(
            volume: 50,
            muted: false,
            appId: '',
            appName: '',
            isIdle: true,
          ),
          lockApps: false,
          lockVolume: true,
          maxVolume: 15,
          whitelist: whitelist,
        );
        expect(d.action, LockAction.capVolume);
        expect(d.message, contains('idle'));
      },
    );

    test('maxVolume of 0 — any volume triggers cap', () {
      final d = LockDecision.evaluate(
        remainingSeconds: 300,
        status: const TvStatus(
          volume: 1,
          muted: false,
          appId: '',
          appName: '',
          isIdle: true,
        ),
        lockApps: false,
        lockVolume: true,
        maxVolume: 0,
        whitelist: whitelist,
      );
      expect(d.action, LockAction.capVolume);
    });

    test('maxVolume of 100 — nothing triggers cap', () {
      final d = LockDecision.evaluate(
        remainingSeconds: 300,
        status: const TvStatus(
          volume: 100,
          muted: false,
          appId: '',
          appName: '',
          isIdle: true,
        ),
        lockApps: false,
        lockVolume: true,
        maxVolume: 100,
        whitelist: whitelist,
      );
      expect(d.action, LockAction.ok);
    });
  });
}
