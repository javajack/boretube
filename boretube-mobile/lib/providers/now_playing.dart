import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../discovery/discovery_service.dart';
import '../ops/tv_ops.dart';
import '../services/lock_service.dart';
import '../services/tv_service.dart';
import '../tv/presence.dart';
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

  /// The screen is off (standby): ADB's wakefulness or Cast's isStandBy.
  /// Null when the source can't tell.
  final bool? asleep;

  /// When the TV was seen waking (from standby, or back from unreachable);
  /// null when it was already awake when we first looked.
  final DateTime? awakeSince;

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
    this.asleep,
    this.awakeSince,
  });

  static const initial = NowPlaying(loading: true);

  static const _keep = Object();

  /// Pass `null` explicitly to clear [id], [volume] or [muted].
  NowPlaying copyWith({
    Object? id = _keep,
    String? appName,
    bool? isHome,
    Object? volume = _keep,
    Object? muted = _keep,
  }) =>
      NowPlaying(
        loading: loading,
        online: online,
        id: identical(id, _keep) ? this.id : id as String?,
        appName: appName ?? this.appName,
        isHome: isHome ?? this.isHome,
        volume: identical(volume, _keep) ? this.volume : volume as int?,
        muted: identical(muted, _keep) ? this.muted : muted as bool?,
        lastSeen: lastSeen,
        source: source,
        asleep: asleep,
        awakeSince: awakeSince,
      );

  /// The same reading, with [awakeSince] set.
  NowPlaying withAwakeSince(DateTime? since) => NowPlaying(
        loading: loading,
        online: online,
        id: id,
        appName: appName,
        isHome: isHome,
        volume: volume,
        muted: muted,
        lastSeen: lastSeen,
        source: source,
        asleep: asleep,
        awakeSince: since,
      );

  /// Puts back the fields that differ between [before] and [applied],
  /// keeping everything else (e.g. another action's optimistic change).
  NowPlaying restoreFrom(NowPlaying before, NowPlaying applied) => copyWith(
        id: before.id != applied.id ? before.id : _keep,
        appName: before.appName != applied.appName ? before.appName : null,
        isHome: before.isHome != applied.isHome ? before.isHome : null,
        volume: before.volume != applied.volume ? before.volume : _keep,
        muted: before.muted != applied.muted ? before.muted : _keep,
      );

  /// After Stop: the TV is on its home screen.
  NowPlaying atHome() =>
      copyWith(id: null, appName: 'Home screen', isHome: true);

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
  'com.google.android.youtube.tvmusic': 'YouTube Music',
  'com.android.tv': 'Live TV',
  'com.sonyliv': 'SonyLIV',
  'com.apple.atve.androidtv.appletv': 'Apple TV',
  'com.gathin.tvhome': 'Home (custom launcher)',
  'com.google.android.apps.tv.launcherx': 'Google TV home',
  'com.google.android.apps.tv.dreamx': 'Ambient screensaver',
  'com.google.android.tts': 'Speech Services',
  'com.google.android.katniss': 'Google Assistant',
  'com.google.android.tungsten.setupwraith': 'Setup wizard',
  'com.android.adservices.api': 'Ad services',
  'com.android.federatedcompute.services': 'Federated compute',
  'com.android.ondevicepersonalization.services': 'On-device personalization',
  'com.google.android.syncadapters.calendar': 'Calendar sync',
  'com.google.android.feedback': 'Feedback reporter',
  'com.google.android.play.games': 'Play Games',
  'com.google.android.partnersetup': 'Partner setup',
  'com.google.android.onetimeinitializer': 'One-time initializer',
  'com.android.printspooler': 'Print spooler',
  'android.autoinstalls.config.google.gtvpai': 'Partner auto-installs',
  'com.android.gallery3d': 'Gallery',
  'com.sony.dtv.promos': 'Sony promos',
  'com.sony.dtv.sonyselect': 'Sony Select',
  'com.sony.dtv.sonytab': 'Sony tab',
  'com.sony.dtv.multiscreendemo': 'Store demo',
  'com.sony.dtv.smarthelp': 'Sony help',
  'com.sony.dtv.helpguidecontents': 'Help guide',
  'com.sonypicturescore': 'Sony Pictures Core',
  'com.sony.dtv.ecodashboard': 'Eco dashboard',
  'com.sony.dtv.timers': 'Timers',
  'com.realtek.tvmediaplay': 'Media player',
  'com.rakesh.boretube.agent': 'TV Guard',
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

/// Undoes one optimistic change; see [NowPlayingNotifier.patch].
typedef NowPlayingUndo = NowPlaying Function(NowPlaying current);

/// Polls [fetch] every [interval] while [active]; after two failures in a
/// row calls [onUnreachable] (relocation).
///
/// Actions show their effect at once with [patch], and [hold] the poll
/// while they run so a stale reading can't flip the UI back; [release]
/// reconciles with one refresh [settleDelay] later.
class NowPlayingNotifier extends StateNotifier<NowPlaying> {
  final NowPlayingFetch? fetch;
  final Duration interval;
  final Duration settleDelay;
  final void Function()? onUnreachable;
  final void Function(DateTime seen)? onSeen;
  final DateTime Function() clock;
  Timer? _timer;
  Timer? _settle;
  bool _busy = false;
  int _failures = 0;
  int _holds = 0;
  int _epoch = 0;

  NowPlayingNotifier({
    required this.fetch,
    required this.interval,
    required bool active,
    NowPlaying initial = NowPlaying.initial,
    this.settleDelay = const Duration(milliseconds: 300),
    this.onUnreachable,
    this.onSeen,
    this.clock = DateTime.now,
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
        settleDelay = Duration.zero,
        onUnreachable = null,
        onSeen = null,
        clock = DateTime.now;

  /// True while an action holds the poll.
  bool get held => _holds > 0;

  /// Shows [change] now. Returns how to undo just that change.
  NowPlayingUndo patch(NowPlaying Function(NowPlaying s) change) {
    final before = state;
    final applied = change(before);
    _epoch++;
    state = applied;
    return (current) => current.restoreFrom(before, applied);
  }

  /// Rolls back a failed optimistic change.
  void revert(NowPlayingUndo undo) {
    if (!mounted) return;
    _epoch++;
    state = undo(state);
  }

  /// Skips polls until the matching [release].
  void hold() {
    _holds++;
    _settle?.cancel();
  }

  /// Ends a [hold]; the last one schedules a reconciling refresh.
  void release() {
    if (_holds > 0) _holds--;
    if (_holds > 0 || !mounted || fetch == null) return;
    _settle?.cancel();
    _settle = Timer(settleDelay, refresh);
  }

  Future<void> refresh() async {
    final f = fetch;
    if (f == null || _busy || _holds > 0) return;
    _busy = true;
    final epoch = _epoch;
    try {
      final r = await f();
      if (!mounted) return;
      if (r != null) {
        _failures = 0;
        // An action changed the picture mid-read: this reading predates
        // it. The refresh after the action will reconcile.
        if (epoch != _epoch || _holds > 0) return;
        state = r.withAwakeSince(_awakeSince(state, r));
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

  /// Waking is a change we saw: asleep or unreachable before, awake now.
  /// Awake on the very first reading means "since before we looked" (null).
  DateTime? _awakeSince(NowPlaying before, NowPlaying r) {
    if (r.asleep == true) return null;
    if (before.loading) return null;
    if (before.online && before.asleep != true) return before.awakeSince;
    return clock();
  }

  void _fail() {
    _failures++;
    state = state.offline();
    if (_failures == 2) onUnreachable?.call();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _settle?.cancel();
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
      final st = await ops.status();
      final pkg = st.foreground;
      final v = st.volume;
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
        asleep: st.awake == null ? null : !st.awake!,
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
    asleep: status.standby,
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
      // upsert merges it into the saved entry and says which id it kept. A
      // temporary ip: entry at the old address is the one thing to drop.
      final id = await store.upsert(found);
      if (id != saved.id && saved.id.startsWith('ip:')) {
        await store.remove(saved.id);
      }
      await store.setActive(id);
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

/// The active TV's power state (on, waking, asleep, unreachable), from the
/// now-playing poll; re-read on every poll, so "waking" expires by itself.
final tvPresenceProvider = Provider<TvPresence>(
  (ref) => presenceOf(ref.watch(nowPlayingProvider), DateTime.now()),
);
