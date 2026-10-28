import 'dart:io';

import 'package:boretube_mobile/ui/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

double _width(TextStyle s) {
  final p = TextPainter(
    text: TextSpan(text: 'Hamburgefonstiv 0123', style: s),
    textDirection: TextDirection.ltr,
  )..layout();
  return p.width;
}

void main() {
  setUpAll(() async {
    for (final (family, file) in const [
      (Fonts.ui, 'assets/fonts/Figtree-Variable.ttf'),
      (Fonts.display, 'assets/fonts/BricolageGrotesque-Variable.ttf'),
    ]) {
      final bytes = File(file).readAsBytesSync();
      // A real TrueType file, not an HTML error page.
      expect(bytes.length, greaterThan(50000), reason: file);
      expect(bytes.sublist(0, 4), [0, 1, 0, 0], reason: file);
      await (FontLoader(family)
            ..addFont(Future.value(ByteData.sublistView(bytes))))
          .load();
    }
  });

  test('licences are bundled', () {
    for (final f in ['OFL-Figtree.txt', 'OFL-BricolageGrotesque.txt']) {
      expect(
        File('assets/fonts/$f').readAsStringSync(),
        contains('SIL OPEN FONT LICENSE Version 1.1'),
      );
    }
  });

  testWidgets('FontWeight drives the variable wght axis (400–800)',
      (tester) async {
    for (final family in [Fonts.ui, Fonts.display]) {
      final widths = [
        for (final w in const [
          FontWeight.w400,
          FontWeight.w500,
          FontWeight.w600,
          FontWeight.w700,
          FontWeight.w800,
        ])
          _width(TextStyle(fontFamily: family, fontSize: 20, fontWeight: w)),
      ];
      for (var i = 1; i < widths.length; i++) {
        expect(widths[i], greaterThan(widths[i - 1]), reason: '$family $i');
      }
    }
  });

  testWidgets('Bricolage keeps its weight with optical sizing set',
      (tester) async {
    final bold = _width(Fonts.bricolage(24, weight: FontWeight.w700));
    final heavy = _width(Fonts.bricolage(24));
    expect(heavy, greaterThan(bold));
  });
}
