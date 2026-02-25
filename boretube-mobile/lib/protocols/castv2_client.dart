import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../proto/cast_channel.pb.dart';

/// CastV2 protocol client — communicates with Google Cast devices
/// over TLS on port 8009 using protobuf-framed JSON messages.
///
/// Uses a persistent buffered stream listener so no data is lost
/// between reads (Dart SecureSocket is single-subscription).
class CastV2Client {
  final String host;
  final int port;

  static const _nsConnection =
      'urn:x-cast:com.google.cast.tp.connection';
  static const _nsReceiver =
      'urn:x-cast:com.google.cast.receiver';

  static const _connectTimeout = Duration(seconds: 5);
  static const _recvTimeout = Duration(seconds: 3);

  SecureSocket? _socket;
  StreamSubscription<Uint8List>? _subscription;
  int _requestId = 0;

  // Persistent read buffer — all socket data flows here
  final _buffer = BytesBuilder(copy: false);
  Completer<void>? _dataArrived;
  bool _socketDone = false;

  CastV2Client({required this.host, this.port = 8009});

  /// Connect to the Cast device over TLS.
  Future<void> connect() async {
    await disconnect();
    _buffer.clear();
    _socketDone = false;

    try {
      _socket = await SecureSocket.connect(
        host,
        port,
        onBadCertificate: (_) => true,
        timeout: _connectTimeout,
      );
    } catch (e) {
      debugPrint('[CastV2] Connect failed: $e');
      _socket = null;
      rethrow;
    }

    // Single persistent listener — buffers all incoming data
    _subscription = _socket!.listen(
      (data) {
        _buffer.add(data);
        // Wake up anyone waiting for data
        if (_dataArrived != null && !_dataArrived!.isCompleted) {
          _dataArrived!.complete();
        }
      },
      onError: (Object e) {
        debugPrint('[CastV2] Socket error: $e');
        _socketDone = true;
        if (_dataArrived != null && !_dataArrived!.isCompleted) {
          _dataArrived!.complete();
        }
      },
      onDone: () {
        debugPrint('[CastV2] Socket closed by remote');
        _socketDone = true;
        if (_dataArrived != null && !_dataArrived!.isCompleted) {
          _dataArrived!.complete();
        }
      },
    );

    // Send CONNECT message on the connection namespace
    _sendMessage(
      _nsConnection,
      '{"type":"CONNECT"}',
    );
    debugPrint('[CastV2] Connected to $host:$port');
  }

  /// Get current TV status (volume, app, idle state).
  Future<Map<String, dynamic>?> getStatus() async {
    await _ensureConnected();
    final reqId = _nextRequestId();
    _sendCommand({'type': 'GET_STATUS'}, reqId);

    // Read messages until we get RECEIVER_STATUS
    for (var i = 0; i < 5; i++) {
      final resp = await _readMessage();
      if (resp == null) break;
      debugPrint('[CastV2] Got message: ${resp['type']}');
      if (resp['type'] == 'RECEIVER_STATUS') {
        return _parseStatus(resp);
      }
    }
    return null;
  }

  /// Stop the current app.
  Future<bool> stop() async {
    await _ensureConnected();
    _sendCommand({'type': 'STOP'}, _nextRequestId());
    return true;
  }

  /// Mute the TV.
  Future<bool> mute() async {
    await _ensureConnected();
    _sendCommand({
      'type': 'SET_VOLUME',
      'volume': {'muted': true},
    }, _nextRequestId());
    return true;
  }

  /// Unmute the TV.
  Future<bool> unmute() async {
    await _ensureConnected();
    _sendCommand({
      'type': 'SET_VOLUME',
      'volume': {'muted': false},
    }, _nextRequestId());
    return true;
  }

  /// Set volume to a percentage (0-100).
  Future<bool> setVolume(int percent) async {
    await _ensureConnected();
    final level = percent.clamp(0, 100) / 100.0;
    _sendCommand({
      'type': 'SET_VOLUME',
      'volume': {'level': level},
    }, _nextRequestId());
    return true;
  }

  /// Stop app + mute in one connection (matching bash bore).
  /// Preserves the 300ms pause between STOP and MUTE.
  Future<bool> bore() async {
    await _ensureConnected();
    _sendCommand({'type': 'STOP'}, _nextRequestId());
    await Future<void>.delayed(
      const Duration(milliseconds: 300),
    );
    _sendCommand({
      'type': 'SET_VOLUME',
      'volume': {'muted': true},
    }, _nextRequestId());
    return true;
  }

  /// Close the connection.
  Future<void> disconnect() async {
    _subscription?.cancel();
    _subscription = null;
    try {
      _socket?.destroy();
    } catch (_) {
      // Ignore close errors
    }
    _socket = null;
    _socketDone = true;
    // Wake up anyone waiting
    if (_dataArrived != null && !_dataArrived!.isCompleted) {
      _dataArrived!.complete();
    }
  }

  bool get isConnected => _socket != null && !_socketDone;

  // ── Private helpers ──

  Future<void> _ensureConnected() async {
    if (!isConnected) {
      await connect();
    }
  }

  int _nextRequestId() => ++_requestId;

  void _sendMessage(
    String namespace,
    String payload, {
    String sourceId = 'sender-0',
    String destinationId = 'receiver-0',
  }) {
    final msg = CastMessage(
      protocolVersion:
          CastMessage_ProtocolVersion.CASTV2_1_0,
      sourceId: sourceId,
      destinationId: destinationId,
      namespace: namespace,
      payloadType: CastMessage_PayloadType.STRING,
      payloadUtf8: payload,
    );
    final msgBytes = msg.writeToBuffer();
    final lengthPrefix = ByteData(4)
      ..setUint32(0, msgBytes.length);
    _socket!.add(lengthPrefix.buffer.asUint8List());
    _socket!.add(msgBytes);
  }

  void _sendCommand(
    Map<String, dynamic> payload,
    int requestId,
  ) {
    payload['requestId'] = requestId;
    _sendMessage(_nsReceiver, jsonEncode(payload));
  }

  /// Read exactly [length] bytes from the buffered stream.
  /// Returns null on timeout or socket close.
  Future<Uint8List?> _readExactly(int length) async {
    final deadline =
        DateTime.now().add(_recvTimeout);

    while (_buffer.length < length) {
      if (_socketDone) return null;
      final remaining =
          deadline.difference(DateTime.now());
      if (remaining.isNegative) return null;

      // Wait for more data or timeout
      _dataArrived = Completer<void>();
      await Future.any([
        _dataArrived!.future,
        Future.delayed(remaining),
      ]);
    }

    // Extract exactly [length] bytes from the buffer
    final allBytes = _buffer.toBytes();
    _buffer.clear();
    final result =
        Uint8List.fromList(allBytes.sublist(0, length));
    // Put remaining bytes back in the buffer
    if (allBytes.length > length) {
      _buffer.add(allBytes.sublist(length));
    }
    return result;
  }

  /// Read one CastV2 message: 4-byte length prefix + protobuf body.
  /// Returns decoded JSON payload or null.
  Future<Map<String, dynamic>?> _readMessage() async {
    try {
      // Read 4-byte big-endian length prefix
      final lengthBytes = await _readExactly(4);
      if (lengthBytes == null) return null;

      final msgLength =
          ByteData.sublistView(lengthBytes).getUint32(0);
      if (msgLength > 65536) return null;

      // Read the protobuf message body
      final msgBytes = await _readExactly(msgLength);
      if (msgBytes == null) return null;

      final castMsg = CastMessage.fromBuffer(msgBytes);
      if (castMsg.payloadUtf8.isNotEmpty) {
        try {
          return jsonDecode(castMsg.payloadUtf8)
              as Map<String, dynamic>;
        } catch (_) {
          return null;
        }
      }
      return null;
    } on SocketException {
      await disconnect();
      return null;
    } catch (e) {
      debugPrint('[CastV2] Read error: $e');
      return null;
    }
  }

  Map<String, dynamic> _parseStatus(
    Map<String, dynamic> resp,
  ) {
    final status =
        resp['status'] as Map<String, dynamic>? ?? {};
    final vol =
        status['volume'] as Map<String, dynamic>? ?? {};
    final apps =
        status['applications'] as List<dynamic>? ?? [];

    final result = <String, dynamic>{
      'volume':
          ((vol['level'] as num?)?.toDouble() ?? 0.0) * 100,
      'muted': vol['muted'] as bool? ?? false,
      'app_id': '',
      'app_name': '',
      'idle': true,
    };

    if (apps.isNotEmpty) {
      final app = apps[0] as Map<String, dynamic>;
      result['app_id'] = app['appId'] as String? ?? '';
      result['app_name'] =
          app['displayName'] as String? ?? '';
      result['idle'] =
          app['isIdleScreen'] as bool? ?? false;
    }

    return result;
  }
}
