import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../agent/agent_client.dart';
import '../../ops/tv_ops.dart';
import '../../providers/agent_providers.dart';
import '../../providers/now_playing.dart';
import '../../providers/settings_provider.dart';
import '../../providers/tv_providers.dart';
import '../../ui/components.dart';
import '../../ui/controls.dart';
import '../../ui/learn.dart';
import '../../ui/tokens.dart';
import '../rules/rules_editor.dart' show AppAvatar;
import '../rules_tab.dart' show rulesProvider;
import 'common.dart';

const smartTubePackages = {
  'org.smarttube.stable',
  'org.smarttube.beta',
  'com.teamsmart.videomanager.tv',
};

bool _canWrite(TvOps? ops) =>
    ops != null && (!ops.profile.readOnly || ops.maintenanceUnlocked);

/// Whether SmartTube is on the TV (null while unknown).
bool? smartTubeInstalled(WidgetRef ref) {
  final apps = ref.watch(appsProvider).valueOrNull;
  if (apps == null) return null;
  return apps.any(
    (a) => smartTubePackages.contains(a.pkg) && a.state == AppState.enabled,
  );
}

/// Hides or brings back the TV's own YouTube (and YouTube Music).
Future<void> setStockYouTube(
  BuildContext context,
  WidgetRef ref, {
  required bool installed,
}) async {
  final ok = await confirmAction(
    context,
    title: installed
        ? 'Bring back the TV\'s YouTube?'
        : 'Hide the TV\'s own YouTube?',
    message: installed
        ? 'Google\'s YouTube app comes back with its Shorts, and YouTube '
            'Music is switched back on.'
        : 'Google\'s YouTube app (and YouTube Music) is removed for this TV '
            'user. SmartTube keeps working. One tap here brings it back.',
    confirmLabel: installed ? 'Bring it back' : 'Hide it',
    icon: Icons.smart_display_outlined,
  );
  if (!ok || !context.mounted) return;
  final ops = ref.read(tvOpsProvider).valueOrNull;
  final tvId = ref.read(activeTvIdProvider);
  if (ops == null || tvId == null) return;
  await ref
      .read(appSettingsProvider.notifier)
      .setAllowStockYouTube(tvId, installed);
  if (!context.mounted) return;
  await runMaintenance(
    context,
    ref,
    title: installed ? 'YouTube is back' : 'Shorts are gone',
    run: () => ops.stockYouTube(installed),
  );
  ref
    ..invalidate(stockYouTubeStateProvider)
    ..invalidate(appsProvider)
    ..invalidate(healthProvider);
}

/// Better TV › YouTube without Shorts.
class YouTubeScreen extends ConsumerWidget {
  const YouTubeScreen({super.key});

  Future<void> _letStay(BuildContext context, WidgetRef ref, bool v) async {
    final c = ref.read(agentClientProvider);
    if (c == null) return;
    Future<void> send(AgentRules base) => c.putRules(
          base.copyWith(
            stockYouTubeAllowed: v,
            updatedBy: 'Parent phone',
            updatedAt: DateTime.now().toUtc().toIso8601String(),
          ),
        );
    try {
      final current = await c.rules();
      try {
        await send(current);
      } on AgentConflict catch (e) {
        // Someone saved in between: apply this one switch on top.
        await send(e.current);
      }
      ref.invalidate(rulesProvider);
      if (context.mounted) showStatusSnack(context, 'Saved to the TV ✓');
    } on AgentException catch (e) {
      if (context.mounted) {
        showStatusSnack(context, 'Not saved: ${e.message}', ok: false);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final bt = context.bt;
    final state = ref.watch(stockYouTubeStateProvider).valueOrNull;
    final ops = ref.watch(tvOpsProvider).valueOrNull;
    final canWrite = _canWrite(ops);
    final smart = smartTubeInstalled(ref);
    final installed = state == AppState.enabled || state == AppState.disabled;
    final on = state != null && !installed;
    final alwaysOn = ref.watch(hasAgentProvider);
    final rules = alwaysOn ? ref.watch(rulesProvider).valueOrNull : null;
    return DetailPage(
      title: 'YouTube without Shorts',
      titleTrailing: const InfoDot(LearnTerm.noShorts),
      subtitle: 'Kids keep YouTube. The endless Shorts go.',
      onRefresh: () async {
        ref
          ..invalidate(stockYouTubeStateProvider)
          ..invalidate(appsProvider);
        await ref.read(appsProvider.future);
      },
      children: [
        Row(
          key: const Key('youtube-card'),
          children: [
            IconTile(
              icon: on ? Icons.check_rounded : Icons.smart_display_rounded,
              color: on ? bt.mintInk : bt.sunInk,
              size: Sizes.row,
            ),
            const SizedBox(width: Gap.inside),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    state == null ? 'Checking…' : (on ? 'On' : 'Not yet'),
                    style: Fonts.bricolage(TypeSize.title, color: bt.ink),
                  ),
                  Text(
                    on
                        ? 'No Shorts on this TV'
                        : 'The TV\'s own YouTube still shows Shorts',
                    style: text.bodyMedium!.copyWith(color: bt.muted),
                  ),
                ],
              ),
            ),
          ],
        ),
        const GroupHeading('Two steps'),
        RowList(
          children: [
            ListRow(
              key: const Key('youtube-step-smarttube'),
              leading: _StepNumber(1, done: smart == true),
              title: 'Put SmartTube on the TV',
              subtitle: smart == true
                  ? 'It\'s on the TV. Nice.'
                  : smart == null
                      ? 'A free YouTube app without Shorts'
                      : 'Not on the TV yet. About 5 minutes',
              chevron: false,
              trailing: TextButton(
                key: const Key('youtube-guide'),
                onPressed: () => showBtSheet<void>(
                  context,
                  builder: (_) => const SmartTubeGuide(),
                ),
                child: Text(smart == true ? 'Guide' : 'Show me'),
              ),
            ),
            SwitchLine(
              key: const Key('youtube-stock-toggle'),
              leading: _StepNumber(2, done: on),
              title: 'Hide the TV\'s own YouTube',
              subtitle: state == null
                  ? 'Checking the TV…'
                  : on
                      ? 'Hidden. YouTube Music is off too'
                      : smart == false
                          ? 'Do step 1 first'
                          : 'Also switches off YouTube Music',
              value: on,
              onChanged: state == null || !canWrite
                  ? null
                  : (v) => setStockYouTube(context, ref, installed: !v),
            ),
          ],
        ),
        if (alwaysOn && rules != null) ...[
          const GroupHeading('With Always On'),
          RowList(
            children: [
              SwitchLine(
                key: const Key('rules-stock-youtube'),
                leading: Icon(
                  Icons.shield_rounded,
                  size: Sizes.icon,
                  color: Tone.ok.color(context),
                ),
                title: 'Let stock YouTube stay',
                subtitle: rules.stockYouTubeAllowed
                    ? 'Always On leaves it alone'
                    : 'Hidden again if a TV update brings it back',
                value: rules.stockYouTubeAllowed,
                onChanged: (v) => _letStay(context, ref, v),
              ),
            ],
          ),
        ],
        if (!canWrite && ops != null) ...[
          const SizedBox(height: Gap.related),
          Text(
            'Changes are off on this TV model. Allow them in Settings › '
            'Advanced.',
            style: text.bodySmall,
          ),
        ],
      ],
    );
  }
}

/// A step number in a 24 px chip (a check once done), in the row's
/// icon column.
class _StepNumber extends StatelessWidget {
  final int n;
  final bool done;
  const _StepNumber(this.n, {required this.done});

  @override
  Widget build(BuildContext context) {
    final bt = context.bt;
    return AnimatedContainer(
      duration: Motion.of(context, Motion.flip),
      width: Sizes.iconControl,
      height: Sizes.iconControl,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: done ? bt.mint : bt.wash,
        borderRadius: Radii.chip,
      ),
      child: done
          ? const Icon(
              Icons.check_rounded,
              size: Sizes.iconSmall,
              color: Color(0xFF06392A),
            )
          : Text(
              '$n',
              style: Fonts.bricolage(
                TypeSize.caption,
                height: TypeSize.tightLeading,
                color: bt.ink,
              ),
            ),
    );
  }
}

/// How to get SmartTube onto the TV, safely.
class SmartTubeGuide extends StatelessWidget {
  const SmartTubeGuide({super.key});

  @override
  Widget build(BuildContext context) {
    final bt = context.bt;
    const steps = [
      (
        'On the TV, install "Downloader" by AFTVnews',
        'It\'s free, in the Play Store.',
      ),
      (
        'In Downloader, type smarttubeapp.github.io',
        'Exactly this address. Choose "Stable".',
      ),
      (
        'Tap Install when the TV asks',
        'Allow Downloader to install apps if it asks first.',
      ),
      (
        'Come back and hide the TV\'s own YouTube',
        'Shorts gone. You can undo it any time.',
      ),
    ];
    return SheetScaffold(
      key: const Key('smarttube-guide'),
      title: 'Put SmartTube on the TV',
      lead: const Text('About 5 minutes, with the TV remote.'),
      children: [
        const NoticeBanner(
          key: Key('smarttube-warning'),
          kind: BannerKind.problem,
          icon: Icons.gpp_maybe_rounded,
          title: 'Only from smarttubeapp.github.io',
          message: 'Copies elsewhere can hide ads or malware. boretube never '
              'installs it for you.',
        ),
        const SizedBox(height: Gap.inside),
        RowList(
          children: [
            for (var i = 0; i < steps.length; i++)
              ListRow(
                leading: Container(
                  width: Sizes.iconControl,
                  height: Sizes.iconControl,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: bt.coralTint,
                    borderRadius: Radii.chip,
                  ),
                  child: Text(
                    '${i + 1}',
                    style: Fonts.bricolage(
                      TypeSize.caption,
                      height: TypeSize.tightLeading,
                      color: bt.coralInk,
                    ),
                  ),
                ),
                title: steps[i].$1,
                subtitle: steps[i].$2,
                subtitleLines: 2,
                chevron: false,
              ),
          ],
        ),
        const SizedBox(height: Gap.related),
        PrimaryButton(
          label: 'Got it',
          kind: ButtonKind.ink,
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }
}

/// Better TV › Apps on your TV: turn apps on or off.
class AppsScreen extends ConsumerWidget {
  const AppsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final apps = ref.watch(appsProvider);
    final ops = ref.watch(tvOpsProvider).valueOrNull;
    final canWrite = _canWrite(ops);
    final text = Theme.of(context).textTheme;
    return DetailPage(
      title: 'Apps on your TV',
      subtitle: 'Switch one off and it leaves the TV, until you say.',
      onRefresh: () async {
        ref.invalidate(appsProvider);
        await ref.read(appsProvider.future);
      },
      children: [
        ...apps.when(
          loading: () => const [SkeletonCard(rows: 6)],
          error: (e, _) => [
            EmptyState(
              icon: Icons.apps_outage_rounded,
              tone: Tone.bad,
              title: 'Couldn\'t read the app list',
              message: 'Is the TV on and on this Wi-Fi? Then try again.',
              actionLabel: 'Try again',
              onAction: () => ref.invalidate(appsProvider),
            ),
          ],
          data: (list) {
            final shown = list
                .where((a) => a.state != AppState.absent && a.launchable)
                .toList()
              ..sort((a, b) => appLabel(a.pkg).compareTo(appLabel(b.pkg)));
            final hidden = list
                .where(
                  (a) =>
                      a.state != AppState.absent &&
                      !a.launchable &&
                      a.state != AppState.enabled,
                )
                .toList()
              ..sort((a, b) => appLabel(a.pkg).compareTo(appLabel(b.pkg)));
            return [
              if (!canWrite)
                Text(
                  'A list only: allow changes in Settings › Advanced.',
                  style: text.bodySmall,
                ),
              if (shown.isEmpty && hidden.isEmpty)
                const EmptyState(
                  icon: Icons.apps_rounded,
                  title: 'No apps found',
                  message: 'Pull down to read the list again.',
                )
              else ...[
                GroupHeading(
                  'On the home screen · ${shown.length}',
                  first: true,
                ),
                RowList(
                  children: [
                    for (final a in shown) _AppRow(app: a, canWrite: canWrite),
                  ],
                ),
                if (hidden.isNotEmpty) ...[
                  GroupHeading('Switched off · ${hidden.length}'),
                  RowList(
                    children: [
                      for (final a in hidden)
                        _AppRow(app: a, canWrite: canWrite),
                    ],
                  ),
                ],
              ],
            ];
          },
        ),
      ],
    );
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
      title: on ? 'Switch $name back on?' : 'Switch $name off?',
      message: on
          ? '$name shows up on the TV again.'
          : '$name disappears from the TV and can\'t be opened. Switch it '
              'back on here any time.',
      confirmLabel: on ? 'Switch on' : 'Switch off',
      destructive: !on,
      icon: on ? Icons.toggle_on_outlined : Icons.toggle_off_outlined,
    );
    if (!ok || !context.mounted) return;
    final ops = ref.read(tvOpsProvider).valueOrNull;
    if (ops == null) return;
    await runMaintenance(
      context,
      ref,
      title: on ? '$name is back' : '$name switched off',
      run: () => ops.setAppEnabled(app.pkg, on),
    );
    ref.invalidate(appsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bt = context.bt;
    final text = Theme.of(context).textTheme;
    final name = appLabel(app.pkg);
    final Widget trailing;
    if (app.protected) {
      trailing = Tooltip(
        message: 'The TV needs this one, so boretube never changes it',
        child: Icon(Icons.lock_rounded, size: Sizes.icon, color: bt.faint),
      );
    } else if (app.state == AppState.notInstalled) {
      trailing = const TagChip('Removed');
    } else {
      trailing = Switch(
        value: app.state == AppState.enabled,
        onChanged: canWrite ? (v) => _toggle(context, ref, v) : null,
      );
    }
    return ConstrainedBox(
      key: Key('app-${app.pkg}'),
      constraints: const BoxConstraints(minHeight: Sizes.row),
      child: Row(
        children: [
          Opacity(
            opacity: app.state == AppState.enabled ? 1 : 0.5,
            child: AppAvatar(pkg: app.pkg, size: Sizes.tile),
          ),
          const SizedBox(width: Gap.inside),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: text.titleSmall),
                Text(
                  app.protected
                      ? 'The TV needs this'
                      : switch (app.state) {
                          AppState.enabled => 'On',
                          AppState.disabled => 'Switched off',
                          AppState.notInstalled => 'Removed for this TV user',
                          AppState.absent => 'Not on this TV',
                        },
                  style: text.bodySmall,
                ),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}
