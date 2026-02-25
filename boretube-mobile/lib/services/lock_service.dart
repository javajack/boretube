import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../models/log_entry.dart';
import '../models/tv_status.dart';
import '../models/whitelist_entry.dart';
import 'tv_service.dart';

// ── Foreground Task Callback ──

@pragma('vm:entry-point')
void lockTaskCallback() {
  FlutterForegroundTask.setTaskHandler(
    BoretubeTaskHandler(),
  );
}

// ── Task Handler (runs in separate isolate) ──

class BoretubeTaskHandler extends TaskHandler {
  TvService? _tvService;
  bool _lockApps = false;
  bool _lockVolume = false;
  int _maxVolume = 15;
  List<WhitelistEntry> _whitelist = [];
  DateTime? _endTime;
  bool _polling = false;
  bool _expired = false;
  bool _destroyed = false;

  @override
  Future<void> onStart(
    DateTime timestamp,
    TaskStarter starter,
  ) async {
    final configStr =
        await FlutterForegroundTask.getData<String>(
      key: 'lock_config',
    );
    if (configStr == null) {
      _sendLog('No config found, stopping');
      await FlutterForegroundTask.stopService();
      return;
    }

    try {
      final config =
          jsonDecode(configStr) as Map<String, dynamic>;
      _tvService = TvService(
        host: config['host'] as String,
        castPort: config['castPort'] as int? ?? 8009,
        dialPort: config['dialPort'] as int? ?? 8008,
      );
      _lockApps =
          config['lockApps'] as bool? ?? false;
      _lockVolume =
          config['lockVolume'] as bool? ?? false;
      _maxVolume =
          config['maxVolume'] as int? ?? 15;

      final duration =
          config['durationMinutes'] as int? ?? 60;
      _endTime = DateTime.now().add(
        Duration(minutes: duration),
      );

      final whitelistRaw =
          config['whitelist'] as List<dynamic>? ?? [];
      _whitelist = whitelistRaw
          .map(
            (s) => WhitelistEntry.fromStorageString(
              s as String,
            ),
          )
          .toList();

      _sendLog('Lock started ($duration min)');
    } catch (e) {
      _sendLog('Config error: $e');
      await FlutterForegroundTask.stopService();
    }
  }

  @override
  Future<void> onRepeatEvent(
    DateTime timestamp,
  ) async {
    if (_tvService == null ||
        _polling ||
        _destroyed) {
      return;
    }
    _polling = true;
    try {
      await _doPoll();
    } catch (e) {
      _sendLog('Poll error: $e');
    } finally {
      _polling = false;
    }
  }

  Future<void> _doPoll() async {
    final remaining = _remainingSeconds();
    if (remaining <= 0) {
      _expired = true;
      _sendLog('Lock ended (timer expired)');
      await FlutterForegroundTask.stopService();
      return;
    }

    // Update notification + send remaining to UI
    final remText = _formatRemaining(remaining);
    try {
      await FlutterForegroundTask.updateService(
        notificationTitle: 'Boretube Lock',
        notificationText: '$remText left',
      );
    } catch (_) {
      // Notification update can fail if service
      // is being torn down — safe to ignore.
    }
    FlutterForegroundTask.sendDataToMain({
      'type': 'remaining',
      'seconds': remaining,
    });

    // Get TV status (never throws, returns null
    // when TV is off or unreachable)
    final status = await _tvService!.getStatus();
    if (status == null) {
      _sendLog('TV off/standby');
      return;
    }

    // Check whitelist enforcement
    final appId = status.appId;
    if (_lockApps && !status.isIdle) {
      final allowed = _whitelist.any(
        (e) => e.appId == appId,
      );
      if (!allowed) {
        _sendLog(
          'STOPPED: ${status.appName}'
          ' (${status.appId})',
        );
        try {
          await _tvService!.bore();
        } catch (e) {
          _sendLog('Bore failed: $e');
        }
        return;
      }
    }

    // Check volume cap
    if (_lockVolume &&
        !status.muted &&
        status.volume > _maxVolume) {
      final label = _appLabel(status);
      final ok =
          await _tvService!.setVolume(_maxVolume);
      if (ok) {
        _sendLog(
          '$label vol=${status.volume}%'
          ' \u2192 capped to $_maxVolume%',
        );
      } else {
        _sendLog(
          '$label vol=${status.volume}%'
          ' \u2192 cap failed (TV unreachable?)',
        );
      }
      return;
    }

    // All OK — report status
    _sendStatusLog(status);
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    _destroyed = true;
    if (_lockApps && _tvService != null) {
      try {
        await _tvService!.restore();
      } catch (_) {}
    }
    if (!_expired) {
      _sendLog('Lock stopped');
    }
    FlutterForegroundTask.sendDataToMain(
      {'type': 'stopped'},
    );
  }

  @override
  void onReceiveData(Object data) {}

  @override
  void onNotificationButtonPressed(String id) {
    if (id == 'stop') {
      FlutterForegroundTask.stopService();
    }
  }

  @override
  void onNotificationPressed() {
    FlutterForegroundTask.launchApp();
  }

  @override
  void onNotificationDismissed() {}

  void _sendStatusLog(TvStatus status) {
    final label = _appLabel(status);
    final vol =
        '${status.volume}%'
        '${status.muted ? ' MUTED' : ''}';

    if (status.isIdle) {
      _sendLog('Home screen (idle) $vol');
    } else {
      final wl = _whitelist.any(
        (e) => e.appId == status.appId,
      );
      final tag = wl ? ' (whitelisted)' : '';
      _sendLog('$label$tag $vol');
    }
  }

  int _remainingSeconds() {
    if (_endTime == null) return 0;
    final diff =
        _endTime!.difference(DateTime.now()).inSeconds;
    return diff > 0 ? diff : 0;
  }

  String _formatRemaining(int seconds) {
    if (seconds < 60) return '${seconds}s';
    return '${seconds ~/ 60}m';
  }

  String _appLabel(TvStatus status) =>
      status.appName.isEmpty ? 'idle' : status.appName;

  void _sendLog(String message) {
    debugPrint('[Boretube] $message');
    try {
      FlutterForegroundTask.sendDataToMain({
        'type': 'log',
        'timestamp':
            DateTime.now().millisecondsSinceEpoch,
        'message': message,
        'isStopped': message.startsWith('STOPPED'),
      });
    } catch (_) {
      // Communication port may not be ready yet
    }
  }
}

// ── UI-Side Controller ──

class LockService {
  final _logController =
      StreamController<LogEntry>.broadcast();
  final _remainingController =
      StreamController<int>.broadcast();
  final _activeController =
      StreamController<bool>.broadcast();
  final List<LogEntry> _log = [];
  bool _isActive = false;
  int _lastRemaining = 0;
  bool _disposed = false;

  Stream<LogEntry> get logStream =>
      _logController.stream;

  Stream<int> get remainingStream =>
      _remainingController.stream;

  Stream<bool> get activeStream =>
      _activeController.stream;

  List<LogEntry> get log => List.unmodifiable(_log);
  bool get isActive => _isActive;
  int get lastRemaining => _lastRemaining;

  void Function(Object)? _taskDataCallback;

  void init() {
    _taskDataCallback = _onTaskData;
    FlutterForegroundTask.addTaskDataCallback(
      _taskDataCallback!,
    );
    // Reconnect if service was already running
    FlutterForegroundTask.isRunningService.then(
      (running) {
        if (running && !_isActive && !_disposed) {
          _isActive = true;
          _safeAdd(_activeController, true);
        }
      },
    );
  }

  Future<void> start({
    required String host,
    required int castPort,
    required int dialPort,
    required bool lockApps,
    required bool lockVolume,
    required int maxVolume,
    required int intervalSeconds,
    required int durationMinutes,
    required List<WhitelistEntry> whitelist,
  }) async {
    // Request permissions
    await FlutterForegroundTask
        .requestNotificationPermission();
    await FlutterForegroundTask
        .requestIgnoreBatteryOptimization();

    // Save config for task handler isolate
    final config = jsonEncode({
      'host': host,
      'castPort': castPort,
      'dialPort': dialPort,
      'lockApps': lockApps,
      'lockVolume': lockVolume,
      'maxVolume': maxVolume,
      'durationMinutes': durationMinutes,
      'whitelist': whitelist
          .map((e) => e.toStorageString())
          .toList(),
    });
    await FlutterForegroundTask.saveData(
      key: 'lock_config',
      value: config,
    );

    // Configure foreground task
    FlutterForegroundTask.init(
      androidNotificationOptions:
          AndroidNotificationOptions(
        channelId: 'boretube_lock',
        channelName: 'Boretube Lock Service',
        channelDescription:
            'Keeps lock active when phone '
            'is locked',
        channelImportance:
            NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions:
          const IOSNotificationOptions(),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction:
            ForegroundTaskEventAction.repeat(
          intervalSeconds * 1000,
        ),
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: false,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );

    _log.clear();
    _lastRemaining = durationMinutes * 60;

    await FlutterForegroundTask.startService(
      serviceId: 256,
      notificationTitle: 'Boretube Lock',
      notificationText: '${durationMinutes}m left',
      notificationButtons: [
        const NotificationButton(
          id: 'stop',
          text: 'Stop Lock',
        ),
      ],
      callback: lockTaskCallback,
    );

    _isActive = true;
    _safeAdd(_activeController, true);
  }

  Future<void> stop() async {
    _isActive = false;
    _lastRemaining = 0;
    _safeAdd(_activeController, false);
    _safeAdd(_remainingController, 0);
    await FlutterForegroundTask.stopService();
  }

  void _onTaskData(Object data) {
    if (_disposed || data is! Map) return;
    final type = data['type'] as String?;

    switch (type) {
      case 'log':
        final ts = data['timestamp'];
        final msg = data['message'];
        if (ts is! int || msg is! String) return;
        final entry = LogEntry(
          timestamp:
              DateTime.fromMillisecondsSinceEpoch(ts),
          message: msg,
          isStopped:
              data['isStopped'] as bool? ?? false,
        );
        _log.add(entry);
        _safeAdd(_logController, entry);
      case 'remaining':
        final sec = data['seconds'];
        if (sec is! int) return;
        _lastRemaining = sec;
        _safeAdd(_remainingController, sec);
      case 'stopped':
        _isActive = false;
        _lastRemaining = 0;
        _safeAdd(_activeController, false);
        _safeAdd(_remainingController, 0);
    }
  }

  /// Add to stream only if not disposed.
  void _safeAdd<T>(
    StreamController<T> ctrl,
    T value,
  ) {
    if (!ctrl.isClosed) ctrl.add(value);
  }

  void dispose() {
    _disposed = true;
    if (_taskDataCallback != null) {
      FlutterForegroundTask.removeTaskDataCallback(
        _taskDataCallback!,
      );
    }
    _logController.close();
    _remainingController.close();
    _activeController.close();
  }
}
