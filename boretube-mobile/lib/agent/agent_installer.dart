import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';

import '../adb/adb_connection.dart';
import '../adb/adb_identity.dart';
import '../ops/device_profile.dart';
import '../ops/journal.dart';
import '../ops/tv_ops.dart';
import 'agent_client.dart';

// ── bundle ──

/// Thrown when the app was built without `assets/agent/`.
class AgentBundleMissing implements Exception {
  final String detail;
  const AgentBundleMissing([this.detail = '']);
  static const message = 'TV Guard package missing from this build';
  @override
  String toString() => detail.isEmpty ? message : '$message ($detail)';
}

/// `assets/agent/manifest.json`, written by the agent build.
class AgentManifest {
  static const defaultService = '.GuardService';

  final String pkg;
  final String versionName;
  final int versionCode;
  final String sha256;
  final String signingCertSha256;

  /// Component class of the foreground service, e.g. `.GuardService`.
  final String service;
  final String apk;

  const AgentManifest({
    this.pkg = kAgentPackage,
    required this.versionName,
    this.versionCode = 0,
    required this.sha256,
    this.signingCertSha256 = '',
    this.service = defaultService,
    this.apk = 'boretube-agent.apk',
  });

  factory AgentManifest.fromJson(Map<String, dynamic> j) {
    String s(String k, [String d = '']) {
      final v = j[k];
      return v is String && v.isNotEmpty ? v : d;
    }

    return AgentManifest(
      pkg: s('package', kAgentPackage),
      versionName: s('versionName', s('version', '?')),
      versionCode: (j['versionCode'] as num?)?.toInt() ?? 0,
      sha256: s('sha256').toLowerCase(),
      signingCertSha256: s('signingCertSha256', s('certSha256')),
      service: s('service', defaultService),
      apk: s('apk', 'boretube-agent.apk'),
    );
  }

  Map<String, dynamic> toJson() => {
        'package': pkg,
        'versionName': versionName,
        'versionCode': versionCode,
        'sha256': sha256,
        'signingCertSha256': signingCertSha256,
        'service': service,
        'apk': apk,
      };

  /// `pkg/.GuardService` (or a fully qualified class).
  String get component => '$pkg/$service';
}

class AgentBundle {
  static const dir = 'assets/agent';

  final AgentManifest manifest;
  final Uint8List apk;

  const AgentBundle(this.manifest, this.apk);

  String get actualSha256 => sha256.convert(apk).toString();

  /// Loads the manifest and APK; throws [AgentBundleMissing] if absent.
  static Future<AgentBundle> load([AssetBundle? bundle]) async {
    final b = bundle ?? rootBundle;
    final AgentManifest m;
    try {
      m = AgentManifest.fromJson(
        jsonDecode(await b.loadString('$dir/manifest.json'))
            as Map<String, dynamic>,
      );
    } catch (e) {
      throw AgentBundleMissing('$e');
    }
    try {
      final data = await b.load('$dir/${m.apk}');
      return AgentBundle(m, data.buffer.asUint8List());
    } catch (e) {
      throw AgentBundleMissing('$e');
    }
  }
}

// ── token store ──

/// The agent's bearer token per TV, in secure storage.
class AgentTokenStore {
  final SecretStore store;
  const AgentTokenStore(this.store);

  static String keyFor(String tvId) => 'agent_token.$tvId';

  Future<String?> read(String tvId) async {
    final t = await store.read(keyFor(tvId));
    return t == null || t.isEmpty ? null : t;
  }

  Future<void> write(String tvId, String token) =>
      store.write(keyFor(tvId), token);

  Future<void> delete(String tvId) => store.delete(keyFor(tvId));
}

// ── progress ──

enum InstallStepId {
  diagnose,
  verify,
  push,
  install,
  enable,
  grant,
  start,
  token,
  approve,
  profile,
  check,
}

enum SetupStepState { pending, running, waiting, done, warn, failed, skipped }

class InstallStep {
  final InstallStepId id;
  final SetupStepState state;
  final String detail;

  const InstallStep(this.id,
      [this.state = SetupStepState.pending, this.detail = '']);

  String get title => switch (id) {
        InstallStepId.diagnose => 'Check TV Guard',
        InstallStepId.verify => 'Check the package',
        InstallStepId.push => 'Copy to the TV',
        InstallStepId.install => 'Install',
        InstallStepId.enable => 'Turn TV Guard back on',
        InstallStepId.grant => 'Give permissions',
        InstallStepId.start => 'Start TV Guard',
        InstallStepId.token => 'Pair with this phone',
        InstallStepId.approve => 'Allow TV Guard on the TV',
        InstallStepId.profile => 'Send TV settings',
        InstallStepId.check => 'Final check',
      };

  bool get finished =>
      state == SetupStepState.done ||
      state == SetupStepState.warn ||
      state == SetupStepState.failed ||
      state == SetupStepState.skipped;

  InstallStep copyWith(SetupStepState state, [String detail = '']) =>
      InstallStep(id, state, detail);
}

/// A snapshot of an install/repair run, emitted on every change.
class InstallProgress {
  final List<InstallStep> steps;
  final bool finished;
  final bool ok;
  final String? error;
  final AgentStatus? status;

  const InstallProgress({
    required this.steps,
    this.finished = false,
    this.ok = false,
    this.error,
    this.status,
  });

  InstallStep? step(InstallStepId id) {
    for (final s in steps) {
      if (s.id == id) return s;
    }
    return null;
  }

  /// The TV shows "Allow USB debugging?" for the agent's own key.
  bool get awaitingApproval =>
      step(InstallStepId.approve)?.state == SetupStepState.waiting;
}

class _StepFailed implements Exception {
  final String detail;
  const _StepFailed(this.detail);
}

// ── diagnosis ──

enum AgentProblem {
  notInstalled,
  disabled,
  notRunning,
  outdated,
  unreachable,
  tokenMismatch,
  selfAdbNeedsApproval,

  /// The agent reports `needsPhoneGrant`: re-run the grant commands.
  missingGrant,

  /// Health `mediaAccess` isn't ok: the notification-listener grant (what
  /// lets it see what's playing) is missing. Re-granted by the grant step.
  noMediaAccess,
}

class AgentDiagnosis {
  final Set<AgentProblem> problems;
  final String? installedVersion;
  final int? installedVersionCode;
  final AgentStatus? status;

  const AgentDiagnosis({
    required this.problems,
    this.installedVersion,
    this.installedVersionCode,
    this.status,
  });

  bool get healthy => problems.isEmpty;
  bool get installed => !problems.contains(AgentProblem.notInstalled);

  String describe() {
    if (problems.isEmpty) return 'TV Guard looks healthy';
    return [
      for (final p in problems)
        switch (p) {
          AgentProblem.notInstalled => 'not installed',
          AgentProblem.disabled => 'turned off on the TV',
          AgentProblem.notRunning => 'not running',
          AgentProblem.outdated => 'a newer version is ready',
          AgentProblem.unreachable => 'not answering on the network',
          AgentProblem.tokenMismatch => 'paired with a different key',
          AgentProblem.selfAdbNeedsApproval => 'waiting for "Allow" on the TV',
          AgentProblem.missingGrant => 'missing a permission',
          AgentProblem.noMediaAccess => 'can\'t see what\'s playing yet',
        },
    ].join(' · ');
  }
}

// ── versions ──

/// Compares dotted versions ("1.0.1" < "1.1.0"); non-numeric parts count
/// as 0.
int compareVersions(String a, String b) {
  List<int> parts(String v) => [
        for (final p in v.split(RegExp(r'[.\-+]')))
          int.tryParse(p.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0,
      ];
  final x = parts(a);
  final y = parts(b);
  for (var i = 0; i < x.length || i < y.length; i++) {
    final d = (i < x.length ? x[i] : 0) - (i < y.length ? y[i] : 0);
    if (d != 0) return d.sign;
  }
  return 0;
}

/// Whether [bundled] is newer than the agent reporting [running].
bool agentUpdateAvailable(String running, AgentManifest bundled) =>
    running.isNotEmpty &&
    bundled.versionName != '?' &&
    compareVersions(running, bundled.versionName) < 0;

// ── installer ──

typedef AgentClientFactory = AgentClient Function(String token);

/// Installs, repairs and removes TV Guard over ADB. Every command touches
/// only the agent package; nothing here needs the agent to be healthy.
class AgentInstaller {
  static const tmpApk = '/data/local/tmp/bt-agent.apk';
  static const tokenPath = '/sdcard/Android/data/$kAgentPackage/files/token';

  /// Raw bytes per push chunk: a multiple of 3 so each chunk encodes to
  /// base64 without padding; 48 KiB of base64 per shell command keeps
  /// well under the kernel's 128 KiB single-argument limit.
  static const chunkBytes = 36 * 1024;

  final AdbShell adb;
  final String tvId;
  final AgentTokenStore tokens;
  final AgentClientFactory clientFor;
  final Future<AgentBundle> Function() loadBundle;
  final Map<String, dynamic> profile;
  final Journal? journal;
  final DateTime Function() _clock;
  final Future<void> Function(Duration) _delay;

  final Duration pollEvery;
  final Duration tokenTimeout;
  final Duration startupTimeout;
  final Duration approvalTimeout;

  AgentInstaller({
    required this.adb,
    required this.tvId,
    required this.tokens,
    required this.clientFor,
    required this.loadBundle,
    this.profile = const {},
    this.journal,
    DateTime Function()? clock,
    Future<void> Function(Duration)? delay,
    this.pollEvery = const Duration(milliseconds: 500),
    this.tokenTimeout = const Duration(seconds: 10),
    this.startupTimeout = const Duration(seconds: 15),
    this.approvalTimeout = const Duration(minutes: 2),
  })  : _clock = clock ?? DateTime.now,
        _delay = delay ?? Future<void>.delayed;

  static const installSteps = [
    InstallStepId.verify,
    InstallStepId.push,
    InstallStepId.install,
    InstallStepId.grant,
    InstallStepId.start,
    InstallStepId.token,
    InstallStepId.approve,
    InstallStepId.profile,
    InstallStepId.check,
  ];

  // ── commands (exposed for tests) ──

  /// The agent's notification listener (1.1.0+): media sessions need it.
  static const mediaListener =
      '$kAgentPackage/$kAgentPackage.android.MediaListenerService';

  /// Lets the agent read media sessions. Optional: without it the agent
  /// falls back to a coarser view, so a refusal is only a warning.
  static String listenerCommand(String component) =>
      'cmd notification allow_listener $component';

  static List<String> grantCommands(String pkg) => [
        'appops set $pkg GET_USAGE_STATS allow',
        'appops set $pkg SYSTEM_ALERT_WINDOW allow',
        'pm grant $pkg android.permission.WRITE_SECURE_SETTINGS',
        'pm grant $pkg android.permission.POST_NOTIFICATIONS',
        listenerCommand(
          pkg == kAgentPackage
              ? mediaListener
              : '$pkg/$pkg.android.MediaListenerService',
        ),
      ];

  static const diagnoseCommand = 'pm list packages $kAgentPackage; '
      'echo ---; pm list packages -d $kAgentPackage; echo ---; '
      'pidof $kAgentPackage; echo ---; '
      'dumpsys package $kAgentPackage | grep -m2 -E "versionCode|versionName"';

  static String startCommand(AgentManifest m) =>
      'am start-foreground-service -n ${m.component}';

  static const uninstallCommand = 'pm uninstall $kAgentPackage';

  static final _servicePattern = RegExp(r'^\.?[a-zA-Z0-9_.$]+$');
  static final _tokenPattern = RegExp(r'^[A-Za-z0-9_-]{16,256}$');

  // ── public flows ──

  /// Full install. Emits a snapshot after every step change; the last one
  /// has `finished`.
  Stream<InstallProgress> install() => _runFlow(null);

  /// Diagnoses, then runs only the steps that fix what is wrong (a missing
  /// or outdated agent is reinstalled).
  Stream<InstallProgress> repair() => _runFlow(InstallStepId.diagnose);

  /// Installs the bundled version over the one on the TV (`pm install -r`
  /// keeps its data and pairing). The same steps as [install], with the
  /// same checksum checks; the TV's build approval is left as it was.
  Stream<InstallProgress> update() => _runFlow(null, update: true);

  /// Reads the agent's state over ADB (and its API with the saved token).
  Future<AgentDiagnosis> diagnose({AgentManifest? bundled}) async {
    final r = await adb.shell(diagnoseCommand);
    final parts = r.stdout.split(RegExp(r'^---\s*$', multiLine: true));
    String at(int i) => i < parts.length ? parts[i] : '';
    bool listed(String s) =>
        s.split('\n').any((l) => l.trim() == 'package:$kAgentPackage');
    final problems = <AgentProblem>{};
    final installed = listed(at(0));
    if (!installed) {
      return const AgentDiagnosis(problems: {AgentProblem.notInstalled});
    }
    if (listed(at(1))) problems.add(AgentProblem.disabled);
    final running = at(2).trim().isNotEmpty;
    if (!running) problems.add(AgentProblem.notRunning);
    final versionName =
        RegExp(r'versionName=(\S+)').firstMatch(at(3))?.group(1);
    final versionCode = int.tryParse(
      RegExp(r'versionCode=(\d+)').firstMatch(at(3))?.group(1) ?? '',
    );
    if (bundled != null) {
      final older = bundled.versionCode > 0 && versionCode != null
          ? versionCode < bundled.versionCode
          : versionName != null && versionName != bundled.versionName;
      if (older) problems.add(AgentProblem.outdated);
    }
    AgentStatus? status;
    if (running) {
      final token = await tokens.read(tvId);
      if (token == null) {
        problems.add(AgentProblem.tokenMismatch);
      } else {
        try {
          status = await clientFor(token).status();
          if (status.selfAdb == SelfAdb.needsApproval) {
            problems.add(AgentProblem.selfAdbNeedsApproval);
          }
          if (status.needsPhoneGrant) problems.add(AgentProblem.missingGrant);
          if (status.mediaAccessMissing) {
            problems.add(AgentProblem.noMediaAccess);
          }
        } on AgentAuthException {
          problems.add(AgentProblem.tokenMismatch);
        } on AgentException {
          problems.add(AgentProblem.unreachable);
        }
      }
    }
    return AgentDiagnosis(
      problems: problems,
      installedVersion: versionName,
      installedVersionCode: versionCode,
      status: status,
    );
  }

  /// `pm uninstall`. The TV keeps working without the agent.
  Future<bool> uninstall() async {
    final r = await adb.shell(uninstallCommand);
    final ok = r.ok && r.stdout.contains('Success');
    if (ok) await tokens.delete(tvId);
    await _journal(
      'agentUninstall',
      before: 'installed',
      after: ok ? 'removed' : r.stdout.trim(),
      ok: ok,
    );
    return ok;
  }

  // ── flow engine ──

  Stream<InstallProgress> _runFlow(InstallStepId? first,
      {bool update = false}) {
    final op = update
        ? 'agentUpdate'
        : first == null
            ? 'agentInstall'
            : 'agentRepair';
    final out = StreamController<InstallProgress>();
    var steps = <InstallStep>[
      if (first != null)
        InstallStep(first)
      else
        for (final s in installSteps) InstallStep(s),
    ];
    AgentStatus? status;

    void emit({bool finished = false, bool ok = false, String? error}) {
      if (out.isClosed) return;
      out.add(
        InstallProgress(
          steps: List.unmodifiable(steps),
          finished: finished,
          ok: ok,
          error: error,
          status: status,
        ),
      );
    }

    void set(InstallStepId id, SetupStepState s, [String detail = '']) {
      steps = [
        for (final x in steps) x.id == id ? x.copyWith(s, detail) : x,
      ];
      emit();
    }

    Future<void> run() async {
      AgentBundle? bundle;
      String? token;
      try {
        bundle = await loadBundle();
      } on AgentBundleMissing {
        bundle = null;
      }
      var plan = installSteps;
      var fresh = first == null && !update;
      if (first == InstallStepId.diagnose) {
        set(InstallStepId.diagnose, SetupStepState.running);
        final d = await diagnose(bundled: bundle?.manifest);
        set(
          InstallStepId.diagnose,
          d.healthy ? SetupStepState.done : SetupStepState.warn,
          d.describe(),
        );
        plan = repairPlan(d);
        fresh = d.problems.contains(AgentProblem.notInstalled);
        steps = [
          ...steps,
          for (final s in plan) InstallStep(s),
        ];
        emit();
      }
      for (final id in plan) {
        set(id, SetupStepState.running);
        try {
          final r = await _step(
            id,
            bundle,
            token,
            freshInstall: fresh,
            onWaiting: (detail) => set(id, SetupStepState.waiting, detail),
            onStatus: (s) => status = s,
          );
          if (r.token != null) token = r.token;
          set(id, r.state, r.detail);
        } on _StepFailed catch (e) {
          set(id, SetupStepState.failed, e.detail);
          for (final s in steps) {
            if (s.state == SetupStepState.pending) {
              set(s.id, SetupStepState.skipped);
            }
          }
          await _journal(
            op,
            before: id.name,
            after: e.detail,
            ok: false,
          );
          emit(finished: true, error: '${id.name}: ${e.detail}');
          return;
        }
      }
      await _journal(
        op,
        before: '',
        after: status == null ? 'done' : 'v${status!.version}',
        ok: true,
      );
      emit(finished: true, ok: true);
    }

    run().catchError((Object e) {
      emit(finished: true, error: '$e');
    }).whenComplete(out.close);
    return out.stream;
  }

  /// Steps that fix [d]. Re-granting, re-reading the token and pushing
  /// the profile are harmless, so a repair always does them.
  static List<InstallStepId> repairPlan(AgentDiagnosis d) {
    final p = d.problems;
    final reinstall = p.contains(AgentProblem.notInstalled) ||
        p.contains(AgentProblem.outdated);
    final start = reinstall ||
        p.contains(AgentProblem.disabled) ||
        p.contains(AgentProblem.notRunning) ||
        p.contains(AgentProblem.unreachable);
    return [
      if (reinstall) ...[
        InstallStepId.verify,
        InstallStepId.push,
        InstallStepId.install,
      ],
      if (p.contains(AgentProblem.disabled)) InstallStepId.enable,
      InstallStepId.grant,
      if (start) InstallStepId.start,
      InstallStepId.token,
      InstallStepId.approve,
      InstallStepId.profile,
      InstallStepId.check,
    ];
  }

  Future<_StepResult> _step(
    InstallStepId id,
    AgentBundle? bundle,
    String? token, {
    required bool freshInstall,
    required void Function(String detail) onWaiting,
    required void Function(AgentStatus s) onStatus,
  }) async {
    AgentBundle need() {
      if (bundle == null) throw const _StepFailed(AgentBundleMissing.message);
      return bundle;
    }

    switch (id) {
      case InstallStepId.diagnose:
        return const _StepResult(SetupStepState.done);
      case InstallStepId.verify:
        return _verify(need());
      case InstallStepId.push:
        return _push(need());
      case InstallStepId.install:
        return _install();
      case InstallStepId.enable:
        final r = await adb.shell('pm enable $kAgentPackage');
        if (!r.ok) throw _StepFailed(r.stdout.trim());
        return const _StepResult(SetupStepState.done, 'Turned on');
      case InstallStepId.grant:
        return _grant();
      case InstallStepId.start:
        return _start(bundle?.manifest ?? _fallbackManifest);
      case InstallStepId.token:
        return _readToken();
      case InstallStepId.approve:
        return _approve(token, onWaiting, onStatus);
      case InstallStepId.profile:
        return _profile(token, approveBuild: freshInstall);
      case InstallStepId.check:
        return _check(token, bundle?.manifest, onStatus);
    }
  }

  static const _fallbackManifest = AgentManifest(versionName: '?', sha256: '');

  _StepResult _verify(AgentBundle b) {
    final m = b.manifest;
    if (m.pkg != kAgentPackage) {
      throw _StepFailed('unexpected package ${m.pkg}');
    }
    if (!_servicePattern.hasMatch(m.service)) {
      throw _StepFailed('bad service name ${m.service}');
    }
    if (m.sha256.isEmpty) throw const _StepFailed('manifest has no sha256');
    final actual = b.actualSha256;
    if (actual != m.sha256) {
      throw _StepFailed(
        'checksum mismatch (got ${actual.substring(0, 12)}…, '
        'expected ${m.sha256.substring(0, m.sha256.length.clamp(0, 12))}…)',
      );
    }
    return _StepResult(
      SetupStepState.done,
      'v${m.versionName} · ${_size(b.apk.length)} · checksum OK',
    );
  }

  static String _size(int bytes) => bytes >= 1024 * 1024
      ? '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB'
      : '${(bytes / 1024).round()} KB';

  /// Shell commands that write [apk] to [tmpApk] in base64 chunks.
  static List<String> pushCommands(Uint8List apk) => [
        'rm -f $tmpApk',
        for (var i = 0; i < apk.length; i += chunkBytes)
          "printf %s '${base64Encode(Uint8List.sublistView(
            apk,
            i,
            (i + chunkBytes).clamp(0, apk.length),
          ))}' | base64 -d >> $tmpApk",
      ];

  Future<_StepResult> _push(AgentBundle b) async {
    for (final c in pushCommands(b.apk)) {
      final r = await adb.shell(c);
      if (!r.ok) {
        await adb.shell('rm -f $tmpApk');
        throw _StepFailed('copy failed: ${r.stdout.trim()}');
      }
    }
    final sum = await adb.shell('sha256sum $tmpApk');
    final got = sum.stdout.trim().split(RegExp(r'\s+')).first.toLowerCase();
    if (got != b.manifest.sha256) {
      await adb.shell('rm -f $tmpApk');
      throw const _StepFailed('the copy on the TV is damaged; try again');
    }
    return _StepResult(SetupStepState.done, '${_size(b.apk.length)} copied');
  }

  Future<_StepResult> _install() async {
    final r = await adb.shell('pm install -r -g $tmpApk');
    await adb.shell('rm -f $tmpApk');
    final out = r.stdout.trim();
    if (out.contains('Success')) {
      return const _StepResult(SetupStepState.done, 'Installed');
    }
    if (out.contains('UPDATE_INCOMPATIBLE') || out.contains('SIGNATURES')) {
      throw const _StepFailed(
        'a TV Guard signed with a different key is installed; '
        'uninstall it first',
      );
    }
    throw _StepFailed(out.isEmpty ? 'pm install failed' : out);
  }

  /// Plain names for what each grant command gives.
  static String _grantName(String c) {
    if (c.startsWith('cmd notification allow_listener')) {
      return 'seeing what\'s playing';
    }
    final p = c.split(' ');
    return switch (p.length > 3 ? p[3].split('.').last : c) {
      'GET_USAGE_STATS' => 'usage access',
      'SYSTEM_ALERT_WINDOW' => 'overlay',
      'WRITE_SECURE_SETTINGS' => 'settings',
      'POST_NOTIFICATIONS' => 'notifications',
      final other => other,
    };
  }

  Future<_StepResult> _grant() async {
    final cmds = grantCommands(kAgentPackage);
    final failed = <String>[];
    for (final c in cmds) {
      final r = await adb.shell(c);
      final out = r.stdout;
      final bad = !r.ok ||
          out.contains('Exception') ||
          out.contains('Error') ||
          out.contains('Unknown command') ||
          out.contains('not allowed');
      if (bad) failed.add(_grantName(c));
    }
    // Without usage access the agent can't see the foreground app.
    if (failed.contains('usage access')) {
      throw const _StepFailed('the TV refused usage access');
    }
    if (failed.isNotEmpty) {
      return _StepResult(
        SetupStepState.warn,
        'Not granted: ${failed.join(', ')}. Everything else works.',
      );
    }
    return const _StepResult(
      SetupStepState.done,
      'Usage access, overlay, settings, notifications, seeing what\'s '
      'playing',
    );
  }

  Future<_StepResult> _start(AgentManifest m) async {
    final r = await adb.shell(startCommand(m));
    if (!r.ok || r.stdout.contains('Error')) {
      throw _StepFailed(r.stdout.trim().isEmpty
          ? 'could not start the service'
          : r.stdout.trim());
    }
    final until = _clock().add(startupTimeout);
    while (true) {
      final p = await adb.shell('pidof $kAgentPackage');
      if (p.stdout.trim().isNotEmpty) {
        return const _StepResult(SetupStepState.done, 'Running');
      }
      if (!_clock().isBefore(until)) {
        throw const _StepFailed('service did not stay running');
      }
      await _delay(pollEvery);
    }
  }

  Future<_StepResult> _readToken() async {
    final until = _clock().add(tokenTimeout);
    while (true) {
      final r = await adb.shell('cat $tokenPath');
      final t = r.stdout.trim();
      if (r.ok && _tokenPattern.hasMatch(t)) {
        await tokens.write(tvId, t);
        return _StepResult.withToken(SetupStepState.done, 'Paired', t);
      }
      if (!_clock().isBefore(until)) {
        throw const _StepFailed('TV Guard did not create its key');
      }
      await _delay(pollEvery);
    }
  }

  Future<String> _token(String? fromStep) async {
    final t = fromStep ?? await tokens.read(tvId);
    if (t == null) throw const _StepFailed('not paired yet');
    return t;
  }

  /// Waits for the API, then for self-ADB approval if the TV is asking.
  Future<_StepResult> _approve(
    String? stepToken,
    void Function(String detail) onWaiting,
    void Function(AgentStatus s) onStatus,
  ) async {
    final client = clientFor(await _token(stepToken));
    final up = _clock().add(startupTimeout);
    AgentStatus s;
    while (true) {
      try {
        s = await client.status();
        break;
      } on AgentAuthException {
        throw const _StepFailed('TV Guard rejected the key');
      } on AgentException catch (e) {
        if (!_clock().isBefore(up)) {
          throw _StepFailed('TV Guard is not answering (${e.message})');
        }
        await _delay(pollEvery);
      }
    }
    onStatus(s);
    if (s.selfAdb == SelfAdb.ok) {
      return const _StepResult(SetupStepState.done, 'Allowed');
    }
    if (s.selfAdb == SelfAdb.unavailable) {
      return const _StepResult(
        SetupStepState.warn,
        'ADB on the TV is off, so TV Guard runs in limited mode',
      );
    }
    onWaiting('Look at the TV and choose "Always allow"');
    final until = _clock().add(approvalTimeout);
    while (_clock().isBefore(until)) {
      await _delay(pollEvery * 2);
      try {
        s = await client.status();
        onStatus(s);
        if (s.selfAdb == SelfAdb.ok) {
          return const _StepResult(SetupStepState.done, 'Allowed');
        }
      } on AgentException {
        // Keep waiting.
      }
    }
    return const _StepResult(
      SetupStepState.warn,
      'Not allowed yet: TV Guard runs in limited mode. Use Repair to '
      'try again.',
    );
  }

  /// Cleanup/extras packages disabled right now, so the watchdog keeps
  /// them that way (and doesn't touch the ones the parent left on).
  Future<List<String>> keepDisabled() async {
    final DeviceProfile p;
    try {
      p = DeviceProfile.fromJson(profile);
    } catch (_) {
      return const [];
    }
    final snap = PackageSnapshot.parse(
      (await adb.shell(PackageSnapshot.command)).stdout,
    );
    return [
      for (final c in [...p.cleanup, ...p.extras])
        if (snap.state(c.pkg) == AppState.disabled) c.pkg,
    ];
  }

  /// Pushes the profile; on a first install also approves the TV's
  /// current build, so clean-up isn't held "pending approval".
  Future<_StepResult> _profile(
    String? stepToken, {
    required bool approveBuild,
  }) async {
    final client = clientFor(await _token(stepToken));
    final notes = <String>[];
    var state = SetupStepState.done;
    if (profile.isEmpty) {
      notes.add('No TV profile');
      state = SetupStepState.skipped;
    } else {
      try {
        final keep = await keepDisabled();
        await client.pushProfile(profile, keepDisabled: keep);
        notes.add('${profile['name'] ?? profile['id'] ?? 'profile'}');
      } on AgentException catch (e) {
        notes.add('Not sent: ${e.message}');
        state = SetupStepState.warn;
      }
    }
    if (approveBuild) {
      try {
        await client.approveBuild();
        notes.add('TV software approved');
        if (state == SetupStepState.skipped) state = SetupStepState.done;
      } on AgentException catch (e) {
        notes.add('Approve later: ${e.message}');
        state = SetupStepState.warn;
      }
    }
    return _StepResult(state, notes.join(' · '));
  }

  Future<_StepResult> _check(
    String? stepToken,
    AgentManifest? m,
    void Function(AgentStatus s) onStatus,
  ) async {
    final AgentStatus s;
    try {
      s = await clientFor(await _token(stepToken)).status();
    } on AgentException catch (e) {
      throw _StepFailed(e.message);
    }
    onStatus(s);
    final mismatch = m != null && s.version != m.versionName;
    return _StepResult(
      mismatch ? SetupStepState.warn : SetupStepState.done,
      'TV Guard v${s.version} · ${s.mode.name}'
      '${mismatch ? ' (expected v${m.versionName})' : ''}',
    );
  }

  Future<void> _journal(
    String op, {
    required String before,
    required String after,
    required bool ok,
  }) async {
    await journal?.add(
      JournalEntry(
        tvId: tvId,
        time: _clock(),
        op: op,
        target: kAgentPackage,
        before: before,
        after: after,
        ok: ok,
      ),
    );
  }
}

class _StepResult {
  final SetupStepState state;
  final String detail;
  final String? token;
  const _StepResult(this.state, [this.detail = '']) : token = null;
  const _StepResult.withToken(this.state, this.detail, this.token);
}
