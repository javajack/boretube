import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../actions/actions_service.dart';
import '../adb/adb_identity.dart';
import '../adb/adb_key.dart';
import '../adb/adb_session.dart';
import '../discovery/discovery_service.dart';
import '../discovery/mdns_discovery.dart';
import '../ops/device_profile.dart';
import '../ops/health.dart';
import '../ops/journal.dart';
import '../ops/tv_ops.dart';
import '../platform/multicast_lock.dart';
import '../tv/capabilities.dart';
import '../tv/tv.dart';
import '../tv/tv_store.dart';
import 'agent_providers.dart';
import 'providers.dart';
import 'settings_provider.dart';

// ── Saved TVs ──

/// Loaded in main() via [TvStore.load]; override in ProviderScope.
final tvStoreProvider = ChangeNotifierProvider<TvStore>(
  (ref) => throw UnimplementedError('Override with a loaded TvStore'),
);

final savedTvsProvider =
    Provider<List<Tv>>((ref) => ref.watch(tvStoreProvider).tvs);

final activeTvProvider =
    Provider<Tv?>((ref) => ref.watch(tvStoreProvider).active);

final activeTvIdProvider =
    Provider<String?>((ref) => ref.watch(activeTvProvider)?.id);

/// Where the active TV lives. Changes only when the TV is switched,
/// moves or has its ports edited, so connections survive other updates.
typedef TvAddress = ({
  String id,
  String ip,
  int castPort,
  int dialPort,
  int adbPort,
});

final activeTvAddressProvider = Provider<TvAddress?>((ref) {
  final tv = ref.watch(activeTvProvider);
  if (tv == null) return null;
  return (
    id: tv.id,
    ip: tv.ip,
    castPort: tv.castPort,
    dialPort: tv.dialPort,
    adbPort: tv.adbPort,
  );
});

/// True when the active TV last probed with an authorized ADB.
final activeHasAdbProvider = Provider<bool>(
  (ref) => ref.watch(activeTvProvider)?.can(TvCapability.adb) ?? false,
);

// ── ADB identity and session ──

final secretStoreProvider =
    Provider<SecretStore>((ref) => const SecureSecretStore());

final adbIdentityProvider = Provider<AdbIdentity>(
  (ref) => AdbIdentity(store: ref.watch(secretStoreProvider)),
);

/// The phone's ADB key (generated on first use).
final adbKeyProvider = FutureProvider<AdbKey>(
  (ref) => ref.watch(adbIdentityProvider).load(),
);

/// A lazy session to the active TV: nothing connects until a command
/// runs or [AdbSession.connect] is called. Disposed on TV switch.
final adbSessionProvider = Provider<AdbSession?>((ref) {
  final addr = ref.watch(activeTvAddressProvider);
  final key = ref.watch(adbKeyProvider).valueOrNull;
  final tv = ref.read(activeTvProvider);
  if (addr == null || key == null || tv == null) return null;
  final session = AdbSession(tv: tv, key: key);
  ref.onDispose(() => unawaited(session.dispose()));
  return session;
});

final adbStateProvider = StreamProvider<AdbSessionState>((ref) {
  final s = ref.watch(adbSessionProvider);
  if (s == null) return Stream.value(const AdbDisconnected());
  final out = StreamController<AdbSessionState>();
  out.add(s.state);
  final sub = s.states.listen(out.add);
  ref.onDispose(() {
    sub.cancel();
    out.close();
  });
  return out.stream;
});

// ── Profiles, TvOps, journal ──

final profileRepositoryProvider = FutureProvider<ProfileRepository>(
  (ref) => ProfileRepository.load(rootBundle),
);

final journalProvider = Provider<Journal>(
  (ref) => Journal(Future.value(ref.watch(sharedPrefsProvider))),
);

/// Profile picked for the active TV from its getprop values.
final profileMatchProvider = FutureProvider<ProfileMatch?>((ref) async {
  final session = ref.watch(adbSessionProvider);
  if (session == null || !ref.watch(activeHasAdbProvider)) return null;
  final repo = await ref.watch(profileRepositoryProvider.future);
  return repo.match(await DeviceProps.read(session));
});

/// The only way the UI touches the TV over ADB. Null without ADB.
final tvOpsProvider = FutureProvider<TvOps?>((ref) async {
  final session = ref.watch(adbSessionProvider);
  final addr = ref.watch(activeTvAddressProvider);
  if (session == null || addr == null) return null;
  final match = await ref.watch(profileMatchProvider.future);
  if (match == null) return null;
  final unlocked = ref.watch(
    appSettingsProvider.select(
      (s) => s.maintenanceUnlocked.contains(addr.id),
    ),
  );
  return TvOps(
    adb: session,
    profile: match.profile,
    tvId: addr.id,
    journal: ref.watch(journalProvider),
    maintenanceUnlocked: unlocked,
  );
});

/// Instant actions for the active TV (best transport per capability).
final actionsServiceProvider = Provider<ActionsService?>((ref) {
  final tv = ref.watch(activeTvProvider);
  if (tv == null) return null;
  return ActionsService(
    tv,
    adb: ref.watch(tvOpsProvider).valueOrNull,
    agent: ref.watch(agentForActionsProvider),
  );
});

/// Journal of the active TV, newest first.
final journalEntriesProvider = FutureProvider<List<JournalEntry>>((ref) async {
  final id = ref.watch(activeTvIdProvider);
  if (id == null) return const [];
  final list = await ref.watch(journalProvider).entries(id);
  return list.reversed.toList();
});

final healthProvider = FutureProvider<List<HealthCheck>>((ref) async {
  final ops = await ref.watch(tvOpsProvider.future);
  if (ops == null) return const [];
  final allowYt = ref.watch(
    appSettingsProvider.select((s) => s.allowStockYouTube.contains(ops.tvId)),
  );
  return computeHealth(ops, allowStockYouTube: allowYt);
});

final appsProvider = FutureProvider<List<TvApp>>((ref) async {
  final ops = await ref.watch(tvOpsProvider.future);
  if (ops == null) return const [];
  return ops.listApps();
});

final stockYouTubeStateProvider = FutureProvider<AppState?>((ref) async {
  final ops = await ref.watch(tvOpsProvider.future);
  return ops?.stockYouTubeState();
});

// ── Capabilities ──

final capabilityProberProvider =
    Provider<CapabilityProber>((ref) => CapabilityProber());

/// Last probe report for the active TV (with per-capability detail).
class CapabilityController
    extends StateNotifier<AsyncValue<CapabilityReport?>> {
  final Ref _ref;

  CapabilityController(this._ref) : super(const AsyncValue.data(null));

  /// Probes [tv] (default: the active TV) and saves the result.
  Future<CapabilityReport?> probe([Tv? tv]) async {
    final target = tv ?? _ref.read(activeTvProvider);
    if (target == null) return null;
    state = const AsyncValue.loading();
    try {
      AdbKey? key;
      try {
        key = await _ref
            .read(adbKeyProvider.future)
            .timeout(const Duration(seconds: 30));
      } catch (_) {
        key = null;
      }
      final report =
          await _ref.read(capabilityProberProvider).probe(target, key: key);
      await _ref.read(tvStoreProvider).upsert(report.tv);
      if (mounted) state = AsyncValue.data(report);
      return report;
    } catch (e, st) {
      if (mounted) state = AsyncValue.error(e, st);
      return null;
    }
  }
}

final capabilityProvider =
    StateNotifierProvider<CapabilityController, AsyncValue<CapabilityReport?>>(
        (ref) {
  ref.watch(activeTvIdProvider);
  return CapabilityController(ref);
});

// ── Discovery ──

final multicastLockProvider =
    Provider<MulticastLock>((ref) => const MulticastLock());

final discoveryServiceProvider = Provider<DiscoveryService>((ref) {
  final lock = ref.watch(multicastLockProvider);
  return DiscoveryService(
    mdns: MdnsDiscovery(
      acquireMulticastLock: lock.acquire,
      releaseMulticastLock: lock.release,
    ),
  );
});

// ── App-wide messages (snackbars from background work) ──

final appMessagesProvider = Provider<StreamController<String>>((ref) {
  final c = StreamController<String>.broadcast();
  ref.onDispose(c.close);
  return c;
});

/// Whether the app is in the foreground (set by the app lifecycle).
final appForegroundProvider = StateProvider<bool>((ref) => true);
