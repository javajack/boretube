import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/tv_config.dart';
import 'tv.dart';

/// Saved TVs plus the active one, persisted in SharedPreferences.
///
/// Listen for changes via [ChangeNotifier] or [changes].
class TvStore extends ChangeNotifier {
  static const tvsKey = 'tvs_v2';
  static const activeKey = 'active_tv_id';

  /// The v1 single-TV prefs key ([TvConfig] JSON).
  static const legacyKey = 'tv_config';

  final SharedPreferences _prefs;
  final List<Tv> _tvs;
  String? _activeId;

  TvStore._(this._prefs, this._tvs, this._activeId);

  /// Loads the store, migrating v1 `tv_config` once if `tvs_v2` was
  /// never written.
  static Future<TvStore> load({SharedPreferences? prefs}) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final tvs = <Tv>[];
    final raw = p.getString(tvsKey);
    if (raw != null) {
      try {
        for (final j in jsonDecode(raw) as List) {
          tvs.add(Tv.fromJson((j as Map).cast<String, dynamic>()));
        }
      } catch (_) {
        // Corrupt data: start empty rather than crash.
      }
    }
    var activeId = p.getString(activeKey);
    final store = TvStore._(p, tvs, activeId);
    if (raw == null) {
      final migrated = _migrate(p.getString(legacyKey));
      if (migrated != null) {
        tvs.add(migrated);
        activeId ??= migrated.id;
        store._activeId = activeId;
      }
      await store._save();
    }
    if (_repairRekeyed(p, store)) await store._save();
    if (store._activeId != null && store.byId(store._activeId!) == null) {
      store._activeId = tvs.isEmpty ? null : tvs.first.id;
      await store._save();
    }
    return store;
  }

  /// Before 2.0.1 a saved TV could be re-keyed (`adb:<serial>` → `agent:…`)
  /// when TV Guard announced itself, orphaning everything kept under the old
  /// id. Gives such a TV its old id back when data still lives under it.
  static bool _repairRekeyed(SharedPreferences p, TvStore store) {
    final keys = p.getKeys();
    var changed = false;
    for (var i = 0; i < store._tvs.length; i++) {
      final t = store._tvs[i];
      final serial = t.adbSerial;
      if (serial == null || serial.isEmpty || t.id.startsWith('adb:')) continue;
      final old = 'adb:$serial';
      if (store.byId(old) != null) continue;
      // Data is kept as "<what>.<tvId>" (baseline.adb:…, nudge.build.adb:…).
      if (!keys.any((k) => k.endsWith('.$old'))) continue;
      // Carry anything saved under the newer id across where the old id has
      // nothing of its own (journal, watch state, a newer baseline…).
      for (final k in keys.where((k) => k.endsWith('.${t.id}')).toList()) {
        final to = '${k.substring(0, k.length - t.id.length)}$old';
        if (p.containsKey(to)) continue;
        final v = p.get(k);
        if (v is String) {
          p.setString(to, v);
        } else if (v is bool) {
          p.setBool(to, v);
        } else if (v is int) {
          p.setInt(to, v);
        } else if (v is double) {
          p.setDouble(to, v);
        } else if (v is List<String>) {
          p.setStringList(to, v);
        }
      }
      store._tvs[i] = t.copyWith(id: old);
      if (store._activeId == t.id) store._activeId = old;
      changed = true;
    }
    return changed;
  }

  static Tv? _migrate(String? legacy) {
    if (legacy == null) return null;
    try {
      final cfg = TvConfig.fromJson(
        (jsonDecode(legacy) as Map).cast<String, dynamic>(),
      );
      if (cfg.ip.isEmpty) return null;
      return Tv(
        id: 'ip:${cfg.ip}',
        name: cfg.name.isEmpty ? 'TV' : cfg.name,
        ip: cfg.ip,
        castPort: cfg.castPort,
        dialPort: cfg.dialPort,
      );
    } catch (_) {
      return null;
    }
  }

  List<Tv> get tvs => List.unmodifiable(_tvs);
  String? get activeId => _activeId;
  Tv? get active => _activeId == null ? null : byId(_activeId!);

  Tv? byId(String id) {
    for (final t in _tvs) {
      if (t.id == id) return t;
    }
    return null;
  }

  /// Emits the TV list after every change.
  Stream<List<Tv>> get changes {
    late final StreamController<List<Tv>> c;
    void push() => c.add(tvs);
    c = StreamController<List<Tv>>(
      onListen: () => addListener(push),
      onCancel: () => removeListener(push),
    );
    return c.stream;
  }

  /// Adds or updates [tv] by id. Entries for the same physical TV under
  /// another id (same ADB serial or UDN, or a temporary `ip:` id at the
  /// same IP) are merged into one. The saved id wins: the agent token,
  /// baselines, restore points and plan state are all keyed by it, so only
  /// a temporary `ip:` id may be upgraded. The active id follows.
  /// Returns the id the TV is stored under (which can differ from [tv.id]).
  Future<String> upsert(Tv tv) async {
    bool eq(String? a, String? b) => a != null && a.isNotEmpty && a == b;
    final same = <int>[];
    for (var i = 0; i < _tvs.length; i++) {
      final o = _tvs[i];
      if (o.id == tv.id ||
          eq(o.adbSerial, tv.adbSerial) ||
          eq(o.udn, tv.udn) ||
          (o.id.startsWith('ip:') && o.ip == tv.ip)) {
        same.add(i);
      }
    }
    var merged = tv;
    for (final i in same) {
      merged = _merge(_tvs[i], merged);
    }
    final kept = [for (final i in same) _tvs[i].id]
        .where((id) => !id.startsWith('ip:'))
        .firstOrNull;
    if (kept != null) merged = merged.copyWith(id: kept);
    if (same.isEmpty) {
      _tvs.add(merged);
    } else {
      final replaced = {for (final i in same) _tvs[i].id};
      _tvs[same.first] = merged;
      for (final i in same.skip(1).toList().reversed) {
        _tvs.removeAt(i);
      }
      if (replaced.contains(_activeId)) _activeId = merged.id;
    }
    _activeId ??= merged.id;
    await _save();
    notifyListeners();
    return merged.id;
  }

  /// [newer] wins, but keeps [older]'s known identity, capabilities
  /// (when [newer] was never probed) and the latest lastSeen.
  static Tv _merge(Tv older, Tv newer) {
    final keepCaps = newer.capabilitiesCheckedAt == null &&
        older.capabilitiesCheckedAt != null;
    final olderSeen = older.lastSeen;
    final newerSeen = newer.lastSeen;
    return newer.copyWith(
      name: newer.name.isEmpty ? older.name : null,
      manufacturer: newer.manufacturer.isEmpty ? older.manufacturer : null,
      model: newer.model.isEmpty ? older.model : null,
      adbSerial: newer.adbSerial ?? older.adbSerial,
      udn: newer.udn ?? older.udn,
      capabilities: keepCaps ? older.capabilities : null,
      capabilitiesCheckedAt: keepCaps ? older.capabilitiesCheckedAt : null,
      lastSeen: newerSeen == null ||
              (olderSeen != null && olderSeen.isAfter(newerSeen))
          ? olderSeen
          : null,
    );
  }

  Future<void> remove(String id) async {
    final before = _tvs.length;
    _tvs.removeWhere((t) => t.id == id);
    if (_tvs.length == before) return;
    if (_activeId == id) _activeId = _tvs.isEmpty ? null : _tvs.first.id;
    await _save();
    notifyListeners();
  }

  /// Sets the active TV; ignored for unknown ids (null clears it).
  Future<void> setActive(String? id) async {
    if (id != null && byId(id) == null) return;
    if (id == _activeId) return;
    _activeId = id;
    await _save();
    notifyListeners();
  }

  Future<void> _save() async {
    await _prefs.setString(
      tvsKey,
      jsonEncode([for (final t in _tvs) t.toJson()]),
    );
    final a = _activeId;
    if (a == null) {
      await _prefs.remove(activeKey);
    } else {
      await _prefs.setString(activeKey, a);
    }
  }
}
