import 'package:boretube_mobile/ops/health.dart';
import 'package:boretube_mobile/providers/tv_providers.dart';
import 'package:boretube_mobile/screens/tv/health_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  testWidgets('renders checks, summary and Fix with confirmation',
      (tester) async {
    var fixed = 0;
    final checks = [
      const HealthCheck(
        id: 'adb',
        title: 'ADB connection',
        status: HealthStatus.ok,
        detail: 'Connected',
      ),
      HealthCheck(
        id: 'cleanup',
        title: 'Bloat cleanup',
        status: HealthStatus.warn,
        detail: '20/22 disabled (pending: a, b)',
        fix: () async => fixed++,
      ),
      HealthCheck(
        id: 'stockYouTube',
        title: 'Stock YouTube',
        status: HealthStatus.warn,
        detail: 'Installed',
        fix: () async => fixed++,
      ),
      const HealthCheck(
        id: 'launcher',
        title: 'Home launcher',
        status: HealthStatus.ok,
        detail: 'Home opens the launcher',
      ),
    ];
    final env = await TestEnv.create(tvs: [adbSony]);
    await pumpScreen(
      tester,
      const HealthSection(),
      scaffold: true,
      overrides: [
        ...env.overrides(),
        healthProvider.overrideWith((ref) async => checks),
      ],
    );
    await settle(tester);

    for (final c in checks) {
      expect(find.text(c.title), findsOneWidget);
    }
    expect(find.text('2 things need attention'), findsOneWidget);
    expect(find.byKey(const Key('health-fix-all')), findsOneWidget);
    expect(find.text('Fix'), findsNWidgets(2));

    // Cancel: nothing runs.
    await tester.tap(find.text('Fix').first);
    await settle(tester);
    expect(find.text('Fix Bloat cleanup?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await settle(tester);
    expect(fixed, 0);

    // Confirm: the fix runs and the result dialog shows.
    await tester.tap(find.text('Fix').first);
    await settle(tester);
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, 'Fix'),
      ),
    );
    await settle(tester);
    expect(fixed, 1);
    expect(find.text('Bloat cleanup fixed'), findsOneWidget);
  });

  testWidgets('all good summary', (tester) async {
    final env = await TestEnv.create(tvs: [adbSony]);
    await pumpScreen(
      tester,
      const HealthSection(),
      scaffold: true,
      overrides: [
        ...env.overrides(),
        healthProvider.overrideWith(
          (ref) async => const [
            HealthCheck(
              id: 'adb',
              title: 'ADB connection',
              status: HealthStatus.ok,
              detail: 'Connected',
            ),
          ],
        ),
      ],
    );
    await settle(tester);
    expect(find.text('All good'), findsOneWidget);
    expect(find.byKey(const Key('health-fix-all')), findsNothing);
  });

  testWidgets('TV without ADB shows the unlock tip', (tester) async {
    final env = await TestEnv.create(tvs: [castOnlySony]);
    await pumpScreen(
      tester,
      const HealthSection(),
      scaffold: true,
      overrides: env.overrides(),
    );
    await settle(tester);
    expect(find.text('Unlock with ADB'), findsOneWidget);
  });
}
