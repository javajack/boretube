// The Always On watch: a WorkManager job (about every 15 minutes, with
// a network) asks each Always On TV for `/v1/status` and posts a local
// notification when one stops, and again when it is back. No ADB: only
// the HTTP client and the tokens saved at install.

import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import '../adb/adb_identity.dart';
import '../agent/agent_client.dart';
import '../agent/agent_installer.dart';
import '../protocols/castv2_client.dart';
import '../providers/providers.dart';
import '../tv/tv.dart';
import '../tv/tv_store.dart';
import 'watch_logic.dart';

// ── Persisted state ──

/// The parent's choice: null until asked, then on or off.
const kAlertsKey = 'alerts.alwaysOn';

String watchStateKey(String tvId) => 'watch.state.$tvId';

/// When the watch last ran (for Settings › Advanced).
const kWatchLastRunKey = 'watch.lastRun';

// ── Platform seams (faked in tests) ──

/// Posts and opens local notifications.
abstract class AlertNotifier {
  /// Sets up the channel; [onOpen] gets the payload of a tapped alert.
  Future<void> init({void Function(String? payload)? onOpen});

  Future<void> show({
    required int id,
    required String title,
    required String body,
    String? payload,
  });

  /// The payload of the alert that launched the app, if any.
  Future<String?> launchPayload();

  /// Whether this phone lets boretube post notifications (null: unknown).
  Future<bool?> enabled();

  /// Asks for permission (Android 13+). True when allowed.
  Future<bool> requestPermission();
}

/// Schedules the periodic check.
abstract class WatchScheduler {
  Future<void> schedule({bool replace = false});
  Future<void> cancel();
}

class LocalAlertNotifier implements AlertNotifier {
  static const channelId = 'always_on_alerts';
  static const channelName = 'Always On alerts';

  final FlutterLocalNotificationsPlugin _plugin;
  bool _ready = false;

  LocalAlertNotifier([FlutterLocalNotificationsPlugin? plugin])
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  @override
  Future<void> init({void Function(String? payload)? onOpen}) async {
    if (_ready) return;
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('ic_stat_boretube'),
        ),
        onDidReceiveNotificationResponse:
            onOpen == null ? null : (r) => onOpen(r.payload),
      );
      await _android?.createNotificationChannel(
        const AndroidNotificationChannel(
          channelId,
          channelName,
          description: 'Tells you when Always On stops on a TV, and when '
              'it\'s back.',
          importance: Importance.high,
        ),
      );
      _ready = true;
    } catch (e) {
      debugPrint('alerts: init failed: $e');
    }
  }

  @override
  Future<void> show({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    await init();
    await _plugin.show(
      id: id,
      title: title,
      body: body,
      payload: payload,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          importance: Importance.high,
          priority: Priority.high,
          category: AndroidNotificationCategory.status,
          color: const Color(0xFFF05A39),
          styleInformation: BigTextStyleInformation(body),
          autoCancel: true,
        ),
      ),
    );
  }

  @override
  Future<String?> launchPayload() async {
    try {
      final d = await _plugin.getNotificationAppLaunchDetails();
      if (d == null || !d.didNotificationLaunchApp) return null;
      return d.notificationResponse?.payload;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<bool?> enabled() async {
    try {
      return await _android?.areNotificationsEnabled();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<bool> requestPermission() async {
    try {
      return await _android?.requestNotificationsPermission() ?? true;
    } catch (_) {
      return false;
    }
  }
}

class WorkmanagerScheduler implements WatchScheduler {
  static const uniqueName = 'boretube.alwaysOnWatch';
  static const taskName = 'alwaysOnWatch';
  static bool _initialized = false;

  static Future<void> _init() async {
    if (_initialized) return;
    await Workmanager().initialize(alwaysOnWatchDispatcher);
    _initialized = true;
  }

  @override
  Future<void> schedule({bool replace = false}) async {
    try {
      await _init();
      await Workmanager().registerPeriodicTask(
        uniqueName,
        taskName,
        frequency: const Duration(minutes: 15),
        initialDelay: const Duration(minutes: 2),
        constraints: Constraints(networkType: NetworkType.connected),
        // `keep` on every launch so the timer isn't reset; `update` when
        // the parent turns alerts on again.
        existingWorkPolicy: replace
            ? ExistingPeriodicWorkPolicy.update
            : ExistingPeriodicWorkPolicy.keep,
      );
    } catch (e) {
      debugPrint('alerts: schedule failed: $e');
    }
  }

  @override
  Future<void> cancel() async {
    try {
      await _init();
      await Workmanager().cancelByUniqueName(uniqueName);
    } catch (e) {
      debugPrint('alerts: cancel failed: $e');
    }
  }
}

// ── The check ──

/// A stable small id per TV, so a TV's alerts replace each other instead
/// of stacking up.
int alertIdFor(String tvId) =>
    1000 + tvId.codeUnits.fold<int>(0, (a, b) => (a * 31 + b) & 0xffff);

/// What the TV itself says when its helper doesn't answer.
enum TvPower {
  awake,
  asleep,

  /// Nothing answers: no power, or this phone isn't on the TV's Wi-Fi.
  gone,

  /// It can't tell (no Cast on this TV).
  unknown,
}

/// Asks Cast, which stays up in standby (`isStandBy`) while Android pauses
/// TV Guard. Measured on the VU3, 2026-10-29.
Future<TvPower> castPowerOf(Tv tv) async {
  if (!tv.can(TvCapability.cast)) return TvPower.unknown;
  final c = CastV2Client(host: tv.ip, port: tv.castPort);
  try {
    final st = await c.getStatus().timeout(const Duration(seconds: 8));
    if (st == null) return TvPower.unknown;
    return st['standby'] == true ? TvPower.asleep : TvPower.awake;
  } on SocketException {
    return TvPower.gone;
  } on TimeoutException {
    return TvPower.gone;
  } catch (_) {
    return TvPower.unknown;
  } finally {
    await c.disconnect();
  }
}

/// Checks every saved TV with an Always On token once. Returns the alerts
/// posted. Pure apart from [statusOf], [powerOf] and [notifier].
///
/// A helper that doesn't answer only counts as a miss while the TV is
/// awake (or can't say): standby and a TV that's off answer nothing, and
/// neither is something to fix.
Future<List<WatchAlert>> runWatchOnce({
  required SharedPreferences prefs,
  required List<Tv> tvs,
  required Future<String?> Function(String tvId) tokenFor,
  required Future<AgentStatus> Function(Tv tv, String token) statusOf,
  required AlertNotifier notifier,
  Future<TvPower> Function(Tv tv) powerOf = castPowerOf,
  DateTime Function() clock = DateTime.now,
}) async {
  final posted = <WatchAlert>[];
  for (final tv in tvs) {
    final token = await tokenFor(tv.id);
    if (token == null) continue;
    WatchObservation obs;
    try {
      obs = classifyStatus(await statusOf(tv, token));
    } on AgentAuthException {
      obs = WatchObservation.authFailed;
    } catch (_) {
      obs = switch (await powerOf(tv)) {
        TvPower.asleep => WatchObservation.asleep,
        TvPower.gone => WatchObservation.away,
        TvPower.awake || TvPower.unknown => WatchObservation.unreachable,
      };
    }
    final prev = WatchState.decode(prefs.getString(watchStateKey(tv.id)));
    final (next, alert) = watchStep(prev, obs);
    if (next != prev) {
      await prefs.setString(watchStateKey(tv.id), next.encode());
    }
    if (alert != null) {
      final c = alertCopy(alert, tv.name);
      try {
        await notifier.show(
          id: alertIdFor(tv.id),
          title: c.title,
          body: c.body,
          payload: tv.id,
        );
        posted.add(alert);
      } catch (e) {
        debugPrint('alerts: show failed: $e');
      }
    }
  }
  await prefs.setString(kWatchLastRunKey, clock().toIso8601String());
  return posted;
}

/// WorkManager's entry point (runs in a background isolate).
@pragma('vm:entry-point')
void alwaysOnWatchDispatcher() {
  Workmanager().executeTask((task, input) async {
    DartPluginRegistrant.ensureInitialized();
    final client = http.Client();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      if (prefs.getBool(kAlertsKey) != true) return true;
      final store = await TvStore.load(prefs: prefs);
      final tokens = AgentTokenStore(const SecureSecretStore());
      await runWatchOnce(
        prefs: prefs,
        tvs: store.tvs,
        tokenFor: tokens.read,
        statusOf: (tv, token) => AgentClient(
          host: tv.ip,
          port: tv.agentPort,
          token: token,
          httpClient: client,
        ).status(),
        notifier: LocalAlertNotifier(),
      );
      return true;
    } catch (e) {
      debugPrint('alerts: watch failed: $e');
      return true;
    } finally {
      client.close();
    }
  });
}

// ── Providers ──

final alertNotifierProvider = Provider<AlertNotifier>(
  (ref) => LocalAlertNotifier(),
);

final watchSchedulerProvider = Provider<WatchScheduler>(
  (ref) => WorkmanagerScheduler(),
);

/// Always On alerts: null until the parent was asked.
class AlertsPrefNotifier extends StateNotifier<bool?> {
  final SharedPreferences _prefs;
  final WatchScheduler _scheduler;

  AlertsPrefNotifier(this._prefs, this._scheduler)
      : super(_prefs.getBool(kAlertsKey));

  bool get on => state == true;

  Future<void> set(bool on) async {
    state = on;
    await _prefs.setBool(kAlertsKey, on);
    if (on) {
      await _scheduler.schedule(replace: true);
    } else {
      await _scheduler.cancel();
      // A fresh start next time: no stale "already told you".
      for (final k in _prefs.getKeys().toList()) {
        if (k.startsWith('watch.state.')) await _prefs.remove(k);
      }
    }
  }

  /// On launch: make sure the job exists when alerts are on.
  Future<void> ensureScheduled() async {
    if (on) await _scheduler.schedule();
  }
}

final alertsPrefProvider = StateNotifierProvider<AlertsPrefNotifier, bool?>(
  (ref) => AlertsPrefNotifier(
    ref.watch(sharedPrefsProvider),
    ref.watch(watchSchedulerProvider),
  ),
);

/// Whether notifications are allowed for boretube (null: unknown).
final notificationsAllowedProvider = FutureProvider.autoDispose<bool?>(
  (ref) => ref.watch(alertNotifierProvider).enabled(),
);
