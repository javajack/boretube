// The structural guard itself: it must catch extra surfaces (including
// hand-made white bordered boxes), a second coral primary and eyebrows.
// The guard runs on every golden screen (test/goldens/*_golden_test.dart).
import 'package:boretube_mobile/ui/components.dart';
import 'package:boretube_mobile/ui/theme.dart';
import 'package:boretube_mobile/ui/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'structure.dart';

Future<void> _pump(WidgetTester tester, List<Widget> children) =>
    tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(body: ListView(children: children)),
      ),
    );

void main() {
  testWidgets('counts Surfaces and hand-made bordered white boxes',
      (tester) async {
    await _pump(tester, [
      const Surface(child: Text('a')),
      const Surface(child: Text('b')),
      Container(
        decoration: BoxDecoration(
          color: BtColors.light.surface,
          border: Border.all(color: BtColors.light.border),
        ),
        child: const Text('c'),
      ),
    ]);
    expect(surfaceCount(tester), 3);
  });

  testWidgets('plain rows on the canvas are not surfaces', (tester) async {
    await _pump(tester, [
      const RowList(
        children: [ListRow(title: 'One'), ListRow(title: 'Two')],
      ),
    ]);
    expect(surfaceCount(tester), 0);
    expectCalmStructure(tester);
  });

  testWidgets('a second coral primary and an eyebrow are caught',
      (tester) async {
    await _pump(tester, [
      PrimaryButton(label: 'One', onPressed: () {}),
      PrimaryButton(label: 'Two', onPressed: () {}),
      const Text('YOUR TVS'),
    ]);
    expect(coralPrimaryCount(tester), 2);
    expect(eyebrows(tester), ['YOUR TVS']);
  });
}
