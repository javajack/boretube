import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../ops/tv_ops.dart';
import '../../providers/now_playing.dart';
import '../../providers/providers.dart';
import '../../providers/settings_provider.dart';
import '../../providers/tv_providers.dart';
import '../../ui/components.dart';
import '../../ui/tokens.dart';
import 'common.dart';

class AppsSection extends ConsumerWidget {
  const AppsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(activeHasAdbProvider)) {
      return ListView(
        padding: tvListPadding,
        children: const [
          _WhitelistEntry(),
          SizedBox(height: Gap.md),
          _AdbAppsTip(),
        ],
      );
    }
    final apps = ref.watch(appsProvider);
    final ops = ref.watch(tvOpsProvider).valueOrNull;
    final canWrite =
        ops != null && (!ops.profile.readOnly || ops.maintenanceUnlocked);
    return RefreshIndicator(
      onRefresh: () async {
        ref
          ..invalidate(stockYouTubeStateProvider)
          ..invalidate(appsProvider);
        await ref.read(appsProvider.future);
      },
      child: ListView(
        padding: tvListPadding,
        children: [
          _YouTubeCard(canWrite: canWrite),
          const SizedBox(height: Gap.md),
          const _WhitelistEntry(),
          ...apps.when(
            loading: () => const [
              SectionHeader('Apps on the TV'),
              SkeletonCard(rows: 5),
            ],
            error: (e, _) => [
              const SectionHeader('Apps on the TV'),
              InfoCard(
                child: EmptyState(
                  icon: Icons.apps_outage_rounded,
                  tone: Tone.bad,
                  title: 'Couldn\'t read the app list',
                  message: '$e',
                  actionLabel: 'Try again',
                  onAction: () => ref.invalidate(appsProvider),
                ),
              ),
            ],
            data: (list) => _appList(context, ref, list, canWrite),
          ),
        ],
      ),
    );
  }

  List<Widget> _appList(
    BuildContext context,
    WidgetRef ref,
    List<TvApp> list,
    bool canWrite,
  ) {
    final shown = list.where((a) => a.state != AppState.absent).toList()
      ..sort((a, b) => appLabel(a.pkg).compareTo(appLabel(b.pkg)));
    return [
      SectionHeader('Apps on the TV · ${shown.length}'),
      if (!canWrite)
        const Padding(
          padding: EdgeInsets.only(bottom: Gap.md),
          child: InfoCard(
            padding: EdgeInsets.all(Gap.md),
            child: Text(
              'Generic profile: app changes are off. Turn on maintenance '
              'in Settings to allow them.',
            ),
          ),
        ),
      if (shown.isEmpty)
        const InfoCard(
          child: EmptyState(
            icon: Icons.apps_rounded,
            title: 'No apps found',
            message: 'Pull down to read the list again.',
          ),
        )
      else
        GroupCard(
          children: [
            for (final a in shown)
              _AppRow(app: a, canWrite: canWrite),
          ],
        ),
    ];
  }
}

class _AppRow extends ConsumerWidget {
  final TvApp app;
  final bool canWrite;

  const _AppRow({required this.app, required this.canWrite});

  Future<void> _toggle(BuildContext context, WidgetRef ref, bool on) async {
    final name = appLabel(app.pkg);
    final ok = await confirmAction(
      context,
      title: on ? 'Turn on $name?' : 'Turn off $name?',
      message: on
          ? '$name will show up on the TV again.'
          : '$name disappears from the TV and can\'t be opened. You can '
              'turn it back on here any time.',
      confirmLabel: on ? 'Turn on' : 'Turn off',
      destructive: !on,
      icon: on ? Icons.toggle_on_outlined : Icons.toggle_off_outlined,
    );
    if (!ok || !context.mounted) return;
    final ops = ref.read(tvOpsProvider).valueOrNull;
    if (ops == null) return;
    await runMaintenance(
      context,
      ref,
      title: on ? '$name turned on' : '$name turned off',
      run: () => ops.setAppEnabled(app.pkg, on),
    );
    ref.invalidate(appsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (tone, tag) = switch (app.state) {
      AppState.enabled => (Tone.ok, null),
      AppState.disabled => (Tone.warn, 'Off'),
      AppState.notInstalled => (Tone.idle, 'Removed'),
      AppState.absent => (Tone.idle, 'Missing'),
    };
    final Widget trailing;
    if (app.protected) {
      trailing = Tooltip(
        message: 'Protected — Boretube never changes this app',
        child: Icon(
          Icons.lock_rounded,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      );
    } else if (app.state == AppState.notInstalled) {
      trailing = const TagChip('Removed');
    } else {
      trailing = Switch(
        value: app.state == AppState.enabled,
        onChanged: canWrite ? (v) => _toggle(context, ref, v) : null,
      );
    }
    return StatusRow(
      tone: tone,
      icon: app.launchable ? Icons.apps_rounded : Icons.apps_outage_rounded,
      title: appLabel(app.pkg) + (tag != null ? ' · $tag' : ''),
      detail: app.pkg,
      trailing: trailing,
    );
  }
}

class _YouTubeCard extends ConsumerWidget {
  final bool canWrite;
  const _YouTubeCard({required this.canWrite});

  Future<void> _set(BuildContext context, WidgetRef ref, bool on) async {
    final ok = await confirmAction(
      context,
      title: on ? 'Bring back stock YouTube?' : 'Remove stock YouTube?',
      message: on
          ? 'This restores Google\'s YouTube app and turns YouTube Music '
              'back on. Health will stop flagging it.'
          : 'This removes Google\'s YouTube app for this TV user and also '
              'turns off YouTube Music. SmartTube keeps working. You can '
              'bring it back here.',
      confirmLabel: on ? 'Restore' : 'Remove',
      destructive: !on,
      icon: Icons.smart_display_outlined,
    );
    if (!ok || !context.mounted) return;
    final ops = ref.read(tvOpsProvider).valueOrNull;
    final tvId = ref.read(activeTvIdProvider);
    if (ops == null || tvId == null) return;
    await ref
        .read(appSettingsProvider.notifier)
        .setAllowStockYouTube(tvId, on);
    if (!context.mounted) return;
    await runMaintenance(
      context,
      ref,
      title: on ? 'Stock YouTube restored' : 'Stock YouTube removed',
      run: () => ops.stockYouTube(on),
    );
    ref
      ..invalidate(stockYouTubeStateProvider)
      ..invalidate(appsProvider)
      ..invalidate(healthProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(stockYouTubeStateProvider);
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return state.when(
      loading: () => const SkeletonCard(rows: 1),
      error: (_, __) => const SizedBox.shrink(),
      data: (s) {
        if (s == null) return const SizedBox.shrink();
        final installed = s == AppState.enabled || s == AppState.disabled;
        return InfoCard(
          key: const Key('youtube-card'),
          padding: const EdgeInsets.all(Gap.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconBadge(
                    icon: Icons.smart_display_rounded,
                    color: installed ? scheme.error : scheme.primary,
                    size: 44,
                  ),
                  const SizedBox(width: Gap.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Stock YouTube', style: text.titleMedium),
                        Text(
                          installed
                              ? 'Installed on the TV'
                              : 'Removed — SmartTube is used instead',
                          style: text.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: installed,
                    onChanged: canWrite ? (v) => _set(context, ref, v) : null,
                  ),
                ],
              ),
              const SizedBox(height: Gap.md),
              Text(
                'Switching this also turns YouTube Music on or off.',
                style: text.bodySmall,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _WhitelistEntry extends ConsumerWidget {
  const _WhitelistEntry();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(whitelistProvider).length;
    return InfoCard(
      padding: EdgeInsets.zero,
      onTap: () => context.push('/whitelist'),
      child: StatusRow(
        tone: Tone.accent,
        icon: Icons.checklist_rounded,
        title: 'Classic lock whitelist',
        detail: '$count allowed · add what\'s playing now',
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}

class _AdbAppsTip extends StatelessWidget {
  const _AdbAppsTip();

  @override
  Widget build(BuildContext context) {
    return InfoCard(
      child: Column(
        children: [
          const EmptyState(
            icon: Icons.lock_outline_rounded,
            tone: Tone.accent,
            title: 'See every app on the TV',
            message: 'Unlock with ADB to turn apps on or off and manage '
                'stock YouTube.',
          ),
          FilledButton.icon(
            onPressed: () => context.push('/adb-guide'),
            icon: const Icon(Icons.lock_open_rounded),
            label: const Text('Unlock with ADB'),
          ),
          const SizedBox(height: Gap.sm),
        ],
      ),
    );
  }
}
