import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'providers.dart';

/// App preferences that are not secrets.
class AppSettings {
  static const pollChoices = [3, 5, 10, 15, 30];

  /// Now-on-TV refresh, seconds.
  final int pollSeconds;

  /// TV ids where the parent allowed maintenance on a generic profile.
  final Set<String> maintenanceUnlocked;

  /// TV ids where stock YouTube is allowed (Health won't flag it).
  final Set<String> allowStockYouTube;

  const AppSettings({
    this.pollSeconds = 5,
    this.maintenanceUnlocked = const {},
    this.allowStockYouTube = const {},
  });

  AppSettings copyWith({
    int? pollSeconds,
    Set<String>? maintenanceUnlocked,
    Set<String>? allowStockYouTube,
  }) =>
      AppSettings(
        pollSeconds: pollSeconds ?? this.pollSeconds,
        maintenanceUnlocked: maintenanceUnlocked ?? this.maintenanceUnlocked,
        allowStockYouTube: allowStockYouTube ?? this.allowStockYouTube,
      );
}

class AppSettingsNotifier extends StateNotifier<AppSettings> {
  static const pollKey = 'poll_seconds';
  static const maintenanceKey = 'maintenance_unlocked';
  static const youTubeKey = 'allow_stock_youtube';

  final SharedPreferences _prefs;

  AppSettingsNotifier(this._prefs)
      : super(
          AppSettings(
            pollSeconds: _prefs.getInt(pollKey) ?? 5,
            maintenanceUnlocked:
                (_prefs.getStringList(maintenanceKey) ?? const []).toSet(),
            allowStockYouTube:
                (_prefs.getStringList(youTubeKey) ?? const []).toSet(),
          ),
        );

  Future<void> setPollSeconds(int s) async {
    state = state.copyWith(pollSeconds: s.clamp(2, 60));
    await _prefs.setInt(pollKey, state.pollSeconds);
  }

  Future<void> setMaintenanceUnlocked(String tvId, bool on) async {
    final next = {...state.maintenanceUnlocked};
    on ? next.add(tvId) : next.remove(tvId);
    state = state.copyWith(maintenanceUnlocked: next);
    await _prefs.setStringList(maintenanceKey, next.toList());
  }

  Future<void> setAllowStockYouTube(String tvId, bool on) async {
    final next = {...state.allowStockYouTube};
    on ? next.add(tvId) : next.remove(tvId);
    state = state.copyWith(allowStockYouTube: next);
    await _prefs.setStringList(youTubeKey, next.toList());
  }
}

final appSettingsProvider =
    StateNotifierProvider<AppSettingsNotifier, AppSettings>(
  (ref) => AppSettingsNotifier(ref.watch(sharedPrefsProvider)),
);
