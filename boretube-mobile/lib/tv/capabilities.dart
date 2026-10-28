import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../adb/adb_key.dart';
import '../adb/adb_message.dart';
import '../discovery/net.dart';
import '../protocols/castv2_client.dart';
import 'tv.dart';

/// Result of one capability probe.
class ProbeOutcome {
  /// True when the capability is usable.
  final bool ok;

  /// Human-readable detail, e.g. `authorized`, `needs approval`, `closed`.
  final String detail;

  const ProbeOutcome(this.ok, this.detail);

  @override
  String toString() => '${ok ? 'ok' : 'no'}: $detail';
}

/// Probes one capability of [tv] within [timeout].
typedef CapabilityProbe = Future<ProbeOutcome> Function(
  Tv tv,
  Duration timeout,
);

/// Probes one capability of [tv] using an optional ADB key.
typedef AdbProbe = Future<ProbeOutcome> Function(
  Tv tv,
  AdbKey? key,
  Duration timeout,
);

/// All probe results for a TV.
class CapabilityReport {
  /// The TV with [Tv.capabilities] and [Tv.capabilitiesCheckedAt] set.
  final Tv tv;

  /// Outcome per capability, including the ones that failed.
  final Map<TvCapability, ProbeOutcome> details;

  const CapabilityReport(this.tv, this.details);

  Set<TvCapability> get capabilities => tv.capabilities;

  String? detail(TvCapability c) => details[c]?.detail;
}

/// Probes cast / dial / sonyRest / adb / agent in parallel.
class CapabilityProber {
  final DiscoveryNet net;
  final Duration timeout;
  final DateTime Function() clock;

  late final CapabilityProbe castProbe;
  late final CapabilityProbe dialProbe;
  late final CapabilityProbe sonyRestProbe;
  late final AdbProbe adbProbe;
  late final CapabilityProbe agentProbe;

  CapabilityProber({
    this.net = const DiscoveryNet(),
    this.timeout = const Duration(seconds: 3),
    DateTime Function()? clock,
    CapabilityProbe? castProbe,
    CapabilityProbe? dialProbe,
    CapabilityProbe? sonyRestProbe,
    AdbProbe? adbProbe,
    CapabilityProbe? agentProbe,
  }) : clock = clock ?? DateTime.now {
    this.castProbe = castProbe ?? probeCast;
    this.dialProbe = dialProbe ?? _probeDial;
    this.sonyRestProbe = sonyRestProbe ?? _probeSonyRest;
    this.adbProbe = adbProbe ?? probeAdb;
    this.agentProbe = agentProbe ?? _probeAgent;
  }

  /// Runs every probe in parallel (each bounded by [timeout]).
  Future<CapabilityReport> probe(Tv tv, {AdbKey? key}) async {
    Future<ProbeOutcome> guard(Future<ProbeOutcome> Function() f) async {
      try {
        // `then` re-types the future: `.timeout` on a Future<Never> can't
        // be caught here.
        return await f().then<ProbeOutcome>((v) => v).timeout(
              timeout + const Duration(milliseconds: 200),
              onTimeout: () => const ProbeOutcome(false, 'timeout'),
            );
      } catch (e) {
        return ProbeOutcome(false, 'error: $e');
      }
    }

    final probes = <TvCapability, Future<ProbeOutcome>>{
      TvCapability.cast: guard(() => castProbe(tv, timeout)),
      TvCapability.dial: guard(() => dialProbe(tv, timeout)),
      TvCapability.sonyRest: guard(() => sonyRestProbe(tv, timeout)),
      TvCapability.adb: guard(() => adbProbe(tv, key, timeout)),
      TvCapability.agent: guard(() => agentProbe(tv, timeout)),
    };
    final details = <TvCapability, ProbeOutcome>{};
    for (final e in probes.entries) {
      details[e.key] = await e.value;
    }
    final caps = {
      for (final e in details.entries)
        if (e.value.ok) e.key,
    };
    return CapabilityReport(
      tv.copyWith(capabilities: caps, capabilitiesCheckedAt: clock()),
      details,
    );
  }

  /// CastV2 GET_STATUS answers.
  static Future<ProbeOutcome> probeCast(Tv tv, Duration timeout) async {
    final client = CastV2Client(host: tv.ip, port: tv.castPort);
    try {
      final status = await client.getStatus().timeout(timeout);
      if (status == null) return const ProbeOutcome(false, 'no status');
      final app = status['app_name'] as String? ?? '';
      return ProbeOutcome(true, app.isEmpty ? 'status ok' : 'app: $app');
    } on TimeoutException {
      // A slow connect may still complete; close it when it does.
      unawaited(
        Future<void>.delayed(const Duration(seconds: 6), client.disconnect),
      );
      return const ProbeOutcome(false, 'timeout');
    } catch (e) {
      return ProbeOutcome(false, 'unreachable: ${_short(e)}');
    } finally {
      await client.disconnect();
    }
  }

  Future<ProbeOutcome> _probeDial(Tv tv, Duration timeout) async {
    final r = await net.httpGet(
      Uri.parse('http://${tv.ip}:${tv.dialPort}/ssdp/device-desc.xml'),
      timeout: timeout,
    );
    if (r == null) return const ProbeOutcome(false, 'unreachable');
    if (r.statusCode != 200) {
      return ProbeOutcome(false, 'HTTP ${r.statusCode}');
    }
    return const ProbeOutcome(true, 'device-desc 200');
  }

  /// Read-only `getVolumeInformation`.
  Future<ProbeOutcome> _probeSonyRest(Tv tv, Duration timeout) async {
    final r = await net.httpPost(
      Uri.parse('http://${tv.ip}/sony/audio'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'method': 'getVolumeInformation',
        'id': 33,
        'params': <Object>[],
        'version': '1.0',
      }),
      timeout: timeout,
    );
    if (r == null) return const ProbeOutcome(false, 'no response');
    if (r.statusCode != 200) {
      return ProbeOutcome(false, 'HTTP ${r.statusCode}');
    }
    try {
      final j = jsonDecode(r.body);
      if (j is Map && j['result'] is List) {
        return const ProbeOutcome(true, 'volume info ok');
      }
      if (j is Map && j['error'] != null) {
        return ProbeOutcome(false, 'error ${j['error']}');
      }
    } catch (_) {
      // Fall through.
    }
    return const ProbeOutcome(false, 'unexpected reply');
  }

  Future<ProbeOutcome> _probeAgent(Tv tv, Duration timeout) async {
    final r = await net.httpGet(
      Uri.parse('http://${tv.ip}:${tv.agentPort}/v1/status'),
      timeout: timeout,
    );
    if (r == null) return const ProbeOutcome(false, 'not running');
    if (r.statusCode == 401 || r.statusCode == 403) {
      return ProbeOutcome(false, 'needs token (HTTP ${r.statusCode})');
    }
    if (r.statusCode != 200) {
      return ProbeOutcome(false, 'HTTP ${r.statusCode}');
    }
    try {
      if (jsonDecode(r.body) is Map) {
        return const ProbeOutcome(true, 'status ok');
      }
    } catch (_) {
      // Fall through.
    }
    return const ProbeOutcome(false, 'not JSON');
  }

  /// ADB over TCP: connects, sends CNXN and answers an AUTH token with a
  /// signature from [key]. Never sends the public key, so the TV shows no
  /// "Allow debugging?" prompt; an unknown key reports `needs approval`.
  static Future<ProbeOutcome> probeAdb(
    Tv tv,
    AdbKey? key,
    Duration timeout,
  ) async {
    Socket socket;
    try {
      socket = await Socket.connect(tv.ip, tv.adbPort, timeout: timeout);
    } catch (_) {
      return const ProbeOutcome(false, 'closed');
    }
    if (key == null) {
      socket.destroy();
      return const ProbeOutcome(false, 'open (no key)');
    }
    final reader = _AdbReader(socket);
    try {
      socket.add(AdbMessage.text(
        AdbCommand.cnxn,
        adbVersion,
        adbMaxPayload,
        'host::features=cmd',
      ).encode());
      final deadline = DateTime.now().add(timeout);
      var signed = false;
      while (true) {
        final m = await reader.next(deadline);
        if (m == null) {
          return ProbeOutcome(false, signed ? 'needs approval' : 'no reply');
        }
        if (m.command == AdbCommand.cnxn) {
          return const ProbeOutcome(true, 'authorized');
        }
        if (m.command == AdbCommand.stls) {
          return const ProbeOutcome(false, 'needs approval (TLS)');
        }
        if (m.command != AdbCommand.auth || m.arg0 != AdbAuthType.token) {
          return ProbeOutcome(false, 'unexpected $m');
        }
        if (signed) return const ProbeOutcome(false, 'needs approval');
        signed = true;
        socket.add(AdbMessage(
          AdbCommand.auth,
          AdbAuthType.signature,
          0,
          key.sign(m.payload),
        ).encode());
      }
    } catch (e) {
      return ProbeOutcome(false, 'error: ${_short(e)}');
    } finally {
      await reader.close();
    }
  }

  static String _short(Object e) {
    final s = e.toString();
    return s.length > 80 ? s.substring(0, 80) : s;
  }
}

/// Minimal buffered ADB packet reader for the auth handshake.
class _AdbReader {
  final Socket _socket;
  final _buf = BytesBuilder(copy: false);
  final _messages = <AdbMessage>[];
  Completer<void>? _waiter;
  bool _done = false;
  late final StreamSubscription<Uint8List> _sub;

  _AdbReader(this._socket) {
    _sub = _socket.listen(
      _onData,
      onError: (Object _) => _finish(),
      onDone: _finish,
    );
  }

  void _finish() {
    _done = true;
    _wake();
  }

  void _wake() {
    final w = _waiter;
    _waiter = null;
    if (w != null && !w.isCompleted) w.complete();
  }

  void _onData(Uint8List chunk) {
    _buf.add(chunk);
    final bytes = _buf.takeBytes();
    var off = 0;
    try {
      while (bytes.length - off >= adbHeaderLength) {
        final (h, len) = AdbMessage.decodeHeader(
          Uint8List.sublistView(bytes, off, off + adbHeaderLength),
        );
        final start = off + adbHeaderLength;
        if (bytes.length - start < len) break;
        _messages.add(AdbMessage(
          h.command,
          h.arg0,
          h.arg1,
          Uint8List.fromList(bytes.sublist(start, start + len)),
        ));
        off = start + len;
      }
    } on FormatException {
      _finish();
      return;
    }
    if (off < bytes.length) _buf.add(Uint8List.sublistView(bytes, off));
    _wake();
  }

  /// Next packet, or null on close or when [deadline] passes.
  Future<AdbMessage?> next(DateTime deadline) async {
    while (_messages.isEmpty) {
      if (_done) return null;
      final left = deadline.difference(DateTime.now());
      if (left.isNegative) return null;
      _waiter = Completer<void>();
      await _waiter!.future.timeout(left, onTimeout: () {});
    }
    return _messages.removeAt(0);
  }

  Future<void> close() async {
    await _sub.cancel();
    _socket.destroy();
  }
}
