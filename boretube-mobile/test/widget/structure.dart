// Structural guards for the calm layout (docs/superpowers/specs/
// 2026-10-29-visual-audit-and-direction.md): at most two raised surfaces
// per screen, exactly one coral primary at most, and no uppercase
// "eyebrow" labels.
import 'package:boretube_mobile/screens/rules/tv_says_no.dart';
import 'package:boretube_mobile/ui/components.dart';
import 'package:boretube_mobile/ui/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Raised containers on screen: every [Surface], plus any hand-made white
/// box with a border (so the count can't be dodged with a Container) and
/// any Material [Card].
int surfaceCount(WidgetTester tester) {
  final surfaces = find.byType(Surface).evaluate().length;
  final ctx = find.byType(Scaffold).evaluate().first;
  final white = Theme.of(ctx).extension<BtColors>()!.surface;
  final boxes = find
      .byWidgetPredicate((w) {
        if (w is! DecoratedBox) return false;
        final d = w.decoration;
        return d is BoxDecoration && d.border != null && d.color == white;
      })
      .evaluate()
      .length;
  final cards = find.byType(Card).evaluate().length;
  return surfaces + boxes + cards;
}

int coralPrimaryCount(WidgetTester tester) => find
    .byWidgetPredicate(
      (w) => w is PrimaryButton && w.kind == ButtonKind.coral,
    )
    .evaluate()
    .length;

/// Texts set as tracked uppercase labels ("YOUR TVS"). Words with digits
/// are data (a model name like "BRAVIA VU3"), and the TV-card preview may
/// use caps the way the TV does (the doc's one exception).
List<String> eyebrows(WidgetTester tester) {
  final caps = RegExp(r'^[A-Z]{2,}( [A-Z·&]+)+$');
  final preview = find.descendant(
    of: find.byType(TvSaysNoPreview),
    matching: find.byType(Text),
  );
  final exempt = preview.evaluate().map((e) => e.widget).toSet();
  return [
    for (final e in find.byType(Text).evaluate())
      if (e.widget case final Text t when !exempt.contains(t))
        if (t.data != null &&
            (caps.hasMatch(t.data!.trim()) ||
                (t.style?.letterSpacing ?? 0) > 0.5))
          t.data!,
  ];
}

/// The calm-layout rules for one rendered screen.
void expectCalmStructure(WidgetTester tester, {int maxSurfaces = 2}) {
  expect(
    surfaceCount(tester),
    lessThanOrEqualTo(maxSurfaces),
    reason: 'At most $maxSurfaces raised surfaces per screen; lists go on '
        'the canvas.',
  );
  expect(
    coralPrimaryCount(tester),
    lessThanOrEqualTo(1),
    reason: 'Exactly one coral primary per screen, at most.',
  );
  expect(eyebrows(tester), isEmpty, reason: 'No uppercase eyebrows.');
}
