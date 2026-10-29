import 'dart:convert';
import 'dart:typed_data';

import 'package:boretube_mobile/adb/adb_connection.dart';
import 'package:boretube_mobile/learn/learn_installer.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

/// A TV that understands the Learn installer's few commands.
class FakeLearnTv implements AdbShell {
  final log = <String>[];
  String? installed;
  String pmOut = 'Success';
  bool damage = false;
  final _apk = BytesBuilder();
  String bundleVersion = '0.1.0';

  @override
  Future<AdbShellResult> shell(String c) async {
    log.add(c);
    if (c.startsWith('rm -f')) {
      _apk.clear();
      return const AdbShellResult('', 0);
    }
    if (c.startsWith('printf %s')) {
      final b64 = c.substring(c.indexOf("'") + 1, c.lastIndexOf("'"));
      _apk.add(base64Decode(b64));
      return const AdbShellResult('', 0);
    }
    if (c.startsWith('sha256sum')) {
      final bytes = _apk.toBytes();
      final sum = damage ? 'deadbeef' : sha256.convert(bytes).toString();
      return AdbShellResult('$sum  ${LearnInstaller.tmpApk}\n', 0);
    }
    if (c.startsWith('pm install')) {
      if (pmOut.contains('Success')) installed = bundleVersion;
      return AdbShellResult(pmOut, pmOut.contains('Success') ? 0 : 1);
    }
    if (c.startsWith('dumpsys package com.rakesh.boretube.learn')) {
      return AdbShellResult(
        installed == null ? '' : '    versionName=$installed\n',
        0,
      );
    }
    if (c.startsWith('monkey')) {
      return const AdbShellResult('Events injected: 1\n', 0);
    }
    return const AdbShellResult('', 0);
  }
}

LearnBundle bundle({String version = '0.1.0', int size = 80 * 1024}) {
  final apk = Uint8List.fromList(List.generate(size, (i) => i % 251));
  return LearnBundle(
    LearnManifest(
      versionName: version,
      versionCode: 1,
      sha256: sha256.convert(apk).toString(),
    ),
    apk,
  );
}

void main() {
  late FakeLearnTv tv;
  setUp(() => tv = FakeLearnTv());

  LearnInstaller installer(LearnBundle b) =>
      LearnInstaller(adb: tv, tvId: 'tv1', loadBundle: () async => b);

  test('diagnose: missing, current, update available', () async {
    final b = bundle(version: '0.2.0');
    expect((await installer(b).diagnose()).state, LearnInstallState.missing);
    tv.installed = '0.1.0';
    final d = await installer(b).diagnose();
    expect(d.state, LearnInstallState.updateAvailable);
    expect(d.installed, '0.1.0');
    tv.installed = '0.2.0';
    expect((await installer(b).diagnose()).state, LearnInstallState.current);
  });

  test('install: push in chunks, check the copy, install, verify', () async {
    final r = await installer(bundle()).install();
    expect(r.ok, isTrue, reason: r.message);
    expect(tv.installed, '0.1.0');
    expect(tv.log.where((c) => c.startsWith('printf')).length, 3);
    // The version before is read first, for the journal.
    expect(tv.log.first, LearnInstaller.versionCommand);
    expect(
      tv.log.where((c) => !c.startsWith('printf')).toList(),
      [
        LearnInstaller.versionCommand,
        'rm -f ${LearnInstaller.tmpApk}',
        'sha256sum ${LearnInstaller.tmpApk}',
        'pm install -r ${LearnInstaller.tmpApk}',
        'rm -f ${LearnInstaller.tmpApk}',
        LearnInstaller.versionCommand,
      ],
    );
  });

  test('a damaged copy stops before installing and cleans up', () async {
    tv.damage = true;
    final r = await installer(bundle()).install();
    expect(r.ok, isFalse);
    expect(r.message, contains('damaged'));
    expect(tv.log.any((c) => c.startsWith('pm install')), isFalse);
    expect(tv.log.last, 'rm -f ${LearnInstaller.tmpApk}');
  });

  test('a different signing key says so in plain words', () async {
    tv.pmOut = 'Failure [INSTALL_FAILED_UPDATE_INCOMPATIBLE: ...]';
    final r = await installer(bundle()).install();
    expect(r.ok, isFalse);
    expect(r.message, contains('different key'));
  });

  test('open launches the TV app', () async {
    expect(await installer(bundle()).open(), isTrue);
    expect(tv.log.last, startsWith('monkey -p com.rakesh.boretube.learn'));
  });

  test('the manifest reads the shape the build writes', () {
    final m = LearnManifest.fromJson(
      jsonDecode(
        '{"versionName":"0.1.0","versionCode":1,"sha256":"AB",'
        '"package":"com.rakesh.boretube.learn","apk":"boretube-learn.apk"}',
      ) as Map<String, dynamic>,
    );
    expect(m.sha256, 'ab');
    expect(m.apk, 'boretube-learn.apk');
  });
}
