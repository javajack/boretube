import 'dart:async';
import 'dart:io';

import 'package:boretube_mobile/adb/adb_identity.dart';
import 'package:boretube_mobile/adb/adb_key.dart';
import 'package:boretube_mobile/discovery/discovery_service.dart';
import 'package:boretube_mobile/discovery/subnet_sweep.dart';
import 'package:boretube_mobile/models/whitelist_entry.dart';
import 'package:boretube_mobile/ops/tv_ops.dart';
import 'package:boretube_mobile/providers/now_playing.dart';
import 'package:boretube_mobile/providers/providers.dart';
import 'package:boretube_mobile/providers/security_providers.dart';
import 'package:boretube_mobile/providers/tv_providers.dart';
import 'package:boretube_mobile/security/biometric.dart';
import 'package:boretube_mobile/services/lock_service.dart';
import 'package:boretube_mobile/tv/capabilities.dart';
import 'package:boretube_mobile/tv/tv.dart';
import 'package:boretube_mobile/tv/tv_store.dart';
import 'package:boretube_mobile/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// LockService without the foreground-service plugin.
class FakeLockService extends LockService {
  @override
  void init() {}

  @override
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
  }) async {}

  @override
  Future<void> stop() async {}
}

class FakeBiometric implements BiometricAuth {
  bool available;
  bool result;
  int calls = 0;

  FakeBiometric({this.available = false, this.result = false});

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<bool> authenticate(String reason) async {
    calls++;
    return result;
  }
}

/// Discovery that emits a fixed list (and optionally stays "searching").
class FakeDiscovery extends DiscoveryService {
  final List<Tv> tvs;
  final bool keepSearching;

  FakeDiscovery(this.tvs, {this.keepSearching = false})
      : super(enableSweep: false);

  @override
  Stream<List<Tv>> discover({
    Duration timeout = const Duration(seconds: 10),
    void Function(SweepEvent event)? onSweepProgress,
  }) {
    final c = StreamController<List<Tv>>();
    scheduleMicrotask(() {
      onSweepProgress?.call(const SweepEvent(scanned: 148, total: 254));
      c.add(tvs);
      if (!keepSearching) c.close();
    });
    return c.stream;
  }

  @override
  Future<Tv?> relocate(
    Tv saved, {
    Duration timeout = const Duration(seconds: 10),
    Duration quickTimeout = const Duration(milliseconds: 1500),
  }) async =>
      null;
}

/// Prober whose probes answer instantly with [caps].
CapabilityProber fakeProber(Set<TvCapability> caps) {
  ProbeOutcome o(TvCapability c) =>
      ProbeOutcome(caps.contains(c), caps.contains(c) ? 'ok' : 'closed');
  return CapabilityProber(
    castProbe: (_, __) async => o(TvCapability.cast),
    dialProbe: (_, __) async => o(TvCapability.dial),
    sonyRestProbe: (_, __) async => o(TvCapability.sonyRest),
    adbProbe: (_, __, ___) async => o(TvCapability.adb),
    agentProbe: (_, __) async => o(TvCapability.agent),
  );
}

const castOnlySony = Tv(
  id: 'udn:cast-only',
  name: 'Bedroom TV',
  manufacturer: 'Sony',
  model: 'BRAVIA',
  ip: '192.168.1.9',
  capabilities: {TvCapability.cast, TvCapability.dial},
);

const adbSony = Tv(
  id: 'adb:adb-qaezcxxq07001865',
  name: 'Living Room TV',
  manufacturer: 'Sony',
  model: 'BRAVIA VU3',
  ip: '192.168.1.3',
  adbSerial: 'adb-qaezcxxq07001865',
  capabilities: {
    TvCapability.cast,
    TvCapability.dial,
    TvCapability.sonyRest,
    TvCapability.adb,
  },
);

class TestEnv {
  final SharedPreferences prefs;
  final TvStore store;
  final MemorySecretStore secrets;
  final FakeBiometric biometric;

  TestEnv(this.prefs, this.store, this.secrets, this.biometric);

  static Future<TestEnv> create({
    List<Tv> tvs = const [],
    FakeBiometric? biometric,
    Map<String, Object> prefs = const {},
  }) async {
    SharedPreferences.setMockInitialValues({...prefs});
    final p = await SharedPreferences.getInstance();
    final store = await TvStore.load(prefs: p);
    for (final t in tvs) {
      await store.upsert(t);
    }
    return TestEnv(p, store, MemorySecretStore(), biometric ?? FakeBiometric());
  }

  List<Override> overrides({
    NowPlaying? now,
    Set<TvCapability>? probeCaps,
    DiscoveryService? discovery,
    TvOps? ops,
    bool keyPending = false,
  }) =>
      [
        sharedPrefsProvider.overrideWithValue(prefs),
        tvStoreProvider.overrideWith((ref) => store),
        secretStoreProvider.overrideWithValue(secrets),
        biometricAuthProvider.overrideWithValue(biometric),
        lockServiceProvider.overrideWith((ref) => FakeLockService()),
        // No key: no ADB session and no RSA generation in tests.
        adbKeyProvider.overrideWith(
          (ref) => keyPending
              ? Completer<AdbKey>().future
              : Future<AdbKey>.error(StateError('no key in tests')),
        ),
        tvOpsProvider.overrideWith((ref) async => ops),
        nowPlayingProvider.overrideWith(
          (ref) => NowPlayingNotifier.fixed(now ?? const NowPlaying()),
        ),
        capabilityProberProvider.overrideWithValue(
          fakeProber(probeCaps ?? const {}),
        ),
        discoveryServiceProvider.overrideWithValue(
          discovery ?? FakeDiscovery(const []),
        ),
      ];
}

/// Wraps [child] in the app theme with a 360×800 phone viewport.
Future<void> pumpScreen(
  WidgetTester tester,
  Widget child, {
  required List<Override> overrides,
  bool scaffold = false,
  double textScale = 1,
  Size size = const Size(360, 800),
}) async {
  tester.view.physicalSize = size * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.dark,
        builder: (context, c) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
          ),
          child: c!,
        ),
        home: scaffold ? Scaffold(body: child) : child,
      ),
    ),
  );
}

/// Pumps a few frames without waiting for repeating animations.
Future<void> settle(WidgetTester tester, [int frames = 6]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Real Roboto + Material Icons so golden screenshots are readable.
Future<void> loadAppFonts() async {
  const dir = '/opt/flutter/bin/cache/artifacts/material_fonts';
  Future<void> load(String family, List<String> files) async {
    final loader = FontLoader(family);
    var any = false;
    for (final f in files) {
      final file = File('$dir/$f');
      if (!file.existsSync()) continue;
      any = true;
      loader.addFont(
        Future.value(ByteData.sublistView(file.readAsBytesSync())),
      );
    }
    if (any) await loader.load();
  }

  await load('Roboto', [
    'Roboto-Regular.ttf',
    'Roboto-Medium.ttf',
    'Roboto-Bold.ttf',
    'Roboto-Black.ttf',
    'Roboto-Light.ttf',
  ]);
  await load('MaterialIcons', ['MaterialIcons-Regular.otf']);
}
