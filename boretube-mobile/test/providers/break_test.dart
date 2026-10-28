import 'package:boretube_mobile/actions/actions_service.dart';
import 'package:boretube_mobile/ops/journal.dart';
import 'package:boretube_mobile/providers/break_provider.dart';
import 'package:boretube_mobile/providers/now_playing.dart';
import 'package:boretube_mobile/tv/tv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Actions extends ActionsService {
  final calls = <String>[];
  bool ok = true;

  _Actions() : super(const Tv(id: 'tv1', name: 'TV', ip: '10.0.0.9'));

  Future<ActionResult> _c(String name) async {
    calls.add(name);
    return ActionResult(ok, ActionTransport.adb, detail: ok ? '' : 'nope');
  }

  @override
  Future<ActionResult> mute() => _c('mute');
  @override
  Future<ActionResult> restore() => _c('restore');
  @override
  Future<ActionResult> stopCurrentApp() => _c('stop');
  @override
  Future<ActionResult> startBreak(int minutes, {DateTime? now}) =>
      _c('break $minutes');
}

const _playing = NowPlaying(
  online: true,
  id: 'org.smarttube.stable',
  appName: 'SmartTube',
  volume: 20,
  muted: false,
  source: 'adb',
);

void main() {
  final t0 = DateTime(2026, 10, 28, 19);
  late SharedPreferences prefs;
  late Journal journal;
  late _Actions actions;
  late NowPlayingNotifier now;
  late DateTime clock;

  Future<BreakController> make({Map<String, Object> saved = const {}}) async {
    SharedPreferences.setMockInitialValues(saved);
    prefs = await SharedPreferences.getInstance();
    journal = Journal(Future.value(prefs));
    return BreakController(
      tvId: 'tv1',
      prefs: prefs,
      actions: () => actions,
      nowPlaying: () => now,
      journal: journal,
      clock: () => clock,
    );
  }

  setUp(() {
    clock = t0;
    actions = _Actions();
    now = NowPlayingNotifier.fixed(_playing);
  });

  tearDown(() => now.dispose());

  test('start: break shows at once, is saved, hero goes Home + muted',
      () async {
    final c = await make();
    final r = await c.start(30);
    expect(r!.ok, isTrue);
    expect(actions.calls, ['break 30']);
    expect(c.state.until, t0.add(const Duration(minutes: 30)));
    expect(c.remaining(), const Duration(minutes: 30));
    expect(prefs.getString(BreakController.keyFor('tv1')), isNotNull);
    expect(now.state.muted, isTrue);
    expect(now.state.isHome, isTrue);
    c.dispose();
  });

  test('start that fails rolls everything back', () async {
    final c = await make();
    actions.ok = false;
    final r = await c.start(15);
    expect(r!.ok, isFalse);
    expect(c.state.active, isFalse);
    expect(prefs.getString(BreakController.keyFor('tv1')), isNull);
    expect(now.state.muted, isFalse);
    expect(now.state.appName, 'SmartTube');
    c.dispose();
  });

  test('enforce: closes the app and re-mutes, journaled; then rate-limited',
      () async {
    final c = await make();
    await c.start(15);
    actions.calls.clear();
    await c.enforce(_playing);
    expect(actions.calls, ['stop', 'mute']);
    final titles = [
      for (final e in await journal.entries('tv1')) '${e.op}:${e.target}',
    ];
    expect(titles, ['break:closed SmartTube', 'break:re-muted']);

    await c.enforce(_playing);
    expect(actions.calls, hasLength(2), reason: 'within the gap');
    clock = clock.add(const Duration(seconds: 5));
    await c.enforce(_playing.copyWith(muted: true));
    expect(actions.calls, ['stop', 'mute', 'stop']);
    c.dispose();
  });

  test('enforce does nothing on Home + muted, or without a break', () async {
    final c = await make();
    await c.enforce(_playing);
    expect(actions.calls, isEmpty, reason: 'no break');
    await c.start(15);
    actions.calls.clear();
    await c.enforce(
      const NowPlaying(online: true, isHome: true, muted: true),
    );
    await c.enforce(const NowPlaying()); // offline
    expect(actions.calls, isEmpty);
    c.dispose();
  });

  test('reopening the app resumes a saved break', () async {
    final until = t0.add(const Duration(minutes: 12, seconds: 40));
    final c = await make(
      saved: {BreakController.keyFor('tv1'): until.toIso8601String()},
    );
    expect(c.state.until, until);
    expect(c.remaining(), const Duration(minutes: 12, seconds: 40));
    expect(actions.calls, isEmpty);
    c.dispose();
  });

  test('a break that ran out while closed unmutes once and clears', () async {
    final c = await make(
      saved: {
        BreakController.keyFor('tv1'):
            t0.subtract(const Duration(minutes: 1)).toIso8601String(),
      },
    );
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(actions.calls, ['restore']);
    expect(c.state.active, isFalse);
    expect(prefs.getString(BreakController.keyFor('tv1')), isNull);
    final last = (await journal.entries('tv1')).last;
    expect(last.target, 'over: sound back on');
    c.dispose();
  });

  test('the end timer restores the sound', () async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    final c = BreakController(
      tvId: 'tv1',
      prefs: prefs,
      actions: () => actions,
      nowPlaying: () => now,
    );
    await prefs.setString(
      BreakController.keyFor('tv1'),
      DateTime.now().add(const Duration(milliseconds: 40)).toIso8601String(),
    );
    c.dispose();
    final d = BreakController(
      tvId: 'tv1',
      prefs: prefs,
      actions: () => actions,
      nowPlaying: () => now,
    );
    expect(d.state.active, isTrue);
    await Future<void>.delayed(const Duration(milliseconds: 120));
    expect(actions.calls, ['restore']);
    expect(d.state.active, isFalse);
    d.dispose();
  });

  test('End now clears the break and unmutes', () async {
    final c = await make();
    await c.start(60);
    final r = await c.end();
    expect(r!.ok, isTrue);
    expect(actions.calls, ['break 60', 'restore']);
    expect(c.state.active, isFalse);
    expect(now.state.muted, isFalse);
    c.dispose();
  });
}
