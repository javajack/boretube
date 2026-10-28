import 'package:boretube_mobile/providers/tv_providers.dart';
import 'package:boretube_mobile/providers/ui_providers.dart';
import 'package:boretube_mobile/screens/settings_screen.dart';
import 'package:boretube_mobile/watch/always_on_alerts.dart';
import 'package:boretube_mobile/watch/always_on_watch.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../widget/helpers.dart';
import 'fakes.dart';

void main() {
  late FakeAlertNotifier notifier;
  late FakeScheduler scheduler;

  List<Override> alertOverrides() => [
        alertNotifierProvider.overrideWithValue(notifier),
        watchSchedulerProvider.overrideWithValue(scheduler),
      ];

  setUp(() {
    notifier = FakeAlertNotifier();
    scheduler = FakeScheduler();
  });

  Future<TestEnv> pumpSettings(
    WidgetTester tester, {
    Map<String, Object> prefs = const {},
    double textScale = 1,
  }) async {
    final env =
        await TestEnv.create(tvs: [adbSony, castOnlySony], prefs: prefs);
    await env.store.setActive(adbSony.id);
    await pumpScreen(
      tester,
      const SettingsScreen(),
      size: const Size(360, 2400),
      textScale: textScale,
      overrides: [...env.overrides(), ...alertOverrides()],
    );
    await settle(tester);
    return env;
  }

  group('Settings › Notifications', () {
    testWidgets('alerts start off; turning them on schedules the watch',
        (tester) async {
      final env = await pumpSettings(tester);
      Switch sw() => tester.widget<Switch>(
            find.byKey(const Key('settings-alerts-switch')),
          );
      expect(sw().value, isFalse);
      await tester.tap(find.byKey(const Key('settings-alerts-switch')));
      await settle(tester);
      expect(sw().value, isTrue);
      expect(env.prefs.getBool(kAlertsKey), isTrue);
      expect(scheduler.calls, ['schedule(replace)']);
      expect(find.textContaining('every 15 minutes'), findsOneWidget);

      await tester.tap(find.byKey(const Key('settings-alerts-switch')));
      await settle(tester);
      expect(env.prefs.getBool(kAlertsKey), isFalse);
      expect(scheduler.calls.last, 'cancel');
    });

    testWidgets('blocked notifications explain the fix and can ask again',
        (tester) async {
      notifier = FakeAlertNotifier(allowed: false, grant: false);
      await pumpSettings(tester, prefs: {kAlertsKey: true});
      expect(find.byKey(const Key('settings-alerts-blocked')), findsOneWidget);
      expect(find.textContaining('Notifications.'), findsOneWidget);
      await tester.tap(find.byKey(const Key('settings-alerts-ask')));
      await settle(tester);
      expect(notifier.asks, 1);
    });

    testWidgets('turning alerts on asks for permission when blocked',
        (tester) async {
      notifier = FakeAlertNotifier(allowed: false, grant: true);
      await pumpSettings(tester);
      await tester.tap(find.byKey(const Key('settings-alerts-switch')));
      await settle(tester);
      expect(notifier.asks, 1);
      expect(find.byKey(const Key('settings-alerts-blocked')), findsNothing);
    });
  });

  group('Settings layout', () {
    testWidgets('keeps every section and the Advanced extras', (tester) async {
      await pumpSettings(tester);
      for (final t in [
        'YOUR TVS',
        'LOOK',
        'PARENT PIN',
        'NOTIFICATIONS',
        'YOUR TV',
        'ABOUT AND HELP',
      ]) {
        expect(find.text(t), findsOneWidget, reason: t);
      }
      expect(find.text('Living Room TV'), findsOneWidget);
      expect(find.text('Bedroom TV'), findsOneWidget);
      expect(find.text('In use'), findsOneWidget);
      // Jargon stays behind Advanced.
      expect(find.text('ADB KEY'), findsNothing);
      await tester.tap(find.byKey(const Key('settings-advanced')));
      await settle(tester);
      expect(find.text('ADB KEY'), findsOneWidget);
      expect(find.text('BASELINE SNAPSHOT'), findsOneWidget);
      expect(find.byKey(const Key('settings-debug')), findsOneWidget);
      expect(find.textContaining(adbSony.id), findsOneWidget);
    });

    testWidgets('theme tiles switch the theme', (tester) async {
      final env = await pumpSettings(tester);
      await tester.tap(find.byKey(const Key('theme-dark')));
      await settle(tester);
      expect(env.prefs.getString('ui.theme'), 'dark');
      await tester.tap(find.byKey(const Key('settings-bedtime-dark')));
      await settle(tester);
      expect(env.prefs.getString('ui.theme'), 'bedtime');
    });

    testWidgets('fits 360 dp at 1.3× text', (tester) async {
      await pumpSettings(tester, textScale: 1.3);
      await tester.tap(find.byKey(const Key('settings-advanced')));
      await settle(tester);
      expect(tester.takeException(), isNull);
    });
  });

  group('after Always On is installed', () {
    Future<(TestEnv, WidgetRef)> pumpHost(
      WidgetTester tester, {
      Map<String, Object> prefs = const {},
    }) async {
      final env =
          await TestEnv.create(tvs: [adbSony, castOnlySony], prefs: prefs);
      late WidgetRef captured;
      await pumpScreen(
        tester,
        Consumer(
          builder: (context, ref, _) {
            captured = ref;
            return Center(
              child: FilledButton(
                onPressed: () => enableAlertsAfterInstall(context, ref),
                child: const Text('installed'),
              ),
            );
          },
        ),
        scaffold: true,
        overrides: [...env.overrides(), ...alertOverrides()],
      );
      return (env, captured);
    }

    testWidgets('defaults alerts on quietly when notifications are allowed',
        (tester) async {
      final (env, _) = await pumpHost(tester);
      await tester.tap(find.text('installed'));
      await settle(tester);
      expect(env.prefs.getBool(kAlertsKey), isTrue);
      expect(scheduler.calls, ['schedule(replace)']);
      expect(find.byKey(const Key('alerts-permission')), findsNothing);
    });

    testWidgets('explains before the Android prompt; Allow asks',
        (tester) async {
      notifier = FakeAlertNotifier(allowed: false);
      final (env, _) = await pumpHost(tester);
      await tester.tap(find.text('installed'));
      await settle(tester);
      expect(find.byKey(const Key('alerts-permission')), findsOneWidget);
      await tester.tap(find.byKey(const Key('alerts-allow')));
      await settle(tester);
      expect(notifier.asks, 1);
      expect(env.prefs.getBool(kAlertsKey), isTrue);
    });

    testWidgets('Not now turns alerts off', (tester) async {
      notifier = FakeAlertNotifier(allowed: false);
      final (env, _) = await pumpHost(tester);
      await tester.tap(find.text('installed'));
      await settle(tester);
      await tester.tap(find.byKey(const Key('alerts-not-now')));
      await settle(tester);
      expect(notifier.asks, 0);
      expect(env.prefs.getBool(kAlertsKey), isFalse);
      expect(scheduler.calls.last, 'cancel');
    });

    testWidgets('an earlier choice is respected', (tester) async {
      final (env, _) = await pumpHost(tester, prefs: {kAlertsKey: false});
      await tester.tap(find.text('installed'));
      await settle(tester);
      expect(env.prefs.getBool(kAlertsKey), isFalse);
      expect(scheduler.calls, isEmpty);
    });

    testWidgets('tapping an alert opens Better TV › Always On on that TV',
        (tester) async {
      final (env, ref) = await pumpHost(tester);
      await env.store.setActive(adbSony.id);
      openAlwaysOnAlert(ref, castOnlySony.id);
      await settle(tester, 2);
      expect(ref.read(activeTvIdProvider), castOnlySony.id);
      expect(ref.read(shellTabProvider), 2);
      expect(ref.read(betterTvFocusProvider), 'alwaysOn');
      // An unknown TV keeps the active one.
      openAlwaysOnAlert(ref, 'gone');
      expect(ref.read(activeTvIdProvider), castOnlySony.id);
    });
  });
}
