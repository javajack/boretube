import 'package:boretube_mobile/ops/device_profile.dart';
import 'package:boretube_mobile/ops/tv_ops.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_tv.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final vu3 = loadProfile('sony-bravia-vu3');
  final generic = loadProfile('generic');
  final repo = ProfileRepository([vu3, generic]);

  DeviceProps realProps() => DeviceProps(
        manufacturer: fixture('getprop_manufacturer.txt').trim(),
        device: fixture('getprop_device.txt').trim(),
        buildId: fixture('getprop_build.txt').trim(),
      );

  test('VU3 profile has the agreed data', () {
    expect(vu3.cleanup, hasLength(18));
    expect(vu3.extras.map((e) => e.pkg), [
      'com.sonyliv',
      'com.amazon.amazonvideo.livingroom',
      'com.apple.atve.androidtv.appletv',
    ]);
    expect(vu3.neverTouch, hasLength(20));
    expect(vu3.knownGood['com.google.android.tts'], contains('20251028'));
    expect(vu3.stockYouTube!.pkg, 'com.google.android.youtube.tv');
    expect(vu3.launcher!.a11yService, 'com.gathin.tvhome/.HomeKeyService');
    expect(vu3.readOnly, isFalse);
    expect(vu3.hasQuirk('absoluteVolumeIgnored'), isTrue);
    expect(generic.readOnly, isTrue);
    expect(generic.cleanup, isEmpty);
  });

  test('no cleanup or extras package is protected', () {
    for (final p in [vu3, generic]) {
      final protected = {...kBaselineNeverTouch, ...p.neverTouch};
      for (final c in [...p.cleanup, ...p.extras]) {
        expect(protected, isNot(contains(c.pkg)), reason: c.pkg);
        expect(TvOps.checkPackage(c.pkg), c.pkg);
      }
    }
  });

  test('every cleanup package exists on the real TV', () {
    final all = TvOps.parsePackageList(fixture('pm_list_u.txt'));
    for (final c in [...vu3.cleanup, ...vu3.extras]) {
      expect(all, contains(c.pkg), reason: c.pkg);
    }
  });

  test('DeviceProps parses the 3-line getprop output', () {
    final p = DeviceProps.parse('Sony\nBRAVIA_VU3_2K\nUKR1.240726.001\n');
    expect(p.manufacturer, 'Sony');
    expect(p.device, 'BRAVIA_VU3_2K');
    expect(p.buildId, 'UKR1.240726.001');
  });

  test('real VU3 props match the VU3 profile with a tested build', () {
    final m = repo.match(realProps());
    expect(m.profile.id, 'sony-bravia-vu3');
    expect(m.buildTested, isTrue);
  });

  test('other VU3 variants match; new firmware is flagged untested', () {
    for (final d in ['BRAVIA_VU3', 'BRAVIA_VU3_4K']) {
      final m = repo.match(
        DeviceProps(manufacturer: 'sony', device: d, buildId: 'X'),
      );
      expect(m.profile.id, 'sony-bravia-vu3');
      expect(m.buildTested, isFalse);
    }
  });

  test('unknown TVs get the read-only generic profile', () {
    final m = repo.match(
      const DeviceProps(
        manufacturer: 'TCL',
        device: 'BRAVIA_VU3',
        buildId: 'UKR1.240726.001',
      ),
    );
    expect(m.profile.id, 'generic');
    expect(m.profile.readOnly, isTrue);
    final m2 = repo.match(
      const DeviceProps(manufacturer: 'Sony', device: 'BRAVIA_XR', buildId: ''),
    );
    expect(m2.profile.id, 'generic');
  });

  test('profiles load from the asset bundle', () async {
    final r = await ProfileRepository.load(rootBundle);
    expect(r.profiles.map((p) => p.id), ['sony-bravia-vu3', 'generic']);
    expect(r.generic.id, 'generic');
  });
}
