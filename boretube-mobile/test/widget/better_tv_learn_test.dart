import 'package:boretube_mobile/learn/learn_installer.dart';
import 'package:boretube_mobile/ops/health.dart';
import 'package:boretube_mobile/providers/learn_providers.dart';
import 'package:boretube_mobile/providers/tv_providers.dart';
import 'package:boretube_mobile/screens/better_tv_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../learn/learn_installer_test.dart' show FakeLearnTv, bundle;
import 'better_tv_test.dart' show noAgent;
import 'helpers.dart';

void main() {
  late FakeLearnTv tv;
  setUp(() => tv = FakeLearnTv());

  Future<void> pump(WidgetTester tester) async {
    final env = await TestEnv.create(tvs: [adbSony]);
    await pumpScreen(
      tester,
      const BetterTvTab(),
      scaffold: true,
      size: const Size(360, 1600),
      overrides: [
        ...env.overrides(),
        ...noAgent(),
        healthProvider.overrideWith((ref) async => const <HealthCheck>[]),
        learnInstallerProvider.overrideWithValue(
          LearnInstaller(
              adb: tv, tvId: 'tv1', loadBundle: () async => bundle()),
        ),
      ],
    );
    await settle(tester);
  }

  Finder row() => find.byKey(const Key('better-tv-learn'));

  testWidgets('not on the TV: put it on, then it says so', (tester) async {
    await pump(tester);
    await tester.ensureVisible(row());
    expect(
      find.descendant(
          of: row(),
          matching: find.text('A maths game for the TV · put it on')),
      findsOneWidget,
    );
    await tester.tap(row());
    await settle(tester);
    expect(tv.installed, '0.1.0');
    expect(find.text('Tubby\'s Town 0.1.0 is on the TV ✓'), findsOneWidget);
    expect(
      find.descendant(
          of: row(), matching: find.text('On the TV · open it there')),
      findsOneWidget,
    );
  });

  testWidgets('already on the TV: the row opens it there', (tester) async {
    tv.installed = '0.1.0';
    await pump(tester);
    await tester.ensureVisible(row());
    await tester.tap(row());
    await settle(tester);
    expect(tv.log.last, startsWith('monkey -p $kLearnPackage'));
    expect(tv.log.any((c) => c.startsWith('pm install')), isFalse);
  });

  testWidgets('an older one on the TV offers the update', (tester) async {
    tv.installed = '0.0.9';
    await pump(tester);
    expect(
      find.descendant(of: row(), matching: find.text('A new version is ready')),
      findsOneWidget,
    );
  });
}
