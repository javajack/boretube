import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../agent/agent_models.dart';
import '../../ops/health.dart';
import '../../providers/agent_providers.dart';
import '../../providers/tv_providers.dart';
import '../../ui/components.dart';
import '../../ui/controls.dart';
import '../../ui/tokens.dart';
import 'common.dart';
import 'health_copy.dart';
import 'tv_guard_card.dart' show runAgentSetup;

Tone healthTone(HealthStatus s) => switch (s) {
      HealthStatus.ok => Tone.ok,
      HealthStatus.warn => Tone.warn,
      HealthStatus.fail => Tone.bad,
      HealthStatus.unknown => Tone.idle,
    };

IconData healthIcon(String id) => switch (id) {
      'adb' => Icons.wifi_rounded,
      'cleanup' => Icons.auto_awesome_rounded,
      'stockYouTube' => Icons.smart_display_rounded,
      'speech' => Icons.record_voice_over_rounded,
      'launcher' => Icons.home_rounded,
      'agent' => Icons.shield_rounded,
      _ when id.startsWith('agent.') => Icons.shield_outlined,
      _ => Icons.monitor_heart_rounded,
    };

HealthStatus _fromAgent(AgentHealthStatus s) => switch (s) {
      AgentHealthStatus.ok => HealthStatus.ok,
      AgentHealthStatus.warn => HealthStatus.warn,
      AgentHealthStatus.fail => HealthStatus.fail,
      AgentHealthStatus.unknown => HealthStatus.unknown,
    };

/// Always On's own checks (and an "is it running" line) as health rows.
List<HealthCheck> agentHealthChecks(AgentLink link) {
  if (!link.installed) return const [];
  final s = link.status;
  final up = link.up;
  return [
    HealthCheck(
      id: 'agent',
      title: 'Always On',
      status: up
          ? (s!.mode == AgentMode.normal ? HealthStatus.ok : HealthStatus.warn)
          : link.kind == AgentLinkKind.checking
              ? HealthStatus.unknown
              : HealthStatus.fail,
      detail: up
          ? switch (s!.mode) {
              AgentMode.normal => 'Running and enforcing',
              AgentMode.paused => 'Paused',
              AgentMode.safe => 'Safe mode: reporting only',
            }
          : link.kind == AgentLinkKind.checking
              ? 'Checking…'
              : 'Not answering',
    ),
    if (up)
      for (final h in s!.health)
        HealthCheck(
          id: 'agent.${h.id}',
          title: agentCheckTitle(h.id),
          status: _fromAgent(h.status),
          detail: h.detail.isEmpty ? 'Checked by Always On' : h.detail,
        ),
  ];
}

/// Phone checks (when Home mode works) plus Always On's, or null while
/// the phone's are still loading.
List<HealthCheck>? mergedHealth(WidgetRef ref) {
  final link = ref.watch(agentStatusProvider);
  final agent = agentHealthChecks(link);
  if (!ref.watch(activeHasAdbProvider)) return agent;
  final phone = ref.watch(healthProvider);
  if (phone.isLoading && !phone.hasValue) return null;
  return [...phone.valueOrNull ?? const [], ...agent];
}

/// Asks, then runs each check's fix and shows what changed.
Future<void> fixHealth(
  BuildContext context,
  WidgetRef ref,
  List<HealthCheck> targets,
) async {
  final names =
      targets.map((c) => '•  ${healthLook(c).title}').toList().join('\n');
  final ok = await confirmAction(
    context,
    title: targets.length == 1
        ? 'Fix ${healthLook(targets.first).title}?'
        : 'Fix ${targets.length} things?',
    message: 'This changes settings on the TV:\n\n$names\n\n'
        'Every change is kept in History and can be undone.',
    confirmLabel: 'Fix',
    icon: Icons.auto_fix_high_rounded,
  );
  if (!ok || !context.mounted) return;
  await runMaintenance(
    context,
    ref,
    title: targets.length == 1
        ? '${healthLook(targets.first).title} fixed'
        : 'All fixed',
    run: () async {
      for (final c in targets) {
        await c.fix!();
      }
    },
  );
  ref
    ..invalidate(healthProvider)
    ..invalidate(stockYouTubeStateProvider)
    ..invalidate(appsProvider);
}

/// TV health: every check in plain words, with a Fix where one is safe.
class HealthScreen extends ConsumerStatefulWidget {
  /// A check id to bring into view (from "needs you" on Better TV).
  final String? focus;

  const HealthScreen({super.key, this.focus});

  @override
  ConsumerState<HealthScreen> createState() => _HealthScreenState();
}

class _HealthScreenState extends ConsumerState<HealthScreen> {
  bool _technical = false;
  final _focusKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    if (widget.focus != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final c = _focusKey.currentContext;
        if (c != null && c.mounted) {
          Scrollable.ensureVisible(
            c,
            duration: Motion.of(context, Motion.slow),
            curve: Motion.settle,
            alignment: 0.3,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final bt = context.bt;
    final checks = mergedHealth(ref);
    final error = ref.watch(healthProvider).error;
    final ops = ref.watch(tvOpsProvider).valueOrNull;
    final readOnly =
        ops != null && ops.profile.readOnly && !ops.maintenanceUnlocked;
    final fixable = checks?.where((c) => c.fix != null).toList() ?? const [];
    return DetailPage(
      title: 'TV health',
      subtitle: 'What boretube checks on the TV, in plain words.',
      onRefresh: () async {
        ref.invalidate(healthProvider);
        await ref.read(agentStatusProvider.notifier).refresh();
      },
      children: [
        if (checks == null)
          const SkeletonCard(rows: 4)
        else if (error != null && checks.isEmpty)
          InfoCard(
            child: EmptyState(
              icon: Icons.wifi_off_rounded,
              tone: Tone.bad,
              title: 'Couldn\'t check the TV',
              message: 'Is it on and on this Wi-Fi? Then try again.',
              actionLabel: 'Try again',
              onAction: () {
                ref.invalidate(profileMatchProvider);
                ref.invalidate(healthProvider);
              },
            ),
          )
        else if (checks.isEmpty)
          const InfoCard(
            child: EmptyState(
              icon: Icons.monitor_heart_outlined,
              title: 'Nothing checked yet',
              message: 'Pull down to check the TV.',
            ),
          )
        else ...[
          if (fixable.length > 1) ...[
            PrimaryButton(
              key: const Key('health-fix-all'),
              label: 'Fix all (${fixable.length})',
              icon: Icons.auto_fix_high_rounded,
              onPressed: () => fixHealth(context, ref, fixable),
            ),
            const SizedBox(height: Gap.md),
          ],
          GroupCard(
            children: [
              for (final c in checks)
                StatusRow(
                  key: c.id == widget.focus ? _focusKey : Key('health-${c.id}'),
                  tone: healthTone(c.status),
                  icon: healthIcon(c.id),
                  title: healthLook(c).title,
                  detail: _technical ? c.detail : healthLook(c).detail,
                  detailLines: 3,
                  trailing: c.fix != null
                      ? _FixButton(
                          key: Key('health-fix-${c.id}'),
                          onPressed: () => fixHealth(context, ref, [c]),
                        )
                      : c.id == 'agent.mediaAccess' &&
                              c.status != HealthStatus.ok &&
                              c.status != HealthStatus.unknown &&
                              ref.watch(activeHasAdbProvider)
                          ? _FixButton(
                              key: const Key('health-repair-media'),
                              label: 'Repair',
                              width: 92,
                              onPressed: () =>
                                  runAgentSetup(context, ref, repair: true),
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
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              key: const Key('health-technical'),
              style: TextButton.styleFrom(foregroundColor: bt.muted),
              onPressed: () => setState(() => _technical = !_technical),
              child: Text(
                _technical ? 'Plain words' : 'Technical details',
              ),
            ),
          ),
        ],
        if (readOnly) ...[
          const SizedBox(height: Gap.sm),
          InfoCard(
            padding: const EdgeInsets.all(Gap.md),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 20, color: bt.skyInk),
                const SizedBox(width: Gap.md),
                Expanded(
                  child: Text(
                    'boretube hasn\'t been tested on this TV model, so fixes '
                    'are off. You can allow them in Settings › Advanced.',
                    style: text.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _FixButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String label;
  final double width;
  const _FixButton({
    super.key,
    required this.onPressed,
    this.label = 'Fix',
    this.width = 72,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
        width: width,
        child: PrimaryButton(
          label: label,
          kind: ButtonKind.ink,
          height: 48,
          onPressed: onPressed,
        ),
      );
}
