// The Home nudge card and the History explainer, light and dark.
// Regenerate with: flutter test --update-goldens test/goldens
@Tags(['golden'])
library;

import 'package:boretube_mobile/ops/journal.dart';
import 'package:boretube_mobile/providers/nudges.dart';
import 'package:boretube_mobile/providers/tv_providers.dart';
import 'package:boretube_mobile/screens/history_screen.dart';
import 'package:boretube_mobile/screens/home/nudge_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../widget/helpers.dart';

void main() {
  setUpAll(loadAppFonts);

  for (final dark in [false, true]) {
    final sfx = dark ? '_dark' : '_light';

    testWidgets('Nudge card ($sfx)', (tester) async {
      final env = await TestEnv.create(tvs: [adbSony]);
      final n = bedtimeNudge(
        NudgeInputs(
          now: DateTime(2026, 10, 29, 19),
          pauses: [
            DateTime(2026, 10, 27, 20, 10),
            DateTime(2026, 10, 28, 20, 20),
            DateTime(2026, 10, 29, 20, 15),
          ],
        ),
      )!;
      final v = volumeLimitNudge(
        NudgeInputs(
          now: DateTime(2026, 10, 29, 19),
          volumeDowns: [
            for (final d in [1, 2, 4]) DateTime(2026, 10, 29 - d, 19),
          ],
        ),
      )!;
      await pumpScreen(
        tester,
        ListView(
          padding: const EdgeInsets.all(20),
          children: [
            NudgeCard(nudge: n, onAct: () {}, onNotNow: () {}),
            const SizedBox(height: 16),
            NudgeCard(nudge: v, onAct: () {}, onNotNow: () {}),
          ],
        ),
        scaffold: true,
        dark: dark,
        size: const Size(360, 480),
        overrides: env.overrides(),
      );
      await settle(tester, 4);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('nudge_card$sfx.png'),
      );
    });

    testWidgets('History, nothing yet ($sfx)', (tester) async {
      final env = await TestEnv.create(tvs: [adbSony]);
      await pumpScreen(
        tester,
        const HistoryScreen(),
        dark: dark,
        overrides: [
          ...env.overrides(),
          journalEntriesProvider.overrideWith(
            (ref) async => const <JournalEntry>[],
          ),
        ],
      );
      await settle(tester, 8);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('history_empty$sfx.png'),
      );
    });
  }
}
