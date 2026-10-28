import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:boretube_mobile/adb/adb_key.dart';
import 'package:boretube_mobile/adb/adb_message.dart';
import 'package:boretube_mobile/discovery/net.dart';
import 'package:boretube_mobile/tv/capabilities.dart';
import 'package:boretube_mobile/tv/tv.dart';
import 'package:flutter_test/flutter_test.dart';

import '../discovery/fakes.dart';

// Same small test key as test/adb/adb_unit_test.dart.
final _p = (BigInt.one << 521) - BigInt.one;
final _q = (BigInt.one << 607) - BigInt.one;

AdbKey _testKey() {
  final n = _p * _q;
  final phi = (_p - BigInt.one) * (_q - BigInt.one);
  final e = BigInt.from(65537);
  return AdbKey(n, e, e.modInverse(phi));
}

const _tv = Tv(id: 'ip:127.0.0.1', name: 'TV', ip: '127.0.0.1');

Future<ProbeOutcome> _ok(Tv tv, Duration t) async =>
    const ProbeOutcome(true, 'ok');
Future<ProbeOutcome> _no(Tv tv, Duration t) async =>
    const ProbeOutcome(false, 'no');

/// A fake adbd on localhost that replies per [mode]:
/// `cnxn` (authorized), `reauth` (key unknown), `stls`, `silent`.
Future<(ServerSocket, List<int>)> _fakeAdbd(String mode) async {
  final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final received = <int>[];
  server.listen((s) {
    final buf = BytesBuilder();
    s.listen((data) {
      buf.add(data);
      final bytes = buf.toBytes();
      if (bytes.length < adbHeaderLength) return;
      final (h, len) = AdbMessage.decodeHeader(
          Uint8List.sublistView(bytes, 0, adbHeaderLength));
      if (bytes.length < adbHeaderLength + len) return;
      buf.clear();
      if (bytes.length > adbHeaderLength + len) {
        buf.add(bytes.sublist(adbHeaderLength + len));
      }
      received.add(h.command);
      final token =
          AdbMessage(AdbCommand.auth, AdbAuthType.token, 0, Uint8List(20));
      switch ((mode, h.command)) {
        case ('silent', _):
          break;
        case ('stls', AdbCommand.cnxn):
          s.add(AdbMessage(AdbCommand.stls, 1, 0).encode());
        case (_, AdbCommand.cnxn):
          s.add(token.encode());
        case ('cnxn', AdbCommand.auth):
          s.add(AdbMessage.text(AdbCommand.cnxn, adbVersion, 4096,
                  'device::ro.product.model=VU3;')
              .encode());
        case ('reauth', AdbCommand.auth):
          s.add(token.encode());
      }
    }, onError: (Object _) {});
  });
  return (server, received);
}

void main() {
  test('collects capabilities and details, stamps the time', () async {
    final now = DateTime.utc(2026, 10, 28);
    final prober = CapabilityProber(
      clock: () => now,
      castProbe: _ok,
      dialProbe: _ok,
      sonyRestProbe: _no,
      adbProbe: (tv, key, t) async =>
          const ProbeOutcome(false, 'needs approval'),
      agentProbe: (tv, t) async => throw StateError('boom'),
    );
    final r = await prober.probe(_tv);
    expect(r.capabilities, {TvCapability.cast, TvCapability.dial});
    expect(r.tv.capabilitiesCheckedAt, now);
    expect(r.detail(TvCapability.adb), 'needs approval');
    expect(r.detail(TvCapability.agent), startsWith('error'));
    expect(r.details.keys, TvCapability.values.toSet());
  });

  test('probes run in parallel and time out', () async {
    final prober = CapabilityProber(
      timeout: const Duration(milliseconds: 200),
      castProbe: (tv, t) => Completer<ProbeOutcome>().future,
      dialProbe: (tv, t) async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        return const ProbeOutcome(true, 'ok');
      },
      sonyRestProbe: _no,
      adbProbe: (tv, key, t) => Completer<ProbeOutcome>().future,
      agentProbe: _no,
    );
    final sw = Stopwatch()..start();
    final r = await prober.probe(_tv);
    expect(sw.elapsedMilliseconds, lessThan(1500));
    expect(r.capabilities, {TvCapability.dial});
    expect(r.detail(TvCapability.cast), 'timeout');
  });

  group('HTTP probes', () {
    test('dial, sonyRest and agent from responses', () async {
      final net = FakeNet(get: {
        'http://10.0.0.5:8008/ssdp/device-desc.xml':
            const NetResponse(200, '<root/>'),
        'http://10.0.0.5/sony/audio': const NetResponse(
            200, '{"result":[[{"target":"speaker","volume":10}]],"id":33}'),
        'http://10.0.0.5:8790/v1/status': const NetResponse(200, '{"ok":true}'),
      });
      final r = await CapabilityProber(
        net: net,
        castProbe: _no,
        adbProbe: (tv, key, t) async => const ProbeOutcome(false, 'closed'),
      ).probe(const Tv(id: 'x', name: 'TV', ip: '10.0.0.5'));
      expect(r.capabilities, {
        TvCapability.dial,
        TvCapability.sonyRest,
        TvCapability.agent,
      });
    });

    test('missing / error replies do not count', () async {
      final net = FakeNet(get: {
        'http://10.0.0.5/sony/audio':
            const NetResponse(200, '{"error":[403,"Forbidden"],"id":33}'),
        'http://10.0.0.5:8790/v1/status': const NetResponse(401, ''),
      });
      final r = await CapabilityProber(
        net: net,
        castProbe: _no,
        adbProbe: (tv, key, t) async => const ProbeOutcome(false, 'closed'),
      ).probe(const Tv(id: 'x', name: 'TV', ip: '10.0.0.5'));
      expect(r.capabilities, isEmpty);
      expect(r.detail(TvCapability.agent), contains('needs token'));
      expect(r.detail(TvCapability.sonyRest), startsWith('error'));
      expect(r.detail(TvCapability.dial), 'unreachable');
    });
  });

  group('adb probe', () {
    const t = Duration(seconds: 2);

    Future<ProbeOutcome> run(String mode, {AdbKey? key}) async {
      final (server, _) = await _fakeAdbd(mode);
      try {
        return await CapabilityProber.probeAdb(
          _tv.copyWith(adbPort: server.port),
          key,
          t,
        );
      } finally {
        await server.close();
      }
    }

    test('authorized key → capability', () async {
      final o = await run('cnxn', key: _testKey());
      expect(o.ok, isTrue);
      expect(o.detail, 'authorized');
    });

    test('unknown key → needs approval, public key never sent', () async {
      final (server, received) = await _fakeAdbd('reauth');
      final o = await CapabilityProber.probeAdb(
        _tv.copyWith(adbPort: server.port),
        _testKey(),
        t,
      );
      await server.close();
      expect(o.ok, isFalse);
      expect(o.detail, 'needs approval');
      // CNXN + one signature only.
      expect(received, [AdbCommand.cnxn, AdbCommand.auth]);
    });

    test('STLS → needs approval (TLS)', () async {
      final o = await run('stls', key: _testKey());
      expect(o.ok, isFalse);
      expect(o.detail, 'needs approval (TLS)');
    });

    test('open port without a key', () async {
      final o = await run('silent');
      expect(o.ok, isFalse);
      expect(o.detail, 'open (no key)');
    });

    test('closed port', () async {
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final port = server.port;
      await server.close();
      final o = await CapabilityProber.probeAdb(
        _tv.copyWith(adbPort: port),
        _testKey(),
        t,
      );
      expect(o.detail, 'closed');
    });
  });
}
