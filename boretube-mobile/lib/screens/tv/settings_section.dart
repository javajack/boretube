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

const _listPadding = EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.xxl);

/// Settings: your TVs, look, parent PIN, notifications, then everything
/// technical under Advanced (the only place that says ADB, Cast or agent).
class SettingsSection extends ConsumerStatefulWidget {
  const SettingsSection({super.key});

  @override
  ConsumerState<SettingsSection> createState() => _SettingsSectionState();
}

class _SettingsSectionState extends ConsumerState<SettingsSection> {
  bool _advanced = false;

  @override
  Widget build(BuildContext context) {
    final tvs = ref.watch(savedTvsProvider);
    final active = ref.watch(activeTvProvider);
    final lock = ref.watch(appLockProvider);
    final bioAvailable =
        ref.watch(biometricAvailableProvider).valueOrNull ?? false;
    final bt = context.bt;
    final chevron = Icon(Icons.chevron_right_rounded, color: bt.faint);

    return ListView(
      key: const Key('settings-list'),
      padding: _listPadding,
      children: [
        const _Header(),
        SectionHeader(
          'Your TVs',
          padding: const EdgeInsets.fromLTRB(Gap.xs, Gap.md, Gap.xs, Gap.sm),
        ),
        GroupCard(
          children: [
            for (final t in tvs) _TvRow(tv: t, active: t.id == active?.id),
            StatusRow(
              key: const Key('settings-add-tv'),
              tone: Tone.info,
              icon: Icons.add_rounded,
              title: 'Add a TV',
              detail: 'Find another TV on this Wi-Fi',
              trailing: chevron,
              onTap: () => context.push('/onboarding?add=1'),
            ),
          ],
        ),
        const SectionHeader('Look'),
        const _LookCard(),
        const SectionHeader('Parent PIN'),
        GroupCard(
          children: [
            StatusRow(
              tone: Tone.accent,
              icon: Icons.pin_rounded,
              title: 'Change PIN',
              trailing: chevron,
              onTap: () => showChangePinSheet(context, ref),
            ),
            if (bioAvailable)
              StatusRow(
                tone: Tone.accent,
                icon: Icons.fingerprint_rounded,
                title: 'Unlock with fingerprint',
                trailing: Switch(
                  value: lock.biometricEnabled,
                  onChanged: (v) =>
                      ref.read(appLockProvider.notifier).setBiometricEnabled(v),
                ),
              ),
            StatusRow(
              tone: Tone.accent,
              icon: Icons.lock_rounded,
              title: 'Lock now',
              detail: 'Also locks after 5 minutes in the background',
              detailLines: 2,
              onTap: () => ref.read(appLockProvider.notifier).lockNow(),
            ),
          ],
        ),
        const SectionHeader('Notifications'),
        const NotificationsCard(),
        const SectionHeader('Your TV'),
        GroupCard(
          children: [
            StatusRow(
              key: const Key('settings-restore'),
              tone: Tone.info,
              icon: Icons.settings_backup_restore_rounded,
              title: 'Put the TV back the way it was',
              detail: 'Undo boretube\'s changes, or go back to how the TV '
                  'came',
              detailLines: 2,
              trailing: chevron,
              onTap: () => context.push('/restore'),
            ),
            StatusRow(
              key: const Key('settings-history'),
              tone: Tone.info,
              icon: Icons.history_rounded,
              title: 'History',
              detail: 'Every change to the TV, with before and after',
              detailLines: 2,
              trailing: chevron,
              onTap: () => context.push('/history'),
            ),
          ],
        ),
        const SizedBox(height: Gap.xl),
        _AdvancedToggle(
          open: _advanced,
          onTap: () => setState(() => _advanced = !_advanced),
        ),
        AnimatedSize(
          duration: Motion.of(context, Motion.medium),
          curve: Motion.settle,
          alignment: Alignment.topCenter,
          child: _advanced
              ? _AdvancedBody(active: active)
              : const SizedBox(width: double.infinity),
        ),
        const SectionHeader('About and help'),
        const _AboutCard(),
      ],
    );
  }
}

// ── Header ──

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final canPop = Navigator.maybeOf(context)?.canPop() ?? false;
    return Padding(
      padding: const EdgeInsets.only(top: Gap.sm, bottom: Gap.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (canPop)
            Transform.translate(
              offset: const Offset(-12, 0),
              child: IconButton(
                key: const Key('settings-back'),
                tooltip: 'Back',
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
            )
          else
            const SizedBox(height: Gap.lg),
          Semantics(
            header: true,
            child: Text('Settings', style: text.headlineLarge),
          ),
          const SizedBox(height: 2),
          Text(
            'Your TVs, this phone, and the fine print.',
            style: text.bodyMedium,
          ),
        ],
      ),
    );
  }
}

// ── Look ──

class _LookCard extends ConsumerWidget {
  const _LookCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(themePrefProvider);
    final shown = theme == ThemePref.bedtime ? ThemePref.system : theme;
    void set(ThemePref p) => ref.read(themePrefProvider.notifier).set(p);
    return InfoCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.lg, Gap.lg, Gap.md),
            child: Row(
              key: const Key('settings-theme'),
              children: [
                for (final (p, label) in const [
                  (ThemePref.system, 'Like phone'),
                  (ThemePref.light, 'Light'),
                  (ThemePref.dark, 'Dark'),
                ]) ...[
                  if (p != ThemePref.system) const SizedBox(width: Gap.sm),
                  Expanded(
                    child: _ThemeTile(
                      key: Key('theme-${p.name}'),
                      pref: p,
                      label: label,
                      selected: shown == p,
                      onTap: () => set(p),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Divider(indent: Gap.lg, endIndent: Gap.lg),
          StatusRow(
            key: const Key('settings-bedtime-dark'),
            tone: Tone.warn,
            icon: Icons.bedtime_rounded,
            title: 'Bedtime dark after sunset',
            detail: 'Dark from 7 pm to 7 am, easy on sleepy eyes',
            detailLines: 2,
            onTap: () => set(
              theme == ThemePref.bedtime ? ThemePref.system : ThemePref.bedtime,
            ),
            trailing: Switch(
              value: theme == ThemePref.bedtime,
              onChanged: (v) => set(v ? ThemePref.bedtime : ThemePref.system),
            ),
          ),
        ],
      ),
    );
  }
}

/// A tiny picture of the app in that theme, with its name under it.
class _ThemeTile extends StatelessWidget {
  final ThemePref pref;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeTile({
    super.key,
    required this.pref,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  Widget _mini(BtColors c) => Container(
        color: c.canvas,
        padding: const EdgeInsets.all(6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 6,
              width: 22,
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: 0.6,
                child: Container(
                  decoration: BoxDecoration(
                    color: c.ink,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: c.border),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Container(
              height: 8,
              decoration: BoxDecoration(
                color: c.coralFill,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final bt = context.bt;
    final text = Theme.of(context).textTheme;
    final preview = switch (pref) {
      ThemePref.light => _mini(BtColors.light),
      ThemePref.dark => _mini(BtColors.dark),
      _ => Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: _mini(BtColors.light)),
            Expanded(child: _mini(BtColors.dark)),
          ],
        ),
    };
    return Semantics(
      button: true,
      selected: selected,
      label: '$label theme',
      excludeSemantics: true,
      child: InkWell(
        borderRadius: Radii.tile,
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Column(
          children: [
            AnimatedContainer(
              duration: Motion.of(context, Motion.fast),
              curve: Motion.settle,
              height: 64,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                borderRadius: Radii.tile,
                border: Border.all(
                  color: selected ? bt.coral : bt.border,
                  width: 2,
                ),
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.all(
                  Radius.circular(Radii.tileR - 4),
                ),
                child: preview,
              ),
            ),
            const SizedBox(height: Gap.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (selected) ...[
                  Icon(Icons.check_rounded, size: 16, color: bt.coralInk),
                  const SizedBox(width: 2),
                ],
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.labelLarge!.copyWith(
                      fontSize: 14,
                      color: selected ? bt.coralInk : bt.ink,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
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
    final text = Theme.of(context).textTheme;
    final bt = context.bt;
    final blocked = on && allowed == false;
    return GroupCard(
      children: [
        StatusRow(
          key: const Key('settings-alerts'),
          tone: Tone.ok,
          icon: Icons.notifications_active_rounded,
          title: 'Always On alerts',
          detail: anyAlwaysOn || on
              ? 'A note on this phone if Always On stops on a TV, and '
                  'again when it\'s back.'
              : 'Once Always On is set up, a note on this phone if it '
                  'ever stops.',
          detailLines: 3,
          onTap: () => _toggle(context, ref, !on),
          trailing: Switch(
            key: const Key('settings-alerts-switch'),
            value: on,
            onChanged: (v) => _toggle(context, ref, v),
          ),
        ),
        if (blocked)
          Padding(
            key: const Key('settings-alerts-blocked'),
            padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, Gap.lg),
            child: Container(
              padding: const EdgeInsets.all(Gap.md),
              decoration: BoxDecoration(
                color: bt.sunTint,
                borderRadius: Radii.tile,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.notifications_off_rounded,
                        size: 20,
                        color: bt.sunInk,
                      ),
                      const SizedBox(width: Gap.md),
                      Expanded(
                        child: Text(
                          'This phone blocks notifications from boretube, '
                          'so alerts can\'t reach you. Turn them on in '
                          'Settings › Apps › Boretube 2 › Notifications.',
                          style: text.bodyMedium!.copyWith(color: bt.ink),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Gap.sm),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      key: const Key('settings-alerts-ask'),
                      onPressed: () async {
                        await ref
                            .read(alertNotifierProvider)
                            .requestPermission();
                        ref.invalidate(notificationsAllowedProvider);
                      },
                      child: const Text('Ask again'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (on && !blocked)
          Padding(
            padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, Gap.md),
            child: Row(
              children: [
                Icon(Icons.schedule_rounded, size: 16, color: bt.muted),
                const SizedBox(width: Gap.sm),
                Expanded(
                  child: Text(
                    'Checked about every 15 minutes on Wi-Fi. Only when '
                    'something changes, never more.',
                    style: text.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        const StatusRow(
          tone: Tone.info,
          icon: Icons.lock_clock_rounded,
          title: 'While "Lock for a while" runs',
          detail: 'A quiet notification shows the lock is on and how long '
              'is left. It goes away when the lock ends.',
          detailLines: 3,
        ),
      ],
    );
  }
}

// ── Advanced ──

class _AdvancedToggle extends StatelessWidget {
  final bool open;
  final VoidCallback onTap;

  const _AdvancedToggle({required this.open, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final bt = context.bt;
    final text = Theme.of(context).textTheme;
    return Semantics(
      expanded: open,
      child: InfoCard(
        key: const Key('settings-advanced'),
        padding: EdgeInsets.zero,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Gap.lg,
            vertical: Gap.md,
          ),
          child: Row(
            children: [
              IconBadge(
                icon: Icons.developer_board_rounded,
                color: bt.muted,
                size: 36,
              ),
              const SizedBox(width: Gap.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Advanced', style: text.titleSmall),
                    Text(
                      'Connections, refresh, ADB key, maintenance, '
                      'snapshot, debug info',
                      style: text.bodySmall,
                    ),
                  ],
                ),
              ),
              AnimatedRotation(
                turns: open ? 0.5 : 0,
                duration: Motion.of(context, Motion.fast),
                child: Icon(Icons.expand_more_rounded, color: bt.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdvancedBody extends ConsumerWidget {
  final Tv? active;
  const _AdvancedBody({required this.active});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = this.active;
    final settings = ref.watch(appSettingsProvider);
    final caps = ref.watch(capabilityProvider);
    final match = ref.watch(profileMatchProvider).valueOrNull;
    final text = Theme.of(context).textTheme;
    return Column(
      key: const Key('settings-advanced-body'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (active != null) ...[
          SectionHeader(
            'What ${active.name} can do',
            trailing: caps.isLoading
                ? const Padding(
                    padding: EdgeInsets.all(Gap.md),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : TextButton(
                    onPressed: () =>
                        ref.read(capabilityProvider.notifier).probe(),
                    child: const Text('Re-check'),
                  ),
          ),
          GroupCard(
            children: [
              for (final c in TvCapability.values)
                StatusRow(
                  tone: active.can(c) ? Tone.ok : Tone.idle,
                  icon:
                      active.can(c) ? Icons.check_rounded : Icons.close_rounded,
                  title: capabilityTitle(c),
                  detail: !active.can(c) && caps.valueOrNull?.detail(c) != null
                      ? '${capabilityMeaning(c)} · '
                          '${caps.valueOrNull!.detail(c)}'
                      : capabilityMeaning(c),
                  detailLines: 2,
                ),
              if (active.capabilitiesCheckedAt != null)
                Padding(
                  padding: const EdgeInsets.all(Gap.md),
                  child: Text(
                    'Checked ${relativeTime(active.capabilitiesCheckedAt!)}'
                    '${match == null ? '' : ' · ${match.profile.name}'}',
                    style: text.bodySmall,
                  ),
                ),
            ],
          ),
          if (match != null && match.profile.readOnly) ...[
            const SizedBox(height: Gap.md),
            GroupCard(
              children: [
                StatusRow(
                  tone: Tone.warn,
                  icon: Icons.build_circle_rounded,
                  title: 'Allow maintenance',
                  detail: 'Untested TV model: fixes and app changes stay '
                      'off unless you allow them.',
                  detailLines: 3,
                  trailing: Switch(
                    value: settings.maintenanceUnlocked.contains(active.id),
                    onChanged: (v) async {
                      if (v &&
                          !await confirmAction(
                            context,
                            title: 'Allow maintenance?',
                            message: 'boretube doesn\'t have a tested '
                                'profile for this TV. Fixes and app '
                                'changes will be allowed anyway — each one '
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
        const SectionHeader('Refresh what\'s on'),
        InfoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Check the TV every', style: text.titleSmall),
              const SizedBox(height: Gap.md),
              _Segmented<int>(
                key: const Key('settings-poll'),
                values: AppSettings.pollChoices,
                label: (s) => '${s}s',
                semantic: (s) => 'Every $s seconds',
                selected: settings.pollSeconds,
                onSelect: (s) =>
                    ref.read(appSettingsProvider.notifier).setPollSeconds(s),
              ),
              const SizedBox(height: Gap.sm),
              Text('Only while boretube is open.', style: text.bodySmall),
            ],
          ),
        ),
        const SectionHeader('ADB key'),
        const _AdbKeyCard(),
        const SectionHeader('Baseline snapshot'),
        const BaselineCard(),
        const SectionHeader('Debug info'),
        const _DebugInfoCard(),
      ],
    );
  }
}

/// A row of equal choices with input-radius corners (not pills).
class _Segmented<T> extends StatelessWidget {
  final List<T> values;
  final T selected;
  final String Function(T v) label;
  final String Function(T v) semantic;
  final ValueChanged<T> onSelect;

  const _Segmented({
    super.key,
    required this.values,
    required this.selected,
    required this.label,
    required this.semantic,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final bt = context.bt;
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(Gap.xs),
      decoration: BoxDecoration(
        color: bt.hairline,
        borderRadius: Radii.field,
      ),
      child: Row(
        children: [
          for (final v in values)
            Expanded(
              child: Semantics(
                button: true,
                selected: v == selected,
                label: semantic(v),
                excludeSemantics: true,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    if (v != selected) HapticFeedback.selectionClick();
                    onSelect(v);
                  },
                  child: AnimatedContainer(
                    duration: Motion.of(context, Motion.fast),
                    curve: Motion.settle,
                    constraints: const BoxConstraints(minHeight: 44),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: v == selected ? bt.surface : Colors.transparent,
                      borderRadius: const BorderRadius.all(
                        Radius.circular(Radii.input - 4),
                      ),
                      border: Border.all(
                        color: v == selected ? bt.border : Colors.transparent,
                      ),
                    ),
                    child: Text(
                      label(v),
                      maxLines: 1,
                      style: text.labelLarge!.copyWith(
                        fontSize: 14,
                        fontFeatures: Fonts.tabular,
                        color: v == selected ? bt.ink : bt.muted,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The facts a helper asks for, copyable in one go.
class _DebugInfoCard extends ConsumerWidget {
  const _DebugInfoCard();

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
    return InfoCard(
      key: const Key('settings-debug'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(Gap.md),
            decoration: BoxDecoration(
              color: bt.hairline,
              borderRadius: Radii.field,
            ),
            child: SelectionArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final (k, v) in lines)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '$k  ',
                              style: TextStyle(color: bt.muted),
                            ),
                            TextSpan(text: v),
                          ],
                        ),
                        style: text.bodySmall!.copyWith(
                          fontFamily: 'monospace',
                          fontFamilyFallback: const ['Roboto'],
                          fontSize: 12,
                          color: bt.ink,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: Gap.md),
          OutlinedButton.icon(
            key: const Key('settings-debug-copy'),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: asText()));
              if (context.mounted) {
                showStatusSnack(context, 'Debug info copied');
              }
            },
            icon: const Icon(Icons.copy_rounded),
            label: const Text('Copy debug info'),
          ),
        ],
      ),
    );
  }
}

// ── About ──

class _AboutCard extends StatelessWidget {
  const _AboutCard();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final bt = context.bt;
    final chevron = Icon(Icons.chevron_right_rounded, color: bt.faint);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GroupCard(
          children: [
            StatusRow(
              key: const Key('settings-help-always-on'),
              tone: Tone.ok,
              icon: Icons.shield_rounded,
              title: 'What is Always On?',
              trailing: chevron,
              onTap: () => showLearnSheet(context, LearnTerm.alwaysOn),
            ),
            StatusRow(
              key: const Key('settings-help-home-mode'),
              tone: Tone.info,
              icon: Icons.home_rounded,
              title: 'What is Home mode?',
              trailing: chevron,
              onTap: () => showLearnSheet(context, LearnTerm.homeMode),
            ),
            StatusRow(
              key: const Key('settings-help-guide'),
              tone: Tone.info,
              icon: Icons.menu_book_rounded,
              title: 'Set up Home mode',
              detail: 'The step-by-step guide, with the TV menus',
              trailing: chevron,
              onTap: () => context.push('/adb-guide'),
            ),
          ],
        ),
        const SizedBox(height: Gap.md),
        InfoCard(
          child: Row(
            children: [
              const BrandMark(size: 44),
              const SizedBox(width: Gap.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('boretube $appVersion', style: text.titleSmall),
                    Text(
                      'Android TV parental controls. Calmer TV, fewer '
                      'fights, no Shorts.',
                      style: text.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── TVs ──

class _TvRow extends ConsumerWidget {
  final Tv tv;
  final bool active;

  const _TvRow({required this.tv, required this.active});

  Future<void> _menu(BuildContext context, WidgetRef ref, String v) async {
    final store = ref.read(tvStoreProvider);
    switch (v) {
      case 'active':
        await store.setActive(tv.id);
      case 'edit':
        final edited = await showTvAddressDialog(context, initial: tv);
        if (edited != null) await saveEditedTv(store, tv, edited);
      case 'forget':
        final ok = await confirmAction(
          context,
          title: 'Forget ${tv.name}?',
          message: 'It disappears from this phone. Nothing changes on the '
              'TV. You can find it again later.',
          confirmLabel: 'Forget',
          destructive: true,
          icon: Icons.delete_outline_rounded,
        );
        if (ok) await store.remove(tv.id);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = [
      if (tv.model.isNotEmpty) tv.model else tv.ip,
      if (tv.lastSeen != null) 'seen ${relativeTime(tv.lastSeen!)}',
    ].join(' · ');
    return StatusRow(
      key: Key('settings-tv-${tv.id}'),
      tone: active ? Tone.accent : Tone.idle,
      icon: active ? Icons.tv_rounded : Icons.tv_outlined,
      title: tv.name,
      detail: detail,
      onTap: active ? null : () => _menu(context, ref, 'active'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (active)
            const BtBadge('In use', tone: Tone.accent, icon: Icons.check),
          PopupMenuButton<String>(
            tooltip: 'TV options',
            onSelected: (v) => _menu(context, ref, v),
            itemBuilder: (_) => [
              if (!active)
                const PopupMenuItem(
                    value: 'active', child: Text('Use this TV')),
              const PopupMenuItem(
                value: 'edit',
                child: Text('Rename or edit address'),
              ),
              const PopupMenuItem(value: 'forget', child: Text('Forget')),
            ],
          ),
        ],
      ),
    );
  }
}

class _AdbKeyCard extends ConsumerWidget {
  const _AdbKeyCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = ref.watch(adbKeyProvider);
    final text = Theme.of(context).textTheme;
    return InfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('This phone\'s fingerprint', style: text.titleSmall),
          const SizedBox(height: Gap.xs),
          Text(
            'The TV shows the same code when it asks to allow debugging.',
            style: text.bodySmall,
          ),
          const SizedBox(height: Gap.md),
          key.when(
            loading: () => const Skeleton(height: 14),
            error: (e, _) => Text('Key unavailable: $e', style: text.bodySmall),
            data: (k) => SelectableText(
              adbFingerprint(k),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            ),
          ),
          const SizedBox(height: Gap.md),
          OutlinedButton.icon(
            onPressed: () async {
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
            icon: const Icon(Icons.key_off_rounded),
            label: const Text('Reset key'),
          ),
        ],
      ),
    );
  }
}
