import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'adb_key.dart';
import 'adb_message.dart';

/// Thrown when the TV has not (yet) accepted this device's key.
class AdbAuthPendingException implements Exception {
  final String message;
  const AdbAuthPendingException(this.message);
  @override
  String toString() => 'AdbAuthPendingException: $message';
}

class AdbShellResult {
  final String stdout;
  final int exitCode;
  const AdbShellResult(this.stdout, this.exitCode);
  bool get ok => exitCode == 0;
  @override
  String toString() => 'exit=$exitCode $stdout';
}

/// Pure-Dart ADB client over TCP (legacy port 5555 transport).
class AdbClient {
  final String host;
  final int port;
  final AdbKey key;
  final String keyName;

  Socket? _socket;
  final _buffer = BytesBuilder(copy: false);
  final _incoming = StreamController<AdbMessage>.broadcast();
  StreamSubscription<Uint8List>? _sub;
  int _nextLocalId = 1;
  String? deviceBanner;

  AdbClient({
    required this.host,
    this.port = 5555,
    required this.key,
    this.keyName = 'boretube',
  });

  bool get isConnected => _socket != null;

  /// Connects and authenticates. If the TV doesn't know our key yet, sends
  /// the public key (TV shows "Allow USB debugging?") and waits up to
  /// [promptTimeout] for the user to accept.
  Future<void> connect({
    Duration timeout = const Duration(seconds: 5),
    Duration promptTimeout = const Duration(seconds: 60),
  }) async {
    final socket = await Socket.connect(host, port, timeout: timeout);
    socket.setOption(SocketOption.tcpNoDelay, true);
    _socket = socket;
    _sub = socket.listen(_onData,
        onError: (Object e) => _incoming.addError(e),
        onDone: _onDone);

    _send(AdbMessage.text(
        AdbCommand.cnxn, adbVersion, adbMaxPayload, 'host::features=cmd'));

    var sentSignature = false;
    var sentPublicKey = false;
    while (true) {
      final msg = await _next(
          timeout: sentPublicKey ? promptTimeout : timeout);
      if (msg.command == AdbCommand.cnxn) {
        deviceBanner = utf8.decode(msg.payload, allowMalformed: true);
        return;
      }
      if (msg.command == AdbCommand.stls) {
        await close();
        throw const AdbAuthPendingException(
            'TV wants TLS (wireless debugging pairing); not supported yet');
      }
      if (msg.command != AdbCommand.auth ||
          msg.arg0 != AdbAuthType.token) {
        throw StateError('Unexpected during auth: $msg');
      }
      if (!sentSignature) {
        sentSignature = true;
        _send(AdbMessage(AdbCommand.auth, AdbAuthType.signature, 0,
            key.sign(msg.payload)));
      } else if (!sentPublicKey) {
        sentPublicKey = true;
        _send(AdbMessage.text(AdbCommand.auth, AdbAuthType.rsaPublicKey, 0,
            key.publicKeyString(keyName)));
      } else {
        await close();
        throw const AdbAuthPendingException('TV did not accept the key');
      }
    }
  }

  /// Runs a shell command and returns its output and exit code.
  Future<AdbShellResult> shell(String command,
      {Duration timeout = const Duration(seconds: 30)}) async {
    const marker = '__BTEXIT:';
    final raw = await _openAndRead(
        'shell:$command; echo "$marker\$?"', timeout: timeout);
    final i = raw.lastIndexOf(marker);
    if (i < 0) return AdbShellResult(raw, -1);
    final code = int.tryParse(raw.substring(i + marker.length).trim()) ?? -1;
    return AdbShellResult(raw.substring(0, i), code);
  }

  Future<String> _openAndRead(String service,
      {required Duration timeout}) async {
    final localId = _nextLocalId++;
    final out = BytesBuilder();
    final done = Completer<void>();
    late StreamSubscription<AdbMessage> s;
    int? remoteId;
    s = _incoming.stream.listen((m) {
      if (m.arg1 != localId) return;
      switch (m.command) {
        case AdbCommand.okay:
          remoteId ??= m.arg0;
        case AdbCommand.wrte:
          out.add(m.payload);
          _send(AdbMessage(AdbCommand.okay, localId, m.arg0));
        case AdbCommand.clse:
          if (remoteId != null || m.arg0 == 0) {
            _send(AdbMessage(AdbCommand.clse, localId, m.arg0));
          }
          if (!done.isCompleted) done.complete();
      }
    }, onError: (Object e) {
      if (!done.isCompleted) done.completeError(e);
    });
    _send(AdbMessage.text(AdbCommand.open, localId, 0, service));
    try {
      await done.future.timeout(timeout);
    } finally {
      await s.cancel();
    }
    return utf8.decode(out.takeBytes(), allowMalformed: true);
  }

  void _send(AdbMessage m) {
    final socket = _socket;
    if (socket == null) throw StateError('ADB not connected');
    socket.add(m.encode());
  }

  final _pending = <AdbMessage>[];
  Completer<void>? _waiter;

  Future<AdbMessage> _next({required Duration timeout}) async {
    final deadline = DateTime.now().add(timeout);
    while (_pending.isEmpty) {
      if (_socket == null) throw const SocketException('ADB closed');
      _waiter = Completer<void>();
      final left = deadline.difference(DateTime.now());
      if (left.isNegative) {
        throw TimeoutException('No ADB reply from $host:$port');
      }
      await _waiter!.future.timeout(left, onTimeout: () {});
    }
    return _pending.removeAt(0);
  }

  bool _authDone = false;

  void _onData(Uint8List chunk) {
    _buffer.add(chunk);
    var bytes = _buffer.takeBytes();
    var offset = 0;
    while (bytes.length - offset >= adbHeaderLength) {
      final (header, len) = AdbMessage.decodeHeader(Uint8List.sublistView(
          bytes, offset, offset + adbHeaderLength));
      if (bytes.length - offset - adbHeaderLength < len) break;
      final start = offset + adbHeaderLength;
      final msg = AdbMessage(header.command, header.arg0, header.arg1,
          Uint8List.fromList(bytes.sublist(start, start + len)));
      offset = start + len;
      if (msg.command == AdbCommand.cnxn) _authDone = true;
      if (_authDone && msg.command != AdbCommand.cnxn) {
        _incoming.add(msg);
      } else {
        _pending.add(msg);
        _waiter?.complete();
        _waiter = null;
      }
    }
    if (offset < bytes.length) {
      _buffer.add(Uint8List.sublistView(bytes, offset));
    }
  }

  void _onDone() {
    _socket = null;
    _waiter?.complete();
    _waiter = null;
    _incoming.addError(const SocketException('ADB connection closed'));
  }

  Future<void> close() async {
    await _sub?.cancel();
    _sub = null;
    final s = _socket;
    _socket = null;
    _authDone = false;
    _pending.clear();
    await s?.close();
    s?.destroy();
  }
}
