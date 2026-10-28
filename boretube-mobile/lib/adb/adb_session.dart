import 'dart:async';

import '../tv/tv.dart';
import 'adb_connection.dart';
import 'adb_identity.dart';
import 'adb_key.dart';

/// Connection state of an [AdbSession].
sealed class AdbSessionState {
  const AdbSessionState();
}

class AdbDisconnected extends AdbSessionState {
  const AdbDisconnected();
  @override
  String toString() => 'disconnected';
}

class AdbConnecting extends AdbSessionState {
  const AdbConnecting();
  @override
  String toString() => 'connecting';
}

/// The TV shows "Allow USB debugging?". UI: "Look at the TV → Always allow".
class AdbAwaitingApproval extends AdbSessionState {
  const AdbAwaitingApproval();
  @override
  String toString() => 'awaitingApproval';
}

class AdbConnected extends AdbSessionState {
  const AdbConnected();
  @override
  String toString() => 'connected';
}

class AdbFailed extends AdbSessionState {
  final String reason;

  /// True when the TV did not accept our key (prompt denied or timed out).
  final bool authRejected;

  const AdbFailed(this.reason, {this.authRejected = false});
  @override
  String toString() => 'failed($reason)';
}

/// Thrown by [AdbSession.shell] when no connection could be made.
class AdbUnavailableException implements Exception {
  final String message;
  const AdbUnavailableException(this.message);
  @override
  String toString() => 'AdbUnavailableException: $message';
}

/// A managed ADB connection to one [Tv]: connect + auth-pending state,
/// auto-reconnect with backoff, keep-alive, and one-at-a-time commands.
/// Urgent commands (user actions) run before queued background ones.
class AdbSession implements PriorityAdbShell {
  final Tv tv;
  final AdbKey key;
  final String keyName;
  final AdbConnectionFactory _factory;
  final Duration connectTimeout;
  final Duration promptTimeout;
  final Duration commandTimeout;

  /// Delays between reconnect attempts after a drop; the last one repeats.
  final List<Duration> backoff;

  /// Runs a no-op command this often while idle; null disables it.
  final Duration? keepAlive;

  final _states = StreamController<AdbSessionState>.broadcast();
  AdbSessionState _state = const AdbDisconnected();
  AdbConnection? _conn;
  Future<void>? _connecting;
  final _urgent = <_Job>[];
  final _background = <_Job>[];
  bool _running = false;
  Timer? _reconnectTimer;
  Timer? _keepAliveTimer;
  int _attempt = 0;
  bool _closedByUser = false;

  AdbSession({
    required this.tv,
    required this.key,
    this.keyName = AdbIdentity.keyName,
    AdbConnectionFactory? factory,
    this.connectTimeout = const Duration(seconds: 5),
    this.promptTimeout = const Duration(seconds: 90),
    this.commandTimeout = const Duration(seconds: 30),
    this.backoff = const [
      Duration(seconds: 1),
      Duration(seconds: 2),
      Duration(seconds: 5),
      Duration(seconds: 10),
      Duration(seconds: 30),
    ],
    this.keepAlive = const Duration(seconds: 30),
  }) : _factory = factory ?? defaultAdbConnectionFactory;

  AdbSessionState get state => _state;

  /// State changes (not replayed; read [state] for the current one).
  Stream<AdbSessionState> get states => _states.stream;

  bool get isConnected => _state is AdbConnected;

  void _set(AdbSessionState s) {
    if (s.runtimeType == _state.runtimeType && s is! AdbFailed) return;
    _state = s;
    if (!_states.isClosed) _states.add(s);
  }

  /// Connects if not already connected. Concurrent calls share one attempt.
  /// Throws on failure; [state] is then [AdbFailed].
  Future<void> connect() {
    _closedByUser = false;
    if (_state is AdbConnected && (_conn?.isConnected ?? false)) {
      return Future<void>.value();
    }
    return _connecting ??= _doConnect().whenComplete(() {
      _connecting = null;
    });
  }

  Future<void> _doConnect() async {
    _reconnectTimer?.cancel();
    final old = _conn;
    _conn = null;
    await old?.close();
    _set(const AdbConnecting());
    final conn = _factory(tv.ip, tv.adbPort, key, keyName);
    var prompted = false;
    try {
      await conn.connect(
        timeout: connectTimeout,
        promptTimeout: promptTimeout,
        onAwaitingApproval: () {
          prompted = true;
          _set(const AdbAwaitingApproval());
        },
      );
    } catch (e) {
      await conn.close();
      final rejected = prompted || e is AdbAuthPendingException;
      _set(AdbFailed(
        rejected ? 'TV did not allow this phone: $e' : '$e',
        authRejected: rejected,
      ));
      rethrow;
    }
    if (_closedByUser) {
      await conn.close();
      return;
    }
    _conn = conn;
    _attempt = 0;
    _set(const AdbConnected());
    _startKeepAlive();
    unawaited(conn.closed.then((_) => _onDrop(conn)));
  }

  void _onDrop(AdbConnection conn) {
    if (!identical(conn, _conn)) return;
    _conn = null;
    _keepAliveTimer?.cancel();
    if (_closedByUser) return;
    _set(const AdbDisconnected());
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_closedByUser || _reconnectTimer?.isActive == true) return;
    final i = _attempt < backoff.length ? _attempt : backoff.length - 1;
    _attempt++;
    _reconnectTimer = Timer(backoff[i], () {
      if (_closedByUser) return;
      connect().catchError((Object _) {
        final s = _state;
        // A denied prompt needs the parent; don't nag the TV in a loop.
        if (s is AdbFailed && !s.authRejected) _scheduleReconnect();
      });
    });
  }

  void _startKeepAlive() {
    _keepAliveTimer?.cancel();
    final every = keepAlive;
    if (every == null) return;
    _keepAliveTimer = Timer.periodic(every, (_) {
      if (_state is AdbConnected) {
        shell('true').then((_) {}, onError: (Object _) {});
      }
    });
  }

  /// Runs [command] after any queued commands. Connects if needed and, if
  /// the command fails at the transport level, reconnects once and retries.
  @override
  Future<AdbShellResult> shell(String command) =>
      _enqueue(command, _background);

  /// Like [shell], but jumps ahead of every queued background command. A
  /// command already on the wire still finishes first.
  @override
  Future<AdbShellResult> shellUrgent(String command) =>
      _enqueue(command, _urgent);

  Future<AdbShellResult> _enqueue(String command, List<_Job> lane) {
    final job = _Job(command);
    lane.add(job);
    _pump();
    return job.done.future;
  }

  void _pump() {
    if (_running) return;
    final lane = _urgent.isNotEmpty ? _urgent : _background;
    if (lane.isEmpty) return;
    final job = lane.removeAt(0);
    _running = true;
    _run(job.command)
        .then(job.done.complete, onError: job.done.completeError)
        .whenComplete(() {
      _running = false;
      _pump();
    });
  }

  Future<AdbShellResult> _run(String command) async {
    for (var attempt = 0;; attempt++) {
      try {
        await connect();
      } catch (e) {
        throw AdbUnavailableException('$e');
      }
      final conn = _conn;
      if (conn == null) throw const AdbUnavailableException('closed');
      try {
        return await conn.shell(command, timeout: commandTimeout);
      } catch (e) {
        if (attempt >= 1 || _closedByUser) rethrow;
        _conn = null;
        _keepAliveTimer?.cancel();
        await conn.close();
        _set(const AdbDisconnected());
      }
    }
  }

  /// Closes the connection and stops reconnecting.
  Future<void> close() async {
    _closedByUser = true;
    _reconnectTimer?.cancel();
    _keepAliveTimer?.cancel();
    final conn = _conn;
    _conn = null;
    await conn?.close();
    _set(const AdbDisconnected());
  }

  /// Closes the session and its state stream for good.
  Future<void> dispose() async {
    await close();
    await _states.close();
  }
}

class _Job {
  final String command;
  final done = Completer<AdbShellResult>();
  _Job(this.command);
}
