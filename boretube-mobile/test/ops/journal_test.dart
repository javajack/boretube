import 'package:boretube_mobile/ops/journal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

JournalEntry _e(String tv, int i) => JournalEntry(
      tvId: tv,
      time: DateTime.utc(2026, 1, 1).add(Duration(seconds: i)),
      op: 'disableApp',
      target: 'pkg$i',
      before: 'enabled',
      after: 'disabled',
      undoCommand: 'pm enable pkg$i',
      ok: true,
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('round-trips entries per TV', () async {
    final j = Journal();
    await j.add(_e('a', 1));
    await j.addAll([_e('b', 2), _e('a', 3)]);
    final a = await j.entries('a');
    expect(a.map((e) => e.target), ['pkg1', 'pkg3']);
    expect(a.first.undoCommand, 'pm enable pkg1');
    expect(a.first.time, DateTime.utc(2026, 1, 1, 0, 0, 1));
    expect(await j.entries('b'), hasLength(1));
    await j.clear('a');
    expect(await j.entries('a'), isEmpty);
  });

  test('caps at 500, dropping the oldest', () async {
    final j = Journal();
    await j.addAll([for (var i = 0; i < 520; i++) _e('a', i)]);
    await j.add(_e('a', 520));
    final a = await j.entries('a');
    expect(a, hasLength(Journal.maxEntries));
    expect(a.first.target, 'pkg21');
    expect(a.last.target, 'pkg520');
  });
}
