import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/agent_providers.dart';
import '../../providers/providers.dart';
import '../../providers/security_providers.dart';
import '../../providers/settings_provider.dart';
import '../../providers/tv_providers.dart';
import '../../providers/ui_providers.dart';
import '../../tv/tv.dart';
import '../../tv/tv_store.dart';
import '../../ui/components.dart';
import '../../ui/controls.dart';
import '../../ui/format.dart';
import '../../ui/learn.dart';
import '../../ui/tokens.dart';
import '../../version.dart';
import '../../watch/always_on_watch.dart';
import '../lock_screen.dart';
import '../restore_screen.dart';
import '../shell_screen.dart';
import '../tv_address_dialog.dart';

/// Saves an edited TV; a temporary `ip:` id follows a changed address.
Future<void> saveEditedTv(TvStore store, Tv before, Tv after) async {
  if (before.id.startsWith('ip:') && after.ip != before.ip) {
    final wasActive = store.activeId == before.id;
    final moved = after.copyWith(id: 'ip:${after.ip}');
    await store.remove(before.id);
    await store.upsert(moved);
    if (wasActive) await store.setActive(moved.id);
    return;
  }
  await store.upsert(after);
}

/// Settings, as a plain grouped list: Your TVs · Look · Parent PIN ·
/// Notifications · Help. Everything technical (the only place that says
/// ADB, Cast or agent) lives on its own Advanced page.
class SettingsSection extends ConsumerWidget {
  const SettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tvs = ref.watch(savedTvsProvider);
    final active = ref.watch(activeTvProvider);
    final lock = ref.watch(appLockProvider);
    final bioAvailable =
        ref.watch(biometricAvailableProvider).valueOrNull ?? false;
    final bt = context.bt;

    return DetailPage(
      title: 'Settings',
      subtitle: 'Your TVs, this phone, and the fine print.',
      children: [
        const GroupHeading('Your TVs', first: true),
        RowList(
          children: [
            for (final t in tvs) _TvRow(tv: t, active: t.id == active?.id),
            ListRow(
              key: const Key('settings-add-tv'),
              icon: Icons.add_rounded,
              iconColor: bt.skyInk,
              title: 'Add a TV',
              onTap: () => context.push('/onboarding?add=1'),
            ),
          ],
        ),
        const SizedBox(height: Gap.related),
        RowList(
          children: [
            ListRow(
              key: const Key('settings-history'),
              title: 'History',
              subtitle: 'Every change to the TV, with before and after',
              onTap: () => context.push('/history'),
            ),
            ListRow(
              key: const Key('settings-restore'),
              title: 'Put the TV back the way it was',
              subtitle: 'Undo boretube\'s changes',
              onTap: () => context.push('/restore'),
            ),
          ],
        ),
        const GroupHeading('Look'),
        const _ThemeList(),
        const GroupHeading('Parent PIN'),
        RowList(
          children: [
            ListRow(
              key: const Key('settings-change-pin'),
              title: 'Change PIN',
              onTap: () => showChangePinSheet(context, ref),
            ),
            if (bioAvailable)
              SwitchLine(
                title: 'Unlock with fingerprint',
                value: lock.biometricEnabled,
                onChanged: (v) =>
                    ref.read(appLockProvider.notifier).setBiometricEnabled(v),
              ),
            ListRow(
              key: const Key('settings-lock-now'),
              title: 'Lock now',
              subtitle: 'It also locks after 5 minutes away',
              chevron: false,
              onTap: () => ref.read(appLockProvider.notifier).lockNow(),
            ),
          ],
        ),
        GroupHeading(
          'Notifications',
          // The ⓘ glyph lines up with the switches' trailing edge.
          trailing: Transform.translate(
            offset: Offset(Gap.f13, 0),
            child: InfoButton(
              title: 'Always On alerts',
              body: 'A note on this phone if Always On stops on a TV, and '
                  'again when it\'s back. The phone checks about every 15 '
                  'minutes on Wi-Fi and only tells you when something '
                  'changes, never more.\n\nWhile "Lock for a while" runs, a '
                  'quiet notification shows the lock is on and how long is '
                  'left. It goes away when the lock ends.',
            ),
          ),
        ),
        const NotificationsCard(),
        const GroupHeading('Help'),
        RowList(
          children: [
            ListRow(
              key: const Key('settings-help-always-on'),
              title: 'What is Always On?',
              onTap: () => showLearnSheet(context, LearnTerm.alwaysOn),
            ),
            ListRow(
              key: const Key('settings-help-home-mode'),
              title: 'What is Home mode?',
              onTap: () => showLearnSheet(context, LearnTerm.homeMode),
            ),
            ListRow(
              key: const Key('settings-help-guide'),
              title: 'Set up Home mode',
              subtitle: 'Step by step, with the TV menus',
              onTap: () => context.push('/adb-guide'),
            ),
            ListRow(
              key: const Key('settings-about'),
              title: 'About boretube',
              value: appVersion,
              onTap: () => showInfoSheet(
                context,
                title: 'boretube $appVersion',
                body: 'Android TV parental controls. Calmer TV, fewer '
                    'fights, no Shorts.',
              ),
            ),
          ],
        ),
        const SizedBox(height: Gap.section),
        RowList(
          edges: true,
          children: [
            ListRow(
              key: const Key('settings-advanced'),
              title: 'Advanced',
              subtitle: 'Connection, ADB key, snapshot, debug info',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const AdvancedSettingsPage(),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Look ──

/// Light is the brand and the default; Follow phone comes last.
class _ThemeList extends ConsumerWidget {
  const _ThemeList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(themePrefProvider);
    return RadioList<ThemePref>(
      key: const Key('settings-theme'),
      keyPrefix: 'theme',
      value: theme,
      onChanged: (p) => ref.read(themePrefProvider.notifier).set(p),
      options: const [
        RadioOption(ThemePref.light, 'Light'),
        RadioOption(
          ThemePref.bedtime,
          'Bedtime dark after sunset',
          detail: 'Dark from 7 pm to 7 am',
        ),
        RadioOption(ThemePref.dark, 'Always dark'),
        RadioOption(ThemePref.system, 'Follow phone'),
      ],
    );
  }
}

// ── Notifications ──

/// Always On alerts (opt-in) and a word on the lock's notification.
class NotificationsCard extends ConsumerWidget {
  const NotificationsCard({super.key});

  Future<void> _toggle(BuildContext context, WidgetRef ref, bool on) async {
    await ref.read(alertsPrefProvider.notifier).set(on);
    if (on) {
      final n = ref.read(alertNotifierProvider);
      if (await n.enabled() == false) await n.requestPermission();
      ref.invalidate(notificationsAllowedProvider);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final on = ref.watch(alertsPrefProvider) == true;
    final allowed = ref.watch(notificationsAllowedProvider).valueOrNull;
    final anyAlwaysOn = ref.watch(hasAgentProvider);
    final blocked = on && allowed == false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RowList(
          children: [
            ListRow(
              key: const Key('settings-alerts'),
              title: 'Always On alerts',
              subtitle: on && !blocked
                  ? 'Checked every 15 minutes on Wi-Fi'
                  : anyAlwaysOn
                      ? 'A note here if Always On stops on a TV'
                      : 'Once Always On is set up, a note if it stops',
              chevron: false,
              onTap: () => _toggle(context, ref, !on),
              trailing: Switch(
                key: const Key('settings-alerts-switch'),
                value: on,
                onChanged: (v) => _toggle(context, ref, v),
              ),
            ),
            const ListRow(
              key: Key('settings-lock-notice'),
              title: 'While "Lock for a while" runs',
              subtitle: 'A quiet notification shows the time left',
            ),
          ],
        ),
        if (blocked) ...[
          const SizedBox(height: Gap.f13),
          NoticeBanner(
            key: const Key('settings-alerts-blocked'),
            kind: BannerKind.paused,
            icon: Icons.notifications_off_rounded,
            title: 'This phone blocks boretube\'s alerts',
            message: 'Settings › Apps › Boretube 2 › Notifications.',
            actionLabel: 'Ask again',
            onAction: () async {
              await ref.read(alertNotifierProvider).requestPermission();
              ref.invalidate(notificationsAllowedProvider);
            },
          ),
        ],
      ],
    );
  }
}

// ── TVs ──

class _TvRow extends ConsumerWidget {
  final Tv tv;
  final bool active;

  const _TvRow({required this.tv, required this.active});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bt = context.bt;
    final detail = [
      if (tv.model.isNotEmpty) tv.model else tv.ip,
      if (tv.lastSeen != null) 'seen ${relativeTime(tv.lastSeen!)}',
    ].join(' · ');
    return ListRow(
      key: Key('settings-tv-${tv.id}'),
      icon: active ? Icons.tv_rounded : Icons.tv_outlined,
      iconColor: active ? bt.ink : bt.muted,
      title: tv.name,
      subtitle: detail,
      value: active ? 'In use' : null,
      valueColor: active ? Tone.ok.color(context) : null,
      onTap: () => showBtSheet<void>(
        context,
        builder: (_) => _TvSheet(tv: tv, active: active),
      ),
    );
  }
}

/// Switch to, rename or forget one saved TV.
class _TvSheet extends ConsumerWidget {
  final Tv tv;
  final bool active;

  const _TvSheet({required this.tv, required this.active});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bt = context.bt;
    final store = ref.read(tvStoreProvider);
    // The settings page stays mounted under the sheet: run follow-up
    // dialogs from there once the sheet has closed.
    final host = Navigator.of(context).context;
    void then(Future<void> Function(BuildContext host) action) {
      Navigator.pop(context);
      action(host);
    }

    return SheetScaffold(
      title: tv.name,
      lead: Text(
        [
          if (tv.model.isNotEmpty) '${tv.manufacturer} ${tv.model}'.trim(),
          tv.ip,
        ].join(' · '),
      ),
      children: [
        RowList(
          edges: true,
          children: [
            if (!active)
              ListRow(
                key: const Key('tv-sheet-use'),
                icon: Icons.check_rounded,
                title: 'Use this TV',
                chevron: false,
                onTap: () => then((_) => store.setActive(tv.id)),
              ),
            ListRow(
              key: const Key('tv-sheet-rename'),
              icon: Icons.edit_outlined,
              title: 'Rename',
              chevron: false,
              onTap: () => then((host) async {
                final name = await showTvNameDialog(host, tv: tv);
                if (name != null) {
                  await saveEditedTv(store, tv, tv.copyWith(name: name));
                }
              }),
            ),
            ListRow(
              key: const Key('tv-sheet-forget'),
              icon: Icons.delete_outline_rounded,
              iconColor: bt.berryFill,
              title: 'Forget this TV',
              titleWidget: Text(
                'Forget this TV',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall!
                    .copyWith(color: bt.berryFill),
              ),
              chevron: false,
              onTap: () => then((host) async {
                final ok = await confirmAction(
                  host,
                  title: 'Forget ${tv.name}?',
                  message: 'It disappears from this phone. Nothing changes '
                      'on the TV. You can find it again later.',
                  confirmLabel: 'Forget',
                  destructive: true,
                  icon: Icons.delete_outline_rounded,
                );
                if (ok) await store.remove(tv.id);
              }),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Advanced ──

/// Everything technical, on its own page: what the TV can do, the
/// connection, the ADB key, the baseline and debug info.
class AdvancedSettingsPage extends ConsumerWidget {
  const AdvancedSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activeTvProvider);
    final settings = ref.watch(appSettingsProvider);
    final caps = ref.watch(capabilityProvider);
    final match = ref.watch(profileMatchProvider).valueOrNull;
    final text = Theme.of(context).textTheme;
    return DetailPage(
      key: const Key('settings-advanced-body'),
      title: 'Advanced',
      subtitle: 'For helpers and the curious.',
      children: [
        if (active != null) ...[
          GroupHeading(
            'What this TV can do',
            first: true,
            trailing: caps.isLoading
                ? const Padding(
                    padding: EdgeInsets.all(Gap.f13),
                    child: SizedBox.square(
                      dimension: Sizes.iconSmall,
                      child: CircularProgressIndicator(
                        strokeWidth: Sizes.focus,
                      ),
                    ),
                  )
                : TextButton(
                    key: const Key('settings-recheck'),
                    onPressed: () =>
                        ref.read(capabilityProvider.notifier).probe(),
                    child: const Text('Re-check'),
                  ),
          ),
          RowList(
            children: [
              for (final c in TvCapability.values)
                StatusRow(
                  tone: active.can(c) ? Tone.ok : Tone.idle,
                  icon:
                      active.can(c) ? Icons.check_rounded : Icons.close_rounded,
                  title: capabilityTitle(c),
                  detail: !active.can(c) && caps.valueOrNull?.detail(c) != null
                      ? caps.valueOrNull!.detail(c)
                      : capabilityMeaning(c),
                ),
            ],
          ),
          if (active.capabilitiesCheckedAt != null)
            Padding(
              padding: const EdgeInsets.only(top: Gap.f8),
              child: Text(
                '${active.name} · checked '
                '${relativeTime(active.capabilitiesCheckedAt!)}'
                '${match == null ? '' : ' · ${match.profile.name}'}',
                style: text.bodySmall,
              ),
            ),
          if (match != null && match.profile.readOnly) ...[
            const SizedBox(height: Gap.related),
            RowList(
              edges: true,
              children: [
                ListRow(
                  key: const Key('settings-maintenance'),
                  title: 'Allow maintenance',
                  subtitle: 'Untested model: fixes stay off until you allow',
                  chevron: false,
                  trailing: Switch(
                    value: settings.maintenanceUnlocked.contains(active.id),
                    onChanged: (v) async {
                      if (v &&
                          !await confirmAction(
                            context,
                            title: 'Allow maintenance?',
                            message: 'boretube doesn\'t have a tested '
                                'profile for this TV. Fixes and app '
                                'changes will be allowed anyway. Each one '
                                'still asks first.',
                            confirmLabel: 'Allow',
                          )) {
                        return;
                      }
                      await ref
                          .read(appSettingsProvider.notifier)
                          .setMaintenanceUnlocked(active.id, v);
                    },
                  ),
                ),
              ],
            ),
          ],
        ],
        GroupHeading('Connection', first: active == null),
        RowList(
          children: [
            if (active != null)
              ListRow(
                key: const Key('settings-address'),
                title: 'Address and ports',
                value: active.ip,
                onTap: () async {
                  final edited =
                      await showTvAddressDialog(context, initial: active);
                  if (edited != null) {
                    await saveEditedTv(
                      ref.read(tvStoreProvider),
                      active,
                      edited,
                    );
                  }
                },
              ),
            ListRow(
              key: const Key('settings-poll'),
              title: 'Check the TV every',
              subtitle: 'Only while boretube is open',
              value: '${settings.pollSeconds} s',
              onTap: () => showBtSheet<void>(
                context,
                builder: (_) => const _PollSheet(),
              ),
            ),
          ],
        ),
        const GroupHeading('ADB key'),
        const _AdbKey(),
        const GroupHeading('Baseline snapshot'),
        const BaselineCard(),
        const GroupHeading('Debug info'),
        const _DebugInfo(),
      ],
    );
  }
}

class _PollSheet extends ConsumerWidget {
  const _PollSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seconds = ref.watch(appSettingsProvider).pollSeconds;
    return SheetScaffold(
      title: 'Check the TV every',
      lead: const Text('Only while boretube is open. Sooner uses a little '
          'more battery.'),
      children: [
        RadioList<int>(
          keyPrefix: 'poll',
          value: seconds,
          onChanged: (s) async {
            await ref.read(appSettingsProvider.notifier).setPollSeconds(s);
            if (context.mounted) Navigator.pop(context);
          },
          options: [
            for (final s in AppSettings.pollChoices)
              RadioOption(s, '$s seconds'),
          ],
        ),
      ],
    );
  }
}

/// The facts a helper asks for, copyable in one go. A tinted wash, not a
/// card.
class _DebugInfo extends ConsumerWidget {
  const _DebugInfo();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tv = ref.watch(activeTvProvider);
    final match = ref.watch(profileMatchProvider).valueOrNull;
    final agent = ref.watch(agentStatusProvider);
    final alerts = ref.watch(alertsPrefProvider);
    final prefs = ref.watch(sharedPrefsProvider);
    final lastRun = DateTime.tryParse(prefs.getString(kWatchLastRunKey) ?? '');
    final s = agent.status;
    final text = Theme.of(context).textTheme;
    final bt = context.bt;
    final lines = <(String, String)>[
      ('App', 'boretube $appVersion'),
      if (tv != null) ...[
        ('TV', tv.name),
        ('TV id', tv.id),
        ('Address', '${tv.ip} · cast ${tv.castPort} · dial ${tv.dialPort}'),
        if (tv.model.isNotEmpty) ('Model', '${tv.manufacturer} ${tv.model}'),
      ],
      if (match != null) ...[
        ('Profile', match.profile.id),
        (
          'Build',
          '${match.props.buildId}${match.buildTested ? '' : ' '
              '(untested)'}'
        ),
      ],
      (
        'Always On',
        switch (agent.kind) {
          AgentLinkKind.none => 'not set up',
          AgentLinkKind.checking => 'checking',
          AgentLinkKind.up =>
            s == null ? 'up' : 'v${s.version} · api ${s.api} · ${s.mode.name}',
          AgentLinkKind.authFailed => 'token rejected',
          AgentLinkKind.down => 'not answering',
        },
      ),
      if (s != null) ('Agent id', s.agentId),
      (
        'Alerts',
        '${alerts == null ? 'not asked' : alerts ? 'on' : 'off'}'
            '${lastRun == null ? '' : ' · last check '
                '${relativeTime(lastRun)}'}',
      ),
    ];
    String asText() => [for (final (k, v) in lines) '$k: $v'].join('\n');
    final mono = text.bodySmall!.copyWith(
      fontFamily: 'monospace',
      fontFamilyFallback: const ['Roboto'],
      color: bt.ink,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DecoratedBox(
          key: const Key('settings-debug'),
          decoration:
              BoxDecoration(color: bt.wash, borderRadius: Radii.control),
          child: Padding(
            padding: const EdgeInsets.all(Gap.f13),
            child: SelectionArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final (k, v) in lines)
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '$k  ',
                            style: TextStyle(color: bt.muted),
                          ),
                          TextSpan(text: v),
                        ],
                      ),
                      style: mono,
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: Gap.f13),
        PrimaryButton(
          key: const Key('settings-debug-copy'),
          kind: ButtonKind.outline,
          icon: Icons.copy_rounded,
          label: 'Copy debug info',
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: asText()));
            if (context.mounted) {
              showStatusSnack(context, 'Debug info copied');
            }
          },
        ),
      ],
    );
  }
}

/// This phone's ADB fingerprint and the reset.
class _AdbKey extends ConsumerWidget {
  const _AdbKey();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = ref.watch(adbKeyProvider);
    final text = Theme.of(context).textTheme;
    final bt = context.bt;
    return RowList(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: Gap.f13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('This phone\'s fingerprint', style: text.titleSmall),
              Text(
                'The TV shows the same code when it asks.',
                style: text.bodySmall,
              ),
              const SizedBox(height: Gap.f8),
              key.when(
                loading: () => const Skeleton(height: TypeSize.caption),
                error: (e, _) =>
                    Text('Key unavailable: $e', style: text.bodySmall),
                data: (k) => SelectableText(
                  adbFingerprint(k),
                  style: text.bodySmall!.copyWith(
                    fontFamily: 'monospace',
                    fontFamilyFallback: const ['Roboto'],
                    color: bt.ink,
                  ),
                ),
              ),
            ],
          ),
        ),
        ListRow(
          key: const Key('settings-adb-reset'),
          title: 'Reset key',
          titleWidget: Text(
            'Reset key',
            style: text.titleSmall!.copyWith(color: bt.berryFill),
          ),
          chevron: false,
          onTap: () async {
            final ok = await confirmAction(
              context,
              title: 'Reset ADB key?',
              message: 'Every TV will ask "Allow USB debugging?" again '
                  'before boretube can use ADB.',
              confirmLabel: 'Reset',
              destructive: true,
              icon: Icons.key_off_rounded,
            );
            if (!ok) return;
            await ref.read(adbIdentityProvider).reset();
            ref.invalidate(adbKeyProvider);
            if (context.mounted) showStatusSnack(context, 'New key made');
          },
        ),
      ],
    );
  }
}
