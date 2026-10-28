import 'package:boretube_mobile/providers/now_playing.dart';
import 'package:boretube_mobile/screens/now/now_tab.dart';
import 'package:boretube_mobile/screens/now/quick_actions.dart';
import 'package:boretube_mobile/tv/tv.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

const playing = NowPlaying(
  online: true,
  id: 'org.smarttube.stable',
  appName: 'SmartTube',
  volume: 24,
  muted: false,
  source: 'adb',
);

Finder key(String k) => find.byKey(Key(k), skipOffstage: false);

void main() {
  group('supportedActions', () {
    test('Cast-only Sony: no volume (Cast volume is wrong there)', () {
      expect(supportedActions(castOnlySony), {
        QuickAction.mute,
        QuickAction.stop,
        QuickAction.bore,
        QuickAction.takeBreak,
        QuickAction.restore,
      });
    });

    test('Cast-only non-Sony TV gets Cast volume', () {
      const tv = Tv(
        id: 'udn:x',
        name: 'Other',
        manufacturer: 'TCL',
        ip: '10.0.0.5',
        capabilities: {TvCapability.cast},
      );
      expect(supportedActions(tv), contains(QuickAction.volume));
    });

    test('ADB TV gets everything', () {
      expect(supportedActions(adbSony), QuickAction.values.toSet());
    });

    test('unprobed TV gets nothing', () {
      const tv = Tv(id: 'ip:1.2.3.4', name: 'TV', ip: '1.2.3.4');
      expect(supportedActions(tv), isEmpty);
    });
  });

  testWidgets('Cast-only TV: no volume slider, shows Unlock with ADB tip',
      (tester) async {
    final env = await TestEnv.create(tvs: [castOnlySony]);
    await pumpScreen(
      tester,
      const NowTab(),
      scaffold: true,
      overrides: env.overrides(now: playing),
    );
    await settle(tester);

    expect(key('action-mute'), findsOneWidget);
    expect(key('action-stop'), findsOneWidget);
    expect(key('action-bore'), findsOneWidget);
    expect(key('action-break'), findsOneWidget);
    expect(key('action-restore'), findsOneWidget);
    expect(key('action-volume'), findsNothing);
    expect(key('adb-tip'), findsOneWidget);
    expect(find.text('Cast apps only'), findsOneWidget);
    expect(find.text('SmartTube'), findsOneWidget);
  });

  testWidgets('ADB TV: volume slider, no tip', (tester) async {
    final env = await TestEnv.create(tvs: [adbSony]);
    await pumpScreen(
      tester,
      const NowTab(),
      scaffold: true,
      overrides: env.overrides(now: playing),
    );
    await settle(tester);

    for (final k in [
      'action-mute',
      'action-stop',
      'action-bore',
      'action-break',
      'action-restore',
      'action-volume',
    ]) {
      expect(key(k), findsOneWidget, reason: k);
    }
    expect(key('adb-tip'), findsNothing);
  });

  testWidgets('muted TV shows an Unmute tile and offline shows last seen',
      (tester) async {
    final env = await TestEnv.create(tvs: [adbSony]);
    await pumpScreen(
      tester,
      const NowTab(),
      scaffold: true,
      overrides: env.overrides(
        now: const NowPlaying(
          online: true,
          appName: 'Home screen',
          isHome: true,
          volume: 10,
          muted: true,
          source: 'cast',
        ),
      ),
    );
    await settle(tester);
    expect(find.text('Unmute'), findsOneWidget);
    expect(find.text('Muted'), findsWidgets);
  });

  testWidgets('offline TV says when it was last seen', (tester) async {
    final env = await TestEnv.create(tvs: [adbSony]);
    await pumpScreen(
      tester,
      const NowTab(),
      scaffold: true,
      overrides: env.overrides(
        now: NowPlaying(
          lastSeen: DateTime.now().subtract(const Duration(minutes: 7)),
        ),
      ),
    );
    await settle(tester);
    expect(find.text('TV is off or out of reach'), findsOneWidget);
    expect(find.text('Last seen 7 min ago'), findsOneWidget);
  });

  testWidgets('Now tab fits a 360dp phone at 1.3× text', (tester) async {
    final env = await TestEnv.create(tvs: [adbSony]);
    await pumpScreen(
      tester,
      const NowTab(),
      scaffold: true,
      textScale: 1.3,
      overrides: env.overrides(now: playing),
    );
    await settle(tester);
    expect(tester.takeException(), isNull);
  });
}
