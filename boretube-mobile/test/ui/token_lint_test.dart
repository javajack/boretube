// Screens and the design system reference tokens only (lib/ui/tokens.dart):
// no raw spacing, sizes, radii, type sizes or durations. Zero is fine.
// Illustration geometry (a drawn TV, Tubby) may opt out between
// `// tokens:off` and `// tokens:on`.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _named = 'width|height|size|fontSize|radius|blurRadius|spreadRadius|'
    'strokeWidth|thickness|indent|endIndent|minHeight|minWidth|maxHeight|'
    'maxWidth|letterSpacing|iconSize|elevation|top|left|right|bottom|'
    'horizontal|vertical|milliseconds|extent|itemExtent|toolbarHeight';

final _rules = <RegExp>[
  RegExp(r'\b(' + _named + r')\s*:\s*-?(\d+\.?\d*)\b'),
  RegExp(
    r'\b(EdgeInsets\.all|Radius\.circular|BorderRadius\.circular|'
    r'Offset|Size|SizedBox\.square)\(\s*-?(\d+\.?\d*)',
  ),
  RegExp(r'\b(?:Offset|Size)\([^,()]+,\s*-?(\d+\.?\d*)\s*\)'),
  RegExp(r'fromLTRB\([^)]*?\b(\d+\.?\d*)\b'),
  // Token arithmetic with a raw literal ("Gap.f13 + 2"); halving and
  // doubling are fine.
  RegExp(
    r'\b(?:Gap|Sizes|TypeSize|Radii)\.\w+\s*[+\-*/]\s*(\d+\.?\d*)\b',
  ),
];

bool _zero(String n) => double.tryParse(n) == 0;

List<String> violations(File f) {
  final out = <String>[];
  var off = false;
  final lines = f.readAsLinesSync();
  for (var i = 0; i < lines.length; i++) {
    final raw = lines[i];
    final line = raw.trim();
    if (line.contains('tokens:off')) off = true;
    if (line.contains('tokens:on')) off = false;
    if (off || line.startsWith('//') || line.startsWith('///')) continue;
    final code = raw.split('//').first;
    for (final r in _rules) {
      for (final m in r.allMatches(code)) {
        final n = m.group(m.groupCount)!;
        if (_zero(n)) continue;
        final arith = r == _rules.last;
        if (arith && n == '2') continue;
        out.add('${f.path}:${i + 1}: ${line.trim()}');
      }
    }
  }
  return out;
}

void main() {
  test('lib/screens and lib/ui use tokens only (no raw sizes)', () {
    final files = [
      ...Directory('lib/screens').listSync(recursive: true),
      ...Directory('lib/ui').listSync(recursive: true),
    ].whereType<File>().where(
          (f) =>
              f.path.endsWith('.dart') &&
              !f.path.endsWith('tokens.dart') &&
              !f.path.endsWith('theme.dart'),
        );
    final all = [for (final f in files) ...violations(f)];
    expect(all, isEmpty, reason: all.join('\n'));
  });
}
