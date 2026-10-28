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

void main() {
  testWidgets('Find step lists discovered TVs, then probes the pick',
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
    expect(find.text('Checking the TV'), findsOneWidget);
    expect(find.text('Unlock ADB (recommended)'), findsOneWidget);
    // The probed TV is saved and active.
    expect(env.store.active?.id, 'udn:4506a0af');
    expect(env.store.active?.can(TvCapability.cast), isTrue);
  });

  testWidgets('first run starts with the welcome screen', (tester) async {
    final env = await TestEnv.create();
    await pumpScreen(
      tester,
      const OnboardingScreen(),
      overrides: env.overrides(discovery: FakeDiscovery(found)),
    );
    await settle(tester);
    expect(find.text('Get started'), findsOneWidget);
    await tester.tap(find.byKey(const Key('onboarding-start')));
    await settle(tester);
    expect(find.text('Living Room TV'), findsOneWidget);
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
