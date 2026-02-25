import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/tv_config.dart';
import '../models/tv_status.dart';
import '../models/whitelist_entry.dart';
import '../services/lock_service.dart';
import '../services/tv_service.dart';

// ── SharedPreferences ──

final sharedPrefsProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError(
    'Override in ProviderScope',
  ),
);

// ── TV Config ──

final tvConfigProvider =
    StateNotifierProvider<TvConfigNotifier, TvConfig>(
  (ref) {
    return TvConfigNotifier(
      ref.watch(sharedPrefsProvider),
    );
  },
);

class TvConfigNotifier extends StateNotifier<TvConfig> {
  final SharedPreferences _prefs;

  TvConfigNotifier(this._prefs) : super(_load(_prefs));

  static TvConfig _load(SharedPreferences prefs) {
    final json = prefs.getString('tv_config');
    if (json != null) {
      try {
        return TvConfig.fromJson(
          jsonDecode(json) as Map<String, dynamic>,
        );
      } catch (_) {
        // Fall through to default
      }
    }
    return TvConfig.defaultConfig;
  }

  Future<void> update(TvConfig config) async {
    state = config;
    await _prefs.setString(
      'tv_config',
      jsonEncode(config.toJson()),
    );
  }

  bool get isConfigured =>
      _prefs.containsKey('tv_config');
}

// ── TV Service ──

final tvServiceProvider = Provider<TvService>((ref) {
  final config = ref.watch(tvConfigProvider);
  return TvService(
    host: config.ip,
    castPort: config.castPort,
    dialPort: config.dialPort,
  );
});

// ── TV Status (auto-refreshing) ──

final tvStatusProvider = StateNotifierProvider<
    TvStatusNotifier, AsyncValue<TvStatus>>(
  (ref) {
    final service = ref.watch(tvServiceProvider);
    return TvStatusNotifier(service);
  },
);

class TvStatusNotifier
    extends StateNotifier<AsyncValue<TvStatus>> {
  final TvService _service;
  Timer? _timer;
  bool _disposed = false;

  TvStatusNotifier(this._service)
      : super(const AsyncValue.loading()) {
    _refresh();
    _timer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _refresh(),
    );
  }

  Future<void> _refresh() async {
    if (_disposed) return;
    try {
      final status = await _service.getStatus();
      if (_disposed) return;
      if (status != null) {
        state = AsyncValue.data(status);
      } else {
        state = AsyncValue.error(
          'TV unreachable',
          StackTrace.current,
        );
      }
    } catch (e, st) {
      if (_disposed) return;
      state = AsyncValue.error(e, st);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}

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
