import 'dart:async';

import 'package:boretube_mobile/adb/adb_connection.dart';
import 'package:boretube_mobile/adb/adb_key.dart';
import 'package:boretube_mobile/adb/adb_session.dart';
import 'package:boretube_mobile/tv/tv.dart';
import 'package:flutter_test/flutter_test.dart';

/// Scripted fake transport.
class FakeConnection implements AdbConnection {
  final FakeWorld world;
  Completer<void> _closed = Completer<void>()..complete();
  bool _connected = false;

  FakeConnection(this.world);

  @override
  bool get isConnected => _connected;

  @override
  Future<void> get closed => _closed.future;

  @override
  Future<void> connect({
    Duration timeout = const Duration(seconds: 5),
    Duration promptTimeout = const Duration(seconds: 60),
    void Function()? onAwaitingApproval,
  }) async {
    world.connects++;
    final mode =
        world.connectModes.isEmpty ? 'ok' : world.connectModes.removeAt(0);
    switch (mode) {
      case 'refused':
        throw StateError('connection refused');
      case 'prompt':
        onAwaitingApproval?.call();
        await world.approval!.future;
      case 'prompt-timeout':
        onAwaitingApproval?.call();
        throw TimeoutException('no reply');
    }
    _connected = true;
    _closed = Completer<void>();
  }

  @override
  Future<AdbShellResult> shell(
    String command, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    world.log.add('start $command');
    if (world.failNextShell > 0) {
      world.failNextShell--;
      throw StateError('socket gone');
    }
    await Future<void>.delayed(const Duration(milliseconds: 5));
    world.log.add('end $command');
    return AdbShellResult('out:$command', 0);
  }

  /// Simulates the TV dropping the socket.
  void drop() {
    _connected = false;
    if (!_closed.isCompleted) _closed.complete();
  }

  @override
  Future<void> close() async => drop();
}

class FakeWorld {
  final connectModes = <String>[];
  final conns = <FakeConnection>[];
  final log = <String>[];
  Completer<void>? approval;
  int connects = 0;
  int failNextShell = 0;

  AdbConnection create(String h, int p, AdbKey k, String n) {
    final c = FakeConnection(this);
    conns.add(c);
    return c;
  }
}

const _tv = Tv(id: 'ip:10.0.0.2', name: 'TV', ip: '10.0.0.2');
final _key = AdbKey(BigInt.from(3233), BigInt.from(17), BigInt.from(413));

AdbSession _session(FakeWorld w) => AdbSession(
      tv: _tv,
      key: _key,
      factory: w.create,
      keepAlive: null,
      backoff: const [Duration(milliseconds: 10)],
    );

void main() {
  test('connect goes connecting -> connected', () async {
    final w = FakeWorld();
    final s = _session(w);
    final states = <String>[];
    s.states.listen((e) => states.add('$e'));
    await s.connect();
    await Future<void>.delayed(Duration.zero);
    expect(states, ['connecting', 'connected']);
    expect(s.isConnected, isTrue);
    await s.dispose();
  });

  test('exposes awaitingApproval while the TV prompt is pending', () async {
    final w = FakeWorld()
      ..connectModes.add('prompt')
      ..approval = Completer<void>();
    final s = _session(w);
    final f = s.connect();
    await Future<void>.delayed(Duration.zero);
    expect(s.state, isA<AdbAwaitingApproval>());
    w.approval!.complete();
    await f;
    expect(s.state, isA<AdbConnected>());
    await s.dispose();
  });

  test('prompt timeout -> failed(authRejected), no reconnect loop', () async {
    final w = FakeWorld()..connectModes.add('prompt-timeout');
    final s = _session(w);
    await expectLater(s.connect(), throwsA(isA<TimeoutException>()));
    final st = s.state;
    expect(st, isA<AdbFailed>());
    expect((st as AdbFailed).authRejected, isTrue);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(w.connects, 1);
    await s.dispose();
  });

  test('concurrent connect calls share one attempt', () async {
    final w = FakeWorld();
    final s = _session(w);
    await Future.wait([s.connect(), s.connect(), s.connect()]);
    expect(w.connects, 1);
    await s.dispose();
  });

  test('auto-reconnects with backoff after a drop', () async {
    final w = FakeWorld();
    final s = _session(w);
    await s.connect();
    w.connectModes.addAll(['refused', 'ok']);
    final seen = <String>[];
    s.states.listen((e) => seen.add('$e'));
    w.conns.last.drop();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(seen.first, 'disconnected');
    expect(seen, contains('failed(Bad state: connection refused)'));
    expect(seen.last, 'connected');
    expect(w.connects, 3);
    await s.dispose();
  });

  test('close stops reconnecting', () async {
    final w = FakeWorld();
    final s = _session(w);
    await s.connect();
    await s.close();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(w.connects, 1);
    expect(s.state, isA<AdbDisconnected>());
    await s.dispose();
  });

  test('shell connects lazily and serializes commands', () async {
    final w = FakeWorld();
    final s = _session(w);
    final results = await Future.wait([
      s.shell('a'),
      s.shell('b'),
      s.shell('c'),
    ]);
    expect(results.map((r) => r.stdout), ['out:a', 'out:b', 'out:c']);
    expect(w.log, [
      'start a',
      'end a',
      'start b',
      'end b',
      'start c',
      'end c',
    ]);
    expect(w.connects, 1);
    await s.dispose();
  });

  test('shell reconnects once on transport failure', () async {
    final w = FakeWorld()..failNextShell = 1;
    final s = _session(w);
    final r = await s.shell('getprop');
    expect(r.stdout, 'out:getprop');
    expect(w.connects, 2);
    await s.dispose();
  });

  test('shell gives up after the retry also fails', () async {
    final w = FakeWorld()..failNextShell = 2;
    final s = _session(w);
    await expectLater(s.shell('x'), throwsStateError);
    // The queue keeps working after a failure.
    final r = await s.shell('y');
    expect(r.ok, isTrue);
    await s.dispose();
  });

  test('shell throws AdbUnavailableException when it cannot connect', () async {
    final w = FakeWorld()..connectModes.add('refused');
    final s = _session(w);
    await expectLater(
      s.shell('x'),
      throwsA(isA<AdbUnavailableException>()),
    );
    await s.dispose();
  });
}
