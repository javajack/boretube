import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/whitelist_entry.dart';
import '../services/lock_service.dart';
import '../services/tv_service.dart';
import 'tv_providers.dart';

// ── SharedPreferences ──

final sharedPrefsProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError(
    'Override in ProviderScope',
  ),
);

// ── TV Service (Cast + Sony REST; classic lock, whitelist) ──

/// Legacy CastV2/DIAL service for the active TV, or null with no TV.
final tvServiceProvider = Provider<TvService?>((ref) {
  final a = ref.watch(activeTvAddressProvider);
  if (a == null) return null;
  return TvService(
    host: a.ip,
    castPort: a.castPort,
    dialPort: a.dialPort,
  );
});

// ── Whitelist ──

final whitelistProvider = StateNotifierProvider<
    WhitelistNotifier, List<WhitelistEntry>>(
  (ref) {
    return WhitelistNotifier(
      ref.watch(sharedPrefsProvider),
    );
  },
);

class WhitelistNotifier
    extends StateNotifier<List<WhitelistEntry>> {
  final SharedPreferences _prefs;

  WhitelistNotifier(this._prefs)
      : super(_load(_prefs));

  static List<WhitelistEntry> _load(
    SharedPreferences prefs,
  ) {
    final stored = prefs.getStringList('whitelist');
    if (stored != null && stored.isNotEmpty) {
      return stored
          .map(WhitelistEntry.fromStorageString)
          .toList();
    }
    return [WhitelistEntry.backdrop];
  }

  Future<void> add(WhitelistEntry entry) async {
    if (state.any((e) => e.appId == entry.appId)) {
      return;
    }
    state = [...state, entry];
    await _save();
  }

  Future<void> remove(String appId) async {
    // Cannot remove Backdrop
    if (appId == 'E8C28D3C') return;
    state =
        state.where((e) => e.appId != appId).toList();
    await _save();
  }

  bool isWhitelisted(String appId) =>
      state.any((e) => e.appId == appId);

  Future<void> _save() async {
    await _prefs.setStringList(
      'whitelist',
      state.map((e) => e.toStorageString()).toList(),
    );
  }
}

// ── Lock Service ──

final lockServiceProvider =
    Provider<LockService>((ref) {
  final service = LockService();
  service.init();
  ref.onDispose(service.dispose);
  return service;
});
