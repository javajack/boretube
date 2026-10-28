import 'package:boretube_mobile/actions/actions_service.dart';
import 'package:boretube_mobile/providers/ui_providers.dart';
import 'package:boretube_mobile/screens/onboarding_screen.dart';
import 'package:boretube_mobile/tv/tv.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

const found = [
  Tv(
    id: 'udn:4506a0af',
    name: 'Living Room TV',
    manufacturer: 'Sony',
    model: 'BRAVIA VU3',
    ip: '192.168.1.3',
  ),
  Tv(
    id: 'udn:9911',
    name: 'Bedroom TV',
    manufacturer: 'TCL',
    model: 'C645',
    ip: '192.168.1.7',
  ),
];

const ok = ActionResult(true, ActionTransport.cast);

void main() {
  testWidgets('Find step lists discovered TVs, then says hi to the pick',
      (tester) async {
    final env = await TestEnv.create();
    await pumpScreen(
      tester,
      const OnboardingScreen(addMode: true),
      overrides: env.overrides(
        discovery: FakeDiscovery(found),
        probeCaps: {TvCapability.cast, TvCapability.dial},
      ),
    );
    await settle(tester);

    expect(find.text('Find your TV'), findsOneWidget);
    expect(find.text('Living Room TV'), findsOneWidget);
    expect(find.text('Bedroom TV'), findsOneWidget);
    expect(find.text('Sony BRAVIA VU3 · 192.168.1.3'), findsOneWidget);
    expect(find.byKey(const Key('enter-ip')), findsOneWidget);

    await tester.tap(find.text('Living Room TV'));
    await settle(tester, 10);
    expect(find.text('Say hi to your TV'), findsOneWidget);
    expect(find.text('Sony · found on your Wi-Fi'), findsOneWidget);
    // The probed TV is saved and active.
    expect(env.store.active?.id, 'udn:4506a0af');
    expect(env.store.active?.can(TvCapability.cast), isTrue);
  });

  testWidgets('first win: one tap mutes, celebrates, then Unmute',
      (tester) async {
    final env = await TestEnv.create();
    final actions = ScriptedActions(found.first);
    await pumpScreen(
      tester,
      const OnboardingScreen(addMode: true),
      overrides: env.overrides(
        discovery: FakeDiscovery(found),
        probeCaps: {TvCapability.cast},
        actions: actions,
      ),
    );
    await settle(tester);
    await tester.tap(find.text('Living Room TV'));
    await settle(tester, 10);

    await tester.tap(find.byKey(const Key('first-win-mute')));
    await tester.pump();
    expect(actions.calls, ['mute']);
    actions.answer(ok);
    await settle(tester, 4);
    expect(find.text('Your TV listened!'), findsOneWidget);
    expect(find.text('Muted'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
    expect(env.prefs.getBool('ui.moment.${Moments.firstWin}'), isTrue);

    await tester.ensureVisible(find.text('Unmute'));
    await tester.tap(find.text('Unmute'));
    await tester.pump();
    expect(actions.calls, ['mute', 'unmute']);
    actions.answer(ok);
    // Let the confetti finish.
    await settle(tester, 25);
    expect(find.textContaining('Sound is back'), findsOneWidget);
  });

  testWidgets('first win: a refusal says why and keeps the button',
      (tester) async {
    final env = await TestEnv.create();
    final actions = ScriptedActions(found.first);
    await pumpScreen(
      tester,
      const OnboardingScreen(addMode: true),
      overrides: env.overrides(
        discovery: FakeDiscovery(found),
        probeCaps: {TvCapability.cast},
        actions: actions,
      ),
    );
    await settle(tester);
    await tester.tap(find.text('Living Room TV'));
    await settle(tester, 10);
    await tester.tap(find.byKey(const Key('first-win-mute')));
    await tester.pump();
    actions.answer(const ActionResult(false, ActionTransport.cast));
    await settle(tester, 4);
    expect(find.text('The TV didn\'t answer. Is it on?'), findsOneWidget);
    expect(find.text('Your TV listened!'), findsNothing);
    expect(find.text('Skip this'), findsOneWidget);
  });

  testWidgets('a TV that answers nothing gets "Try again"', (tester) async {
    final env = await TestEnv.create();
    await pumpScreen(
      tester,
      const OnboardingScreen(addMode: true),
      overrides: env.overrides(discovery: FakeDiscovery(found)),
    );
    await settle(tester);
    await tester.tap(find.text('Living Room TV'));
    await settle(tester, 10);
    expect(find.text('Your TV is shy'), findsOneWidget);
    expect(find.byKey(const Key('first-win-retry')), findsOneWidget);
  });

  testWidgets('first run: welcome, find, first win, goals (stored)',
      (tester) async {
    final env = await TestEnv.create();
    await pumpScreen(
      tester,
      const OnboardingScreen(),
      overrides: env.overrides(
        discovery: FakeDiscovery(found),
        probeCaps: {TvCapability.cast},
      ),
    );
    await settle(tester);
    expect(find.text('Calmer TV,\nin a few minutes.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('onboarding-start')));
    await settle(tester);
    await tester.tap(find.text('Living Room TV'));
    await settle(tester, 10);
    await tester.ensureVisible(find.byKey(const Key('first-win-continue')));
    await tester.tap(find.byKey(const Key('first-win-continue')));
    await settle(tester);
    // No PIN step: the lock isn't in setup in tests.
    expect(find.text('What\'s bugging you about TV time?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('goal-bedtime')));
    await tester.tap(find.byKey(const Key('goal-shorts')));
    await settle(tester, 2);
    expect(find.text('Show my calm-TV plan'), findsOneWidget);
    await tester.tap(find.byKey(const Key('goals-done')));
    await settle(tester, 2);
    expect(env.prefs.getStringList(GoalsNotifier.key), ['bedtime', 'shorts']);
  });

  testWidgets('no TVs found offers manual entry', (tester) async {
    final env = await TestEnv.create();
    await pumpScreen(
      tester,
      const OnboardingScreen(addMode: true),
      overrides: env.overrides(discovery: FakeDiscovery(const [])),
    );
    await settle(tester);
    expect(find.text('No TVs found'), findsOneWidget);
    await tester.tap(find.byKey(const Key('enter-ip')));
    await settle(tester);
    await tester.enterText(find.byKey(const Key('tv-ip')), '192.168.1.40');
    await tester.tap(find.text('Save'));
    await settle(tester, 10);
    expect(env.store.active?.ip, '192.168.1.40');
  });
}
