import 'dart:convert';
import 'dart:io';

import 'package:boretube_mobile/adb/adb_identity.dart';
import 'package:boretube_mobile/agent/agent_installer.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../ops/fake_tv.dart';
import 'fake_agent.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeAgentTv tv;
  late FakeAgentHttp agent;
  late MemorySecretStore secrets;

  setUp(() {
    tv = FakeAgentTv();
    agent = FakeAgentHttp(tv);
    secrets = MemorySecretStore();
  });

  Future<InstallProgress> last(Stream<InstallProgress> s) async {
    final all = await s.toList();
    expect(all.last.finished, isTrue);
    return all.last;
  }

  SetupStepState stateOf(InstallProgress p, InstallStepId id) =>
      p.step(id)!.state;

  test('install: exact command sequence and token saved', () async {
    final b = fakeBundle(size: 100 * 1024);
    final p = await last(
        installerFor(tv, agent, bundle: b, secrets: secrets).install());
    expect(p.ok, isTrue, reason: '${p.error}');
    expect(p.steps.every((s) => s.state == SetupStepState.done), isTrue,
        reason: p.steps.map((s) => '${s.id.name}:${s.state.name}').join(' '));
    // ~100 KB in 36 KiB chunks.
    final chunks = tv.log.where((c) => c.startsWith('printf')).length;
    expect(chunks, 3);
    expect(tv.writes, [
      'rm -f /data/local/tmp/bt-agent.apk',
      'pm install -r -g /data/local/tmp/bt-agent.apk',
      'rm -f /data/local/tmp/bt-agent.apk',
      'appops set com.rakesh.boretube.agent GET_USAGE_STATS allow',
      'appops set com.rakesh.boretube.agent SYSTEM_ALERT_WINDOW allow',
      'pm grant com.rakesh.boretube.agent '
          'android.permission.WRITE_SECURE_SETTINGS',
      'pm grant com.rakesh.boretube.agent '
          'android.permission.POST_NOTIFICATIONS',
      'am start-foreground-service -n '
          'com.rakesh.boretube.agent/.GuardService',
    ]);
    expect(await AgentTokenStore(secrets).read('tv1'), kToken);
    expect(agent.paths, [
      '/v1/status',
      '/v1/profile',
      '/v1/approveBuild',
      '/v1/status',
    ]);
    final profile = agent.requests[1];
    expect(jsonDecode(profile.body)['id'], 'sony-bravia-vu3');
    expect(jsonDecode(profile.body)['keepDisabled'], isEmpty);
  });

  test('install: a 2 MB APK is pushed in chunks under 48 KiB', () async {
    final b = fakeBundle(size: 2 * 1024 * 1024 + 17);
    final p = await last(installerFor(tv, agent, bundle: b).install());
    expect(p.ok, isTrue, reason: '${p.error}');
    final chunks = tv.log.where((c) => c.startsWith('printf')).toList();
    expect(chunks, hasLength(57));
    expect(chunks.every((c) => c.length < 48 * 1024 + 100), isTrue);
  });

  test('install: service component comes from the manifest', () {
    const m = AgentManifest(
      versionName: '1',
      sha256: 'x',
      service: 'com.rakesh.boretube.agent.guard.Guard',
    );
    expect(
      AgentInstaller.startCommand(m),
      'am start-foreground-service -n '
      'com.rakesh.boretube.agent/com.rakesh.boretube.agent.guard.Guard',
    );
    expect(
      AgentManifest.fromJson(const {'versionName': '1', 'sha256': 'AB'})
          .service,
      '.GuardService',
    );
  });

  test('install: waits for the token file', () async {
    tv.tokenDelay = 4;
    final p = await last(installerFor(tv, agent).install());
    expect(p.ok, isTrue, reason: '${p.error}');
    expect(
      tv.log.where((c) => c.startsWith('cat ')).length,
      5,
    );
  });

  test('install: token never appears → fails after 10 s', () async {
    tv.token = null;
    final p = await last(installerFor(tv, agent).install());
    expect(p.ok, isFalse);
    expect(stateOf(p, InstallStepId.token), SetupStepState.failed);
    expect(stateOf(p, InstallStepId.approve), SetupStepState.skipped);
  });

  test('install: self-ADB approval step waits for "Always allow"', () async {
    agent.selfAdb = ['needsApproval', 'needsApproval', 'needsApproval', 'ok'];
    final all = await installerFor(tv, agent).install().toList();
    final waiting = all.where((p) => p.awaitingApproval).toList();
    expect(waiting, isNotEmpty);
    expect(
      waiting.first.step(InstallStepId.approve)!.detail,
      contains('Always allow'),
    );
    expect(all.last.ok, isTrue);
    expect(stateOf(all.last, InstallStepId.approve), SetupStepState.done);
  });

  test('install: approval never given → limited, still installed', () async {
    agent.selfAdb = ['needsApproval'];
    final p = await last(installerFor(tv, agent).install());
    expect(p.ok, isTrue);
    expect(stateOf(p, InstallStepId.approve), SetupStepState.warn);
    expect(p.step(InstallStepId.approve)!.detail, contains('limited'));
  });

  test('install: checksum mismatch stops before touching the TV', () async {
    final good = fakeBundle();
    final bad = AgentBundle(
      AgentManifest(versionName: '1', sha256: 'ab' * 32),
      good.apk,
    );
    final p = await last(installerFor(tv, agent, bundle: bad).install());
    expect(p.ok, isFalse);
    expect(stateOf(p, InstallStepId.verify), SetupStepState.failed);
    expect(tv.log, isEmpty);
  });

  test('install: damaged copy on the TV is caught and removed', () async {
    tv.corrupt = true;
    final p = await last(installerFor(tv, agent).install());
    expect(p.ok, isFalse);
    expect(stateOf(p, InstallStepId.push), SetupStepState.failed);
    expect(tv.installed, isFalse);
    expect(tv.log.last, 'rm -f /data/local/tmp/bt-agent.apk');
  });

  test('install: missing bundle', () async {
    final p = await last(installerFor(tv, agent, missing: true).install());
    expect(p.ok, isFalse);
    expect(p.step(InstallStepId.verify)!.detail,
        'TV Guard package missing from this build');
    expect(tv.log, isEmpty);
  });

  test('the bundled APK (when present) matches its manifest', () {
    final m = File('assets/agent/manifest.json');
    if (!m.existsSync()) return;
    final manifest = AgentManifest.fromJson(
      jsonDecode(m.readAsStringSync()) as Map<String, dynamic>,
    );
    final apk = File('assets/agent/${manifest.apk}').readAsBytesSync();
    final b = AgentBundle(manifest, apk);
    expect(b.actualSha256, manifest.sha256);
    expect(manifest.pkg, 'com.rakesh.boretube.agent');
    expect(manifest.service, '.GuardService');
    expect(manifest.signingCertSha256, isNotEmpty);
    expect(apk.length, greaterThan(100 * 1024));
  });

  test('bundle loader reports missing assets', () async {
    expect(
      AgentBundle.load(_EmptyBundle()),
      throwsA(isA<AgentBundleMissing>()),
    );
  });

  test('install: optional grant failing is a warning', () async {
    tv.failing.add('pm grant com.rakesh.boretube.agent '
        'android.permission.POST_NOTIFICATIONS');
    final p = await last(installerFor(tv, agent).install());
    expect(p.ok, isTrue);
    expect(stateOf(p, InstallStepId.grant), SetupStepState.warn);
  });

  test('install: usage access refused is fatal', () async {
    tv.failing.add('appops set com.rakesh.boretube.agent GET_USAGE_STATS');
    final p = await last(installerFor(tv, agent).install());
    expect(p.ok, isFalse);
    expect(stateOf(p, InstallStepId.grant), SetupStepState.failed);
  });

  group('repair', () {
    Future<AgentDiagnosis> diagnose() =>
        installerFor(tv, agent, secrets: secrets)
            .diagnose(bundled: fakeBundle().manifest);

    test('diagnoses each case', () async {
      expect((await diagnose()).problems, {AgentProblem.notInstalled});
      tv
        ..installed = true
        ..disabled = true;
      expect(
        (await diagnose()).problems,
        {AgentProblem.disabled, AgentProblem.notRunning},
      );
      tv
        ..disabled = false
        ..running = true;
      expect((await diagnose()).problems, {AgentProblem.tokenMismatch});
      await AgentTokenStore(secrets).write('tv1', 'wrongwrongwrongwrong');
      expect((await diagnose()).problems, {AgentProblem.tokenMismatch});
      await AgentTokenStore(secrets).write('tv1', kToken);
      agent.selfAdb = ['needsApproval'];
      expect(
        (await diagnose()).problems,
        {AgentProblem.selfAdbNeedsApproval},
      );
      agent.selfAdb = ['ok'];
      tv.versionCode = 0;
      tv.versionName = '0.9';
      expect((await diagnose()).problems, {AgentProblem.outdated});
    });

    test('plans per problem', () {
      List<InstallStepId> plan(Set<AgentProblem> p) =>
          AgentInstaller.repairPlan(AgentDiagnosis(problems: p));
      expect(plan({AgentProblem.notInstalled}), AgentInstaller.installSteps);
      expect(plan({AgentProblem.disabled, AgentProblem.notRunning}), [
        InstallStepId.enable,
        InstallStepId.grant,
        InstallStepId.start,
        InstallStepId.token,
        InstallStepId.approve,
        InstallStepId.profile,
        InstallStepId.check,
      ]);
      expect(plan({AgentProblem.tokenMismatch}), [
        InstallStepId.grant,
        InstallStepId.token,
        InstallStepId.approve,
        InstallStepId.profile,
        InstallStepId.check,
      ]);
    });

    test('disabled agent is enabled and started', () async {
      tv
        ..installed = true
        ..disabled = true;
      final p = await last(
        installerFor(tv, agent, secrets: secrets).repair(),
      );
      expect(p.ok, isTrue, reason: '${p.error}');
      expect(tv.writes, contains('pm enable com.rakesh.boretube.agent'));
      expect(tv.writes.any((c) => c.startsWith('pm install')), isFalse);
      expect(tv.running, isTrue);
      expect(await AgentTokenStore(secrets).read('tv1'), kToken);
    });

    test('missing agent is reinstalled', () async {
      final p = await last(installerFor(tv, agent).repair());
      expect(p.ok, isTrue, reason: '${p.error}');
      expect(p.steps.first.id, InstallStepId.diagnose);
      expect(tv.installed, isTrue);
    });

    test('changed token is re-read', () async {
      tv
        ..installed = true
        ..running = true;
      await AgentTokenStore(secrets).write('tv1', 'oldoldoldoldoldold');
      final p = await last(
        installerFor(tv, agent, secrets: secrets).repair(),
      );
      expect(p.ok, isTrue, reason: '${p.error}');
      expect(await AgentTokenStore(secrets).read('tv1'), kToken);
      expect(tv.writes.any((c) => c.startsWith('am start')), isFalse);
    });
  });

  test('keepDisabled lists the profile packages disabled now', () async {
    final vu3 = loadProfile('sony-bravia-vu3');
    final real = FakeTv();
    real.disabled.remove('com.sonyliv');
    final i = AgentInstaller(
      adb: real,
      tvId: 'tv1',
      tokens: AgentTokenStore(MemorySecretStore()),
      clientFor: (_) => throw UnimplementedError(),
      loadBundle: () async => fakeBundle(),
      profile: vu3.raw,
    );
    final keep = await i.keepDisabled();
    expect(keep, [
      for (final c in vu3.cleanup) c.pkg,
      'com.amazon.amazonvideo.livingroom',
      'com.apple.atve.androidtv.appletv',
    ]);
    expect(real.writes, isEmpty);
  });

  test('repair of an installed agent does not re-approve the build', () async {
    tv
      ..installed = true
      ..running = true;
    await AgentTokenStore(secrets).write('tv1', kToken);
    final p = await last(installerFor(tv, agent, secrets: secrets).repair());
    expect(p.ok, isTrue, reason: '${p.error}');
    expect(agent.paths, isNot(contains('/v1/approveBuild')));
  });

  test('uninstall removes the package and the token', () async {
    tv
      ..installed = true
      ..running = true;
    await AgentTokenStore(secrets).write('tv1', kToken);
    final ok = await installerFor(tv, agent, secrets: secrets).uninstall();
    expect(ok, isTrue);
    expect(tv.writes, ['pm uninstall com.rakesh.boretube.agent']);
    expect(await AgentTokenStore(secrets).read('tv1'), isNull);
  });
}

class _EmptyBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async =>
      throw StateError('Unable to load asset: $key');
}
