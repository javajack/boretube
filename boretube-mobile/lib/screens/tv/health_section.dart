import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ops/health.dart';
import '../../providers/tv_providers.dart';
import '../../ui/components.dart';
import '../../ui/tokens.dart';
import 'common.dart';

Tone healthTone(HealthStatus s) => switch (s) {
      HealthStatus.ok => Tone.ok,
      HealthStatus.warn => Tone.warn,
      HealthStatus.fail => Tone.bad,
      HealthStatus.unknown => Tone.idle,
    };

IconData healthIcon(String id) => switch (id) {
      'adb' => Icons.usb_rounded,
      'cleanup' => Icons.cleaning_services_rounded,
      'stockYouTube' => Icons.smart_display_rounded,
      'speech' => Icons.record_voice_over_rounded,
      'launcher' => Icons.home_rounded,
      _ => Icons.monitor_heart_rounded,
    };

class HealthSection extends ConsumerWidget {
  const HealthSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(activeHasAdbProvider)) {
      return const AdbRequired(what: 'TV health');
    }
    final health = ref.watch(healthProvider);
    return RefreshIndicator(
      onRefresh: () => ref.refresh(healthProvider.future),
      child: health.when(
        loading: () => ListView(
          padding: tvListPadding,
          children: const [SkeletonCard(rows: 1), SizedBox(height: Gap.md),
            SkeletonCard(rows: 4)],
        ),
        error: (e, _) => ListView(
          padding: tvListPadding,
          children: [
            InfoCard(
              child: EmptyState(
                icon: Icons.wifi_off_rounded,
                tone: Tone.bad,
                title: 'Couldn\'t check the TV',
                message: '$e',
                actionLabel: 'Try again',
                onAction: () {
                  ref.invalidate(profileMatchProvider);
                  ref.invalidate(healthProvider);
                },
              ),
            ),
          ],
        ),
        data: (checks) => HealthList(checks: checks),
      ),
    );
  }
}

class HealthList extends ConsumerWidget {
  final List<HealthCheck> checks;
  const HealthList({super.key, required this.checks});

  Future<void> _fix(
    BuildContext context,
    WidgetRef ref,
    List<HealthCheck> targets,
  ) async {
    final names = targets.map((c) => '• ${c.title}: ${c.detail}').join('\n');
    final ok = await confirmAction(
      context,
      title: targets.length == 1
          ? 'Fix ${targets.first.title}?'
          : 'Fix ${targets.length} things?',
      message: 'This changes settings on the TV:\n\n$names\n\n'
          'Every change is logged in Activity.',
      confirmLabel: 'Fix',
    );
    if (!ok || !context.mounted) return;
    await runMaintenance(
      context,
      ref,
      title: targets.length == 1 ? '${targets.first.title} fixed' : 'Fixed',
      run: () async {
        for (final c in targets) {
          await c.fix!();
        }
      },
    );
    ref.invalidate(healthProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final status = StatusColors.of(context);
    final issues = checks.where((c) => c.status != HealthStatus.ok).toList();
    final fixable = checks.where((c) => c.fix != null).toList();
    final ops = ref.watch(tvOpsProvider).valueOrNull;
    final readOnly =
        ops != null && ops.profile.readOnly && !ops.maintenanceUnlocked;
    final good = issues.isEmpty;
    return ListView(
      padding: tvListPadding,
      children: [
        InfoCard(
          key: const Key('health-summary'),
          padding: const EdgeInsets.all(Gap.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  IconBadge(
                    icon: good
                        ? Icons.verified_rounded
                        : Icons.report_gmailerrorred_rounded,
                    color: good ? status.ok : status.warn,
                    size: 48,
                  ),
                  const SizedBox(width: Gap.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          good
                              ? 'All good'
                              : issues.length == 1
                                  ? '1 thing needs attention'
                                  : '${issues.length} things need attention',
                          style: text.titleMedium,
                        ),
                        Text(
                          good
                              ? '${checks.length} checks passed'
                              : '${checks.length} checks · fixes ask first',
                          style: text.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (fixable.length > 1) ...[
                const SizedBox(height: Gap.lg),
                FilledButton.icon(
                  key: const Key('health-fix-all'),
                  onPressed: () => _fix(context, ref, fixable),
                  icon: const Icon(Icons.auto_fix_high_rounded),
                  label: Text('Fix all (${fixable.length})'),
                ),
              ],
            ],
          ),
        ),
        if (readOnly) ...[
          const SizedBox(height: Gap.md),
          const InfoCard(
            padding: EdgeInsets.all(Gap.md),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 20),
                SizedBox(width: Gap.md),
                Expanded(
                  child: Text(
                    'This TV uses a generic profile, so fixes are off. '
                    'Turn on maintenance in Settings to allow them.',
                  ),
                ),
              ],
            ),
          ),
        ],
        const SectionHeader('Checks'),
        if (checks.isEmpty)
          const InfoCard(
            child: EmptyState(
              icon: Icons.monitor_heart_outlined,
              title: 'No checks yet',
              message: 'Pull down to check the TV.',
            ),
          )
        else
          GroupCard(
            children: [
              for (final c in checks)
                StatusRow(
                  key: Key('health-${c.id}'),
                  tone: healthTone(c.status),
                  icon: healthIcon(c.id),
                  title: c.title,
                  detail: c.detail,
                  detailLines: 2,
                  trailing: c.fix != null
                      ? FilledButton.tonal(
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(56, 40),
                            padding: const EdgeInsets.symmetric(
                              horizontal: Gap.md,
                            ),
                          ),
                          onPressed: () => _fix(context, ref, [c]),
                          child: const Text('Fix'),
                        )
                      : Icon(
                          c.status == HealthStatus.ok
                              ? Icons.check_rounded
                              : Icons.remove_rounded,
                          color: healthTone(c.status).color(context),
                        ),
                ),
            ],
          ),
      ],
    );
  }
}
