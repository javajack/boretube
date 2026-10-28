import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../actions/actions_service.dart';
import '../discovery/discovery_service.dart';
import '../ops/tv_ops.dart';
import '../services/lock_service.dart';
import '../services/tv_service.dart';
import '../tv/tv.dart';
import '../tv/tv_store.dart';
import 'providers.dart';
import 'settings_provider.dart';
import 'tv_providers.dart';

/// What the active TV is doing right now.
class NowPlaying {
  final bool loading;
  final bool online;

  /// Android package (ADB) or Cast app id.
  final String? id;
  final String appName;
  final bool isHome;

  /// 0–100, when known.
  final int? volume;
  final bool? muted;
  final DateTime? lastSeen;

  /// `adb` or `cast`.
  final String? source;

  const NowPlaying({
    this.loading = false,
    this.online = false,
    this.id,
    this.appName = '',
    this.isHome = false,
    this.volume,
    this.muted,
    this.lastSeen,
    this.source,
  });

  static const initial = NowPlaying(loading: true);

  NowPlaying offline() => NowPlaying(lastSeen: lastSeen, appName: appName);
}

/// Friendly names for common TV packages.
const _knownApps = {
  'org.smarttube.stable': 'SmartTube',
  'org.smarttube.beta': 'SmartTube Beta',
  'com.teamsmart.videomanager.tv': 'SmartTube',
  'com.google.android.youtube.tv': 'YouTube',
  'com.google.android.youtube.tvkids': 'YouTube Kids',
  'com.google.android.apps.youtube.music': 'YouTube Music',
  'com.netflix.ninja': 'Netflix',
  'com.amazon.amazonvideo.livingroom': 'Prime Video',
  'com.disney.disneyplus': 'Disney+',
  'in.startv.hotstar': 'JioHotstar',
  'com.google.android.videos': 'Google TV',
  'com.spotify.tv.android': 'Spotify',
  'com.plexapp.android': 'Plex',
  'org.xbmc.kodi': 'Kodi',
  'com.android.vending': 'Play Store',
  'com.android.tv.settings': 'Settings',
  'com.sony.dtv.tvx': 'Sony TV',
};

const _homePackages = {
  'com.google.android.apps.tv.launcherx',
  'com.google.android.tvlauncher',
  'com.google.android.leanbacklauncher',
};

/// "SmartTube" for known packages, else a tidy last segment.
String appLabel(String pkg) {
  final known = _knownApps[pkg];
  if (known != null) return known;
  final parts = pkg.split('.');
  var last = parts.isEmpty ? pkg : parts.last;
  if (last == 'tv' || last == 'android' || last == 'app') {
    last = parts.length > 1 ? parts[parts.length - 2] : last;
  }
  if (last.isEmpty) return pkg;
  return last[0].toUpperCase() + last.substring(1);
}

typedef NowPlayingFetch = Future<NowPlaying?> Function();

/// Polls [fetch] every [interval] while [active]; after two failures in a
/// row calls [onUnreachable] (relocation).
class NowPlayingNotifier extends StateNotifier<NowPlaying> {
  final NowPlayingFetch? fetch;
  final Duration interval;
  final void Function()? onUnreachable;
  final void Function(DateTime seen)? onSeen;
  Timer? _timer;
  bool _busy = false;
  int _failures = 0;

  NowPlayingNotifier({
    required this.fetch,
    required this.interval,
    required bool active,
    NowPlaying initial = NowPlaying.initial,
    this.onUnreachable,
    this.onSeen,
  }) : super(initial) {
    if (fetch == null) {
      state = initial.offline();
    } else if (active) {
      refresh();
      _timer = Timer.periodic(interval, (_) => refresh());
    }
  }

  /// A fixed value; for tests and previews.
  NowPlayingNotifier.fixed(super.state)
      : fetch = null,
        interval = const Duration(days: 1),
        onUnreachable = null,
        onSeen = null;

  Future<void> refresh() async {
    final f = fetch;
    if (f == null || _busy) return;
    _busy = true;
    try {
      final r = await f();
      if (!mounted) return;
      if (r != null) {
        _failures = 0;
        state = r;
        onSeen?.call(r.lastSeen ?? DateTime.now());
      } else {
        _fail();
      }
    } catch (_) {
      if (mounted) _fail();
    } finally {
      _busy = false;
    }
  }

  void _fail() {
    _failures++;
    state = state.offline();
    if (_failures == 2) onUnreachable?.call();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

/// Reads now-playing over ADB, falling back to Cast + Sony REST.
Future<NowPlaying?> readNowPlaying({
  TvOps? ops,
  TvService? cast,
  DateTime Function() clock = DateTime.now,
}) async {
  if (ops != null) {
    try {
      final pkg = await ops.foregroundPackage();
      final v = await ops.readVolume();
      final home = pkg == null ||
          _homePackages.contains(pkg) ||
          pkg == ops.profile.launcher?.pkg;
      return NowPlaying(
        online: true,
        id: pkg,
        appName: home ? 'Home screen' : appLabel(pkg),
        isHome: home,
        volume: v?.percent,
        muted: v?.muted,
        lastSeen: clock(),
        source: 'adb',
      );
    } catch (_) {
      // Fall back to Cast.
    }
  }
  final status = await cast?.getStatus();
  if (status == null) return null;
  return NowPlaying(
    online: true,
    id: status.appId.isEmpty ? null : status.appId,
    appName: status.isIdle ? 'Home screen' : status.appName,
    isHome: status.isIdle,
    volume: status.volume,
    muted: status.muted,
    lastSeen: clock(),
    source: 'cast',
  );
}

final nowPlayingProvider =
    StateNotifierProvider<NowPlayingNotifier, NowPlaying>((ref) {
  final addr = ref.watch(activeTvAddressProvider);
  final active = ref.watch(appForegroundProvider);
  final seconds = ref.watch(appSettingsProvider.select((s) => s.pollSeconds));
  final ops = ref.watch(tvOpsProvider).valueOrNull;
  final cast = ref.watch(tvServiceProvider);
  final tv = ref.read(activeTvProvider);
  final initial = NowPlaying(loading: true, lastSeen: tv?.lastSeen);
  if (addr == null) {
    return NowPlayingNotifier(
      fetch: null,
      interval: const Duration(days: 1),
      active: false,
      initial: const NowPlaying(),
    );
  }
  DateTime? persisted = tv?.lastSeen;
  return NowPlayingNotifier(
    fetch: () => readNowPlaying(ops: ops, cast: cast),
    interval: Duration(seconds: seconds),
    active: active,
    initial: initial,
    onUnreachable: () => ref.read(relocatorProvider).relocateActive(),
    onSeen: (seen) {
      // Persist lastSeen at most every 10 minutes.
      final last = persisted;
      if (last != null && seen.difference(last).inMinutes < 10) return;
      persisted = seen;
      final store = ref.read(tvStoreProvider);
      final cur = store.byId(addr.id);
      if (cur != null) unawaited(store.upsert(cur.copyWith(lastSeen: seen)));
    },
  );
});

// ── Relocation ──

/// Finds the active TV again after it stops answering, e.g. a new DHCP
/// lease, and tells the user where it went.
class Relocator {
  final TvStore store;
  final DiscoveryService discovery;
  final void Function(String message) notify;
  final Duration minGap;
  DateTime? _lastTry;
  bool _busy = false;

  Relocator({
    required this.store,
    required this.discovery,
    required this.notify,
    this.minGap = const Duration(minutes: 2),
  });

  Future<Tv?> relocateActive() async {
    final saved = store.active;
    if (saved == null || _busy) return null;
    final now = DateTime.now();
    final last = _lastTry;
    if (last != null && now.difference(last) < minGap) return null;
    _lastTry = now;
    _busy = true;
    try {
      final found = await discovery.relocate(saved);
      if (found == null || found.ip == saved.ip) return found;
      await store.upsert(found);
      if (found.id != saved.id && store.byId(saved.id) != null) {
        await store.remove(saved.id);
      }
      await store.setActive(found.id);
      notify('${saved.name} moved to ${shortIp(found.ip)}');
      return found;
    } catch (_) {
      return null;
    } finally {
      _busy = false;
    }
  }

  /// ".7" when only the last octet changed is the common case; keep the
  /// full address otherwise readable.
  static String shortIp(String ip) {
    final i = ip.lastIndexOf('.');
    return i < 0 ? ip : ip.substring(i);
  }
}

final relocatorProvider = Provider<Relocator>((ref) {
  final messages = ref.watch(appMessagesProvider);
  return Relocator(
    store: ref.watch(tvStoreProvider),
    discovery: ref.watch(discoveryServiceProvider),
    notify: messages.add,
  );
});

// ── Pause TV ──

/// An active "Pause TV" (stop + mute) and when it ends. P1 keeps it in
/// memory and restores when the timer fires while the app is alive.
class PauseState {
  final DateTime? until;
  const PauseState([this.until]);
  bool get active => until != null && until!.isAfter(DateTime.now());
}

class PauseController extends StateNotifier<PauseState> {
  final ActionsService? Function() _actions;
  Timer? _timer;

  PauseController(this._actions) : super(const PauseState());

  Future<ActionResult?> pause(int minutes) async {
    final a = _actions();
    if (a == null) return null;
    final r = await a.pauseTv(minutes);
    final until = r.until;
    if (r.ok && until != null && mounted) {
      state = PauseState(until);
      _timer?.cancel();
      _timer = Timer(until.difference(DateTime.now()), () {
        unawaited(restore());
      });
    }
    return r;
  }

  Future<ActionResult?> restore() async {
    _timer?.cancel();
    if (mounted) state = const PauseState();
    return _actions()?.restore();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final pauseProvider =
    StateNotifierProvider<PauseController, PauseState>((ref) {
  ref.watch(activeTvIdProvider);
  return PauseController(() => ref.read(actionsServiceProvider));
});

// ── Classic lock state ──

final classicLockActiveProvider = StreamProvider<bool>((ref) {
  final LockService ls = ref.watch(lockServiceProvider);
  final out = StreamController<bool>();
  out.add(ls.isActive);
  final sub = ls.activeStream.listen(out.add);
  ref.onDispose(() {
    sub.cancel();
    out.close();
  });
  return out.stream;
});
