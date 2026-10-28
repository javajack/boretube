import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../agent/agent_client.dart';
import '../agent/agent_installer.dart';
import '../ops/baseline.dart';
import '../ops/journal.dart';
import '../ops/restore_planner.dart';
import 'providers.dart';
import 'tv_providers.dart';

// ── token and client ──

final agentTokenStoreProvider = Provider<AgentTokenStore>(
  (ref) => AgentTokenStore(ref.watch(secretStoreProvider)),
);

/// The saved agent token for the active TV; null when TV Guard was never
/// installed from this phone. Invalidate after install/repair/uninstall.
final agentTokenProvider = FutureProvider<String?>((ref) async {
  final id = ref.watch(activeTvIdProvider);
  if (id == null) return null;
  return ref.watch(agentTokenStoreProvider).read(id);
});

/// Shared HTTP client for agent calls; tests override it.
final agentHttpClientProvider = Provider<http.Client>((ref) {
  final c = http.Client();
  ref.onDispose(c.close);
  return c;
});

/// Client for the active TV's agent, or null without a token.
final agentClientProvider = Provider<AgentClient?>((ref) {
  final addr = ref.watch(activeTvAddressProvider);
  final token = ref.watch(agentTokenProvider).valueOrNull;
  final port = ref.watch(activeTvProvider.select((t) => t?.agentPort));
  if (addr == null || token == null) return null;
  return AgentClient(
    host: addr.ip,
    port: port ?? AgentClient.defaultPort,
    token: token,
    httpClient: ref.watch(agentHttpClientProvider),
  );
});

// ── live status ──

enum AgentLinkKind {
  /// No TV Guard paired with this phone for this TV.
  none,

  /// Paired; first status not back yet.
  checking,
  up,

  /// The agent answers but rejects our token (it was reinstalled).
  authFailed,

  /// Paired, but not answering.
  down,
}

class AgentLink {
  final AgentLinkKind kind;
  final AgentStatus? status;
  final DateTime? lastOk;
  final String? error;

  const AgentLink(this.kind, {this.status, this.lastOk, this.error});

  static const none = AgentLink(AgentLinkKind.none);

  bool get installed => kind != AgentLinkKind.none;
  bool get up => kind == AgentLinkKind.up && status != null;

  /// Reachable and enforcing (not safe mode): route actions through it.
  bool get healthy => up && status!.mode != AgentMode.safe;
}

/// Polls `/v1/status` every [interval] while the app is in front.
class AgentStatusNotifier extends StateNotifier<AgentLink> {
  final AgentClient? client;
  final Duration interval;
  final DateTime Function() clock;
  Timer? _timer;
  bool _busy = false;
  int _failures = 0;

  AgentStatusNotifier({
    required this.client,
    required bool active,
    this.interval = const Duration(seconds: 5),
    this.clock = DateTime.now,
  }) : super(
          client == null
              ? AgentLink.none
              : const AgentLink(AgentLinkKind.checking),
        ) {
    if (client != null && active) {
      refresh();
      _timer = Timer.periodic(interval, (_) => refresh());
    }
  }

  /// A fixed value; for tests and previews.
  AgentStatusNotifier.fixed(super.state)
      : client = null,
        interval = const Duration(days: 1),
        clock = DateTime.now;

  Future<void> refresh() async {
    final c = client;
    if (c == null || _busy) return;
    _busy = true;
    try {
      final s = await c.status();
      _failures = 0;
      if (mounted) {
        state = AgentLink(AgentLinkKind.up, status: s, lastOk: clock());
      }
    } on AgentAuthException catch (e) {
      if (mounted) {
        state = AgentLink(
          AgentLinkKind.authFailed,
          status: state.status,
          lastOk: state.lastOk,
          error: e.message,
        );
      }
    } catch (e) {
      _failures++;
      // One miss keeps the last picture; two in a row is "down".
      if (mounted && (_failures >= 2 || state.status == null)) {
        state = AgentLink(
          _failures >= 2 ? AgentLinkKind.down : AgentLinkKind.checking,
          status: state.status,
          lastOk: state.lastOk,
          error: e is AgentException ? e.message : '$e',
        );
      }
    } finally {
      _busy = false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final agentStatusProvider =
    StateNotifierProvider<AgentStatusNotifier, AgentLink>((ref) {
  final client = ref.watch(agentClientProvider);
  final active = ref.watch(appForegroundProvider);
  return AgentStatusNotifier(client: client, active: active);
});

/// TV Guard is paired with this TV (whatever its state).
final hasAgentProvider = Provider<bool>(
  (ref) => ref.watch(agentStatusProvider.select((l) => l.installed)),
);

/// The client to route instant actions through, or null to use ADB/Cast.
final agentForActionsProvider = Provider<AgentClient?>((ref) {
  final healthy = ref.watch(agentStatusProvider.select((l) => l.healthy));
  return healthy ? ref.watch(agentClientProvider) : null;
});

// ── status pill ──

enum GuardState {
  on,
  limited,
  paused,
  down,
  safe,
  onBreak,
  classic,
  notGuarded,
  checking,
}

/// One state for the top-bar pill.
GuardState guardStateOf({
  required AgentLink link,
  required bool onBreak,
  required bool classic,
}) {
  if (!link.installed) {
    if (onBreak) return GuardState.onBreak;
    return classic ? GuardState.classic : GuardState.notGuarded;
  }
  final s = link.status;
  switch (link.kind) {
    case AgentLinkKind.none:
      return GuardState.notGuarded;
    case AgentLinkKind.down:
    case AgentLinkKind.authFailed:
      return GuardState.down;
    case AgentLinkKind.checking:
      if (s == null) return onBreak ? GuardState.onBreak : GuardState.checking;
    case AgentLinkKind.up:
      break;
  }
  if (s!.mode == AgentMode.safe) return GuardState.safe;
  if (onBreak || s.breakState.active) return GuardState.onBreak;
  if (s.mode == AgentMode.paused) return GuardState.paused;
  if (s.isLimited) return GuardState.limited;
  return GuardState.on;
}

// ── installer ──

final agentBundleLoaderProvider = Provider<Future<AgentBundle> Function()>(
  (ref) => () => AgentBundle.load(rootBundle),
);

/// Whether the APK is in this build (null while checking).
final agentBundleProvider = FutureProvider<AgentManifest?>((ref) async {
  try {
    return (await ref.watch(agentBundleLoaderProvider)()).manifest;
  } on AgentBundleMissing {
    return null;
  }
});

final agentInstallerProvider = FutureProvider<AgentInstaller?>((ref) async {
  final session = ref.watch(adbSessionProvider);
  final addr = ref.watch(activeTvAddressProvider);
  if (session == null || addr == null) return null;
  final ops = await ref.watch(tvOpsProvider.future);
  final port = ref.read(activeTvProvider)?.agentPort ?? AgentClient.defaultPort;
  final http = ref.watch(agentHttpClientProvider);
  return AgentInstaller(
    adb: session,
    tvId: addr.id,
    tokens: ref.watch(agentTokenStoreProvider),
    clientFor: (token) => AgentClient(
      host: addr.ip,
      port: port,
      token: token,
      httpClient: http,
    ),
    loadBundle: ref.watch(agentBundleLoaderProvider),
    profile: ops?.profile.raw ?? const {},
    journal: ref.watch(journalProvider),
  );
});

// ── journal ──

/// The agent's journal (newest first); empty without a reachable agent.
final agentJournalProvider =
    FutureProvider<List<AgentJournalEntry>>((ref) async {
  final c = ref.watch(agentClientProvider);
  if (c == null) return const [];
  try {
    final list = await c.journal();
    return list..sort((a, b) => b.time.compareTo(a.time));
  } on AgentException {
    return const [];
  }
});

/// One Activity row: a journal entry and who made it.
class ActivityItem {
  final JournalEntry entry;
  final JournalSource source;
  const ActivityItem(this.entry, this.source);
}

JournalEntry agentEntryToJournal(String tvId, AgentJournalEntry e) =>
    JournalEntry(
      tvId: tvId,
      time: e.time,
      op: e.op,
      target: e.target,
      before: e.before,
      after: e.after,
      ok: e.ok,
    );

/// Phone and agent journals merged, newest first.
/// A watchdog run that found nothing to do ("0/0 ops ok, 0 pending") is
/// noise in Activity; real fixes and failures still show.
bool isNoOpWatchdogRun(AgentJournalEntry e) =>
    e.op == 'watchdog' &&
    e.ok &&
    RegExp(r'^\s*0/0 ops ok, 0 pending').hasMatch(e.after);

final activityProvider = FutureProvider<List<ActivityItem>>((ref) async {
  final id = ref.watch(activeTvIdProvider) ?? '';
  final phone = await ref.watch(journalEntriesProvider.future);
  final agent = await ref.watch(agentJournalProvider.future);
  final all = [
    for (final e in phone) ActivityItem(e, JournalSource.phone),
    for (final e in agent)
      if (!isNoOpWatchdogRun(e))
        ActivityItem(agentEntryToJournal(id, e), e.source),
  ]..sort((a, b) => b.entry.time.compareTo(a.entry.time));
  return all;
});

/// When the app was last opened before this launch (for "While you were
/// away"). Read once and stamped with now.
final previousVisitProvider = Provider<DateTime?>((ref) {
  const key = 'app.lastVisit';
  final prefs = ref.watch(sharedPrefsProvider);
  final prev = DateTime.tryParse(prefs.getString(key) ?? '');
  unawaited(prefs.setString(key, DateTime.now().toIso8601String()));
  return prev;
});

// ── baseline and restore ──

final baselineStoreProvider = Provider<BaselineStore>(
  (ref) => BaselineStore(ref.watch(sharedPrefsProvider)),
);

/// The active TV's baseline. Captured on the first ADB connection.
final baselineProvider = FutureProvider<TvBaseline?>((ref) async {
  final id = ref.watch(activeTvIdProvider);
  if (id == null) return null;
  final store = ref.watch(baselineStoreProvider);
  final have = store.read(id);
  if (have != null) return have;
  final ops = await ref.watch(tvOpsProvider.future);
  if (ops == null) return null;
  return store.captureIfMissing(ops);
});

final restoreRunnerProvider = FutureProvider<RestoreRunner?>((ref) async {
  final ops = await ref.watch(tvOpsProvider.future);
  if (ops == null) return null;
  return RestoreRunner(ops, journal: ref.watch(journalProvider));
});

typedef RestoreRequest = ({RestoreTarget target, bool removeHelper});

final restorePlanProvider =
    FutureProvider.autoDispose.family<RestorePlan?, RestoreRequest>(
  (ref, req) async {
    final runner = await ref.watch(restoreRunnerProvider.future);
    if (runner == null) return null;
    final baseline = await ref.watch(baselineProvider.future);
    return runner.plan(
      req.target,
      baseline: baseline,
      removeLauncherHelper: req.removeHelper,
    );
  },
);
