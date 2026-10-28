import 'tv_ops.dart';

enum HealthStatus { ok, warn, fail, unknown }

/// One line of the TV Health screen. [fix] is null when there is nothing
/// safe to do automatically (or the profile is read-only).
class HealthCheck {
  final String id;
  final String title;
  final HealthStatus status;
  final String detail;
  final Future<void> Function()? fix;

  const HealthCheck({
    required this.id,
    required this.title,
    required this.status,
    required this.detail,
    this.fix,
  });

  @override
  String toString() => '$id: ${status.name} — $detail';
}

/// Computes the health checks for a TV. Only reads; fixes run when the UI
/// calls [HealthCheck.fix].
Future<List<HealthCheck>> computeHealth(
  TvOps ops, {
  bool allowStockYouTube = false,
  Set<String> extras = const {},
}) async {
  final canFix = !ops.profile.readOnly || ops.maintenanceUnlocked;
  final checks = <HealthCheck>[];

  Future<void> guarded(
    String id,
    String title,
    Future<HealthCheck> Function() f,
  ) async {
    try {
      checks.add(await f());
    } catch (e) {
      checks.add(
        HealthCheck(
          id: id,
          title: title,
          status: HealthStatus.unknown,
          detail: '$e',
        ),
      );
    }
  }

  await guarded('adb', 'ADB connection', () async {
    final r = await ops.adb.shell('echo ok');
    final ok = r.ok && r.stdout.trim() == 'ok';
    return HealthCheck(
      id: 'adb',
      title: 'ADB connection',
      status: ok ? HealthStatus.ok : HealthStatus.fail,
      detail: ok ? 'Connected' : 'Shell failed: $r',
    );
  });
  if (checks.last.status != HealthStatus.ok) return checks;

  if (ops.profile.cleanup.isNotEmpty || extras.isNotEmpty) {
    await guarded('cleanup', 'Bloat cleanup', () async {
      final s = await ops.cleanupStatus(extras: extras);
      final n = s.present.length;
      return HealthCheck(
        id: 'cleanup',
        title: 'Bloat cleanup',
        status: s.complete ? HealthStatus.ok : HealthStatus.warn,
        detail: '${s.disabled.length}/$n disabled'
            '${s.pending.isEmpty ? '' : ' (pending: ${s.pending.join(', ')})'}',
        fix: canFix && !s.complete
            ? () => ops.applyCleanup(extras: extras)
            : null,
      );
    });
  }

  if (ops.profile.stockYouTube != null) {
    await guarded('stockYouTube', 'Stock YouTube', () async {
      final st = await ops.stockYouTubeState();
      final installed = st == AppState.enabled || st == AppState.disabled;
      final bad = installed && !allowStockYouTube;
      return HealthCheck(
        id: 'stockYouTube',
        title: 'Stock YouTube',
        status: bad ? HealthStatus.warn : HealthStatus.ok,
        detail: installed
            ? (allowStockYouTube ? 'Installed (allowed)' : 'Installed')
            : 'Removed',
        fix: bad && canFix ? () => ops.stockYouTube(false) : null,
      );
    });
  }

  if (ops.profile.knownGood.containsKey(kTtsPackage)) {
    await guarded('speech', 'Speech services', () async {
      final d = await ops.speechDecision();
      return HealthCheck(
        id: 'speech',
        title: 'Speech services',
        status: d.atKnownGood
            ? HealthStatus.ok
            : (d.needed ? HealthStatus.fail : HealthStatus.warn),
        detail: '${d.reason} (${d.currentVersion ?? '?'})',
        fix: d.needed && canFix ? ops.speechRollback : null,
      );
    });
  }

  if (ops.profile.launcher != null) {
    await guarded('launcher', 'Home launcher', () async {
      final h = await ops.launcherHealth();
      final detail = h.homeIsLauncher
          ? 'Home opens the launcher'
          : 'Home resolves to ${h.homeComponent ?? 'nothing'}; helper '
              '${h.helperEnabled ? 'on' : 'off'}, accessibility '
              '${h.a11yEnabled ? 'on' : 'off'}';
      return HealthCheck(
        id: 'launcher',
        title: 'Home launcher',
        status: h.ok ? HealthStatus.ok : HealthStatus.fail,
        detail: detail,
        fix: !h.ok && canFix ? ops.fixLauncher : null,
      );
    });
  }

  return checks;
}
