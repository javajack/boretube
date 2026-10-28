import 'package:boretube_mobile/providers/agent_providers.dart';
import 'package:boretube_mobile/providers/ui_providers.dart';
import 'package:boretube_mobile/screens/home/home_tab.dart';
import 'package:boretube_mobile/screens/home/plan.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';
import 'home_tab_test.dart' show playing;

void main() {
  group('orderPlan', () {
    test('no goals: the default order', () {
      expect(orderPlan(const []), PlanStep.values);
    });

    test('Shorts first: Home mode, then YouTube without Shorts', () {
      expect(orderPlan(const [Goal.shorts]).take(3), [
        PlanStep.remote,
        PlanStep.unlockHome,
        PlanStep.noShorts,
      ]);
    });

    test('ads pulls Clean TV ahead of Shorts', () {
      expect(orderPlan(const [Goal.ads]), [
        PlanStep.remote,
        PlanStep.unlockHome,
        PlanStep.cleanTv,
        PlanStep.noShorts,
        PlanStep.bedtime,
        PlanStep.alwaysOn,
      ]);
    });

    test('the order of the picks matters, prerequisites never move', () {
      final p = orderPlan(const [Goal.apps, Goal.bedtime, Goal.shorts]);
      expect(p, [
        PlanStep.remote,
        PlanStep.unlockHome,
        PlanStep.alwaysOn,
        PlanStep.bedtime,
        PlanStep.noShorts,
        PlanStep.cleanTv,
      ]);
      for (final s in p) {
        for (final n in s.needs) {
          expect(p.indexOf(n), lessThan(p.indexOf(s)), reason: '$n < $s');
        }
      }
    });

    test('done state per TV', () {
      final cast = planProgress(tv: castOnlySony, link: AgentLink.none);
      expect(cast[PlanStep.remote], isTrue);
      expect(cast[PlanStep.unlockHome], isFalse);
      final adb = planProgress(tv: adbSony, link: AgentLink.none);
      expect(adb[PlanStep.unlockHome], isTrue);
      expect(adb[PlanStep.alwaysOn], isFalse);
    });
  });

  testWidgets('Home shows the plan in goal order, the next step marked',
      (tester) async {
    final env = await TestEnv.create(
      tvs: [castOnlySony],
      prefs: {
        GoalsNotifier.key: ['ads'],
      },
    );
    await pumpScreen(
      tester,
      const HomeTab(),
      scaffold: true,
      size: const Size(360, 2000),
      overrides: env.overrides(now: playing),
    );
    await settle(tester);
    expect(find.byKey(const Key('plan-card')), findsOneWidget);
    expect(find.text('1 of 6 done'), findsOneWidget);
    // Slim until asked: only the next step, the rest open in place.
    expect(find.byKey(const Key('plan-unlockHome')), findsOneWidget);
    expect(find.byKey(const Key('plan-cleanTv')), findsNothing);
    await tester.tap(find.byKey(const Key('plan-toggle')));
    await settle(tester);
    final ys = [
      for (final s in [
        PlanStep.remote,
        PlanStep.unlockHome,
        PlanStep.cleanTv,
        PlanStep.noShorts,
      ])
        tester.getTopLeft(find.byKey(Key('plan-${s.name}'))).dy,
    ];
    expect([...ys]..sort(), ys);
    expect(
      find.descendant(
        of: find.byKey(const Key('plan-unlockHome')),
        matching: find.textContaining('Next · '),
      ),
      findsOneWidget,
    );
  });
}
