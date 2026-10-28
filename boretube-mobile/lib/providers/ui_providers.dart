import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'providers.dart';

// UI-only state kept on this phone. Nothing here talks to the TV.

// ── Theme ──

/// Theme choices, in the order Settings offers them. Cream light is the
/// identity and the default whatever the phone says; "Follow phone" is
/// last and never the default.
enum ThemePref { light, bedtime, dark, system }

/// [ThemePref.bedtime]: light by day, bedtime dark after sunset (7 pm to
/// 7 am).
ThemeMode themeModeFor(ThemePref p, DateTime now) => switch (p) {
      ThemePref.system => ThemeMode.system,
      ThemePref.light => ThemeMode.light,
      ThemePref.dark => ThemeMode.dark,
      ThemePref.bedtime =>
        now.hour >= 19 || now.hour < 7 ? ThemeMode.dark : ThemeMode.light,
    };

class ThemePrefNotifier extends StateNotifier<ThemePref> {
  static const key = 'ui.theme';
  final SharedPreferences _prefs;

  /// Installs that never chose a theme (no stored value) get Light; the
  /// old default followed the phone, which hid the brand in dark mode.
  ThemePrefNotifier(this._prefs)
      : super(
          ThemePref.values.asNameMap()[_prefs.getString(key)] ??
              ThemePref.light,
        );

  Future<void> set(ThemePref p) async {
    state = p;
    await _prefs.setString(key, p.name);
  }
}

final themePrefProvider = StateNotifierProvider<ThemePrefNotifier, ThemePref>(
  (ref) => ThemePrefNotifier(ref.watch(sharedPrefsProvider)),
);

// ── Goals ("What's bugging you?") ──

enum Goal { shorts, bedtime, loud, ads, apps }

class GoalsNotifier extends StateNotifier<List<Goal>> {
  static const key = 'ui.goals';
  static const answeredKey = 'ui.goals.answered';
  final SharedPreferences _prefs;

  GoalsNotifier(this._prefs) : super(_load(_prefs));

  static List<Goal> _load(SharedPreferences p) {
    final names = Goal.values.asNameMap();
    return [
      for (final n in p.getStringList(key) ?? const <String>[])
        if (names[n] != null) names[n]!,
    ];
  }

  bool get answered => _prefs.getBool(answeredKey) ?? false;

  /// Saves the picks in the order they were chosen.
  Future<void> save(List<Goal> goals) async {
    state = List.unmodifiable(goals);
    await _prefs.setStringList(key, [for (final g in goals) g.name]);
    await _prefs.setBool(answeredKey, true);
  }
}

final goalsProvider = StateNotifierProvider<GoalsNotifier, List<Goal>>(
  (ref) => GoalsNotifier(ref.watch(sharedPrefsProvider)),
);

// ── Pause TV ──

/// The duration chip last used on Pause TV, in minutes. 0 = "Until
/// bedtime".
class PauseChoiceNotifier extends StateNotifier<int> {
  static const key = 'ui.pause.minutes';
  static const choices = [15, 30, 60];
  final SharedPreferences _prefs;

  PauseChoiceNotifier(this._prefs) : super(_prefs.getInt(key) ?? 30);

  Future<void> set(int minutes) async {
    state = minutes;
    await _prefs.setInt(key, minutes);
  }
}

final pauseChoiceProvider = StateNotifierProvider<PauseChoiceNotifier, int>(
  (ref) => PauseChoiceNotifier(ref.watch(sharedPrefsProvider)),
);

/// When this phone started the running break, per TV (for "During this
/// break"). Breaks started elsewhere fall back to the last hour.
class BreakStartLog {
  final SharedPreferences prefs;
  const BreakStartLog(this.prefs);

  static String keyFor(String tvId) => 'ui.break.started.$tvId';

  DateTime? read(String tvId) =>
      DateTime.tryParse(prefs.getString(keyFor(tvId)) ?? '');

  Future<void> mark(String tvId, DateTime at) =>
      prefs.setString(keyFor(tvId), at.toIso8601String());
}

final breakStartLogProvider = Provider<BreakStartLog>(
  (ref) => BreakStartLog(ref.watch(sharedPrefsProvider)),
);

// ── One-time moments ──

/// Celebrations happen once each (no streaks).
class Moments {
  final SharedPreferences prefs;
  const Moments(this.prefs);

  static const firstPause = 'firstPause';
  static const firstWin = 'firstWin';

  bool seen(String id) => prefs.getBool('ui.moment.$id') ?? false;

  /// True the first time; false after.
  Future<bool> claim(String id) async {
    if (seen(id)) return false;
    await prefs.setBool('ui.moment.$id', true);
    return true;
  }
}

final momentsProvider = Provider<Moments>(
  (ref) => Moments(ref.watch(sharedPrefsProvider)),
);

// ── Helper-switch guide ──

/// The step of the Home mode guide each TV was left on.
class HelperProgress {
  final SharedPreferences prefs;
  const HelperProgress(this.prefs);

  static String keyFor(String tvId) => 'ui.helper.step.$tvId';
  static String presses(String tvId) => 'ui.helper.presses.$tvId';

  int step(String tvId) => prefs.getInt(keyFor(tvId)) ?? 0;

  Future<void> setStep(String tvId, int step) =>
      prefs.setInt(keyFor(tvId), step);

  int okPresses(String tvId) => prefs.getInt(presses(tvId)) ?? 0;

  Future<void> setOkPresses(String tvId, int n) =>
      prefs.setInt(presses(tvId), n);

  Future<void> clear(String tvId) async {
    await prefs.remove(keyFor(tvId));
    await prefs.remove(presses(tvId));
  }
}

final helperProgressProvider = Provider<HelperProgress>(
  (ref) => HelperProgress(ref.watch(sharedPrefsProvider)),
);

// ── Shell ──

/// The selected main tab: 0 Home, 1 Routines, 2 Better TV.
final shellTabProvider = StateProvider<int>((ref) => 0);

/// A Better TV section to scroll to once (e.g. 'alwaysOn' from an Always
/// On alert). Better TV clears it after scrolling.
final betterTvFocusProvider = StateProvider<String?>((ref) => null);

/// A Routines card to scroll to once (e.g. 'shorts' from a nudge). The
/// rules editor clears it after scrolling.
final routinesFocusProvider = StateProvider<String?>((ref) => null);
