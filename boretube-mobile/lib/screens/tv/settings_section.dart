import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/security_providers.dart';
import '../../providers/settings_provider.dart';
import '../../providers/tv_providers.dart';
import '../../providers/ui_providers.dart';
import '../../tv/tv.dart';
import '../../tv/tv_store.dart';
import '../../ui/components.dart';
import '../../ui/format.dart';
import '../../ui/tokens.dart';
import '../../version.dart';
import '../lock_screen.dart';
import '../shell_screen.dart';
import '../tv_address_dialog.dart';
import 'common.dart';

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

/// Settings: your TVs, look, parent PIN, then everything technical under
/// Advanced (the only place that says ADB, Cast or agent).
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
    final settings = ref.watch(appSettingsProvider);
    final lock = ref.watch(appLockProvider);
    final theme = ref.watch(themePrefProvider);
    final bioAvailable =
        ref.watch(biometricAvailableProvider).valueOrNull ?? false;
    final caps = ref.watch(capabilityProvider);
    final match = ref.watch(profileMatchProvider).valueOrNull;
    final text = Theme.of(context).textTheme;
    final bt = context.bt;

    return ListView(
      padding: tvListPadding,
      children: [
        SectionHeader(
          'Your TVs',
          padding: const EdgeInsets.fromLTRB(
            Gap.xs,
            Gap.sm,
            Gap.xs,
            Gap.sm,
          ),
          trailing: TextButton.icon(
            onPressed: () => context.push('/onboarding?add=1'),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add a TV'),
          ),
        ),
        GroupCard(
          children: [
            for (final t in tvs) _TvRow(tv: t, active: t.id == active?.id),
          ],
        ),
        const SectionHeader('Look'),
        InfoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Theme', style: text.titleSmall),
              const SizedBox(height: Gap.md),
              SegmentedButton<ThemePref>(
                key: const Key('settings-theme'),
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: ThemePref.system, label: Text('Phone')),
                  ButtonSegment(value: ThemePref.light, label: Text('Light')),
                  ButtonSegment(value: ThemePref.dark, label: Text('Dark')),
                ],
                selected: {
                  theme == ThemePref.bedtime ? ThemePref.system : theme,
                },
                onSelectionChanged: (s) =>
                    ref.read(themePrefProvider.notifier).set(s.first),
              ),
              const SizedBox(height: Gap.sm),
              SwitchListTile(
                key: const Key('settings-bedtime-dark'),
                contentPadding: EdgeInsets.zero,
                value: theme == ThemePref.bedtime,
                onChanged: (v) => ref
                    .read(themePrefProvider.notifier)
                    .set(v ? ThemePref.bedtime : ThemePref.system),
                title: const Text('Bedtime dark after sunset'),
                subtitle: const Text('Dark from 7 pm to 7 am'),
              ),
            ],
          ),
        ),
        const SectionHeader('Parent PIN'),
        GroupCard(
          children: [
            StatusRow(
              tone: Tone.accent,
              icon: Icons.pin_rounded,
              title: 'Change PIN',
              trailing: Icon(Icons.chevron_right_rounded, color: bt.faint),
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
              onTap: () => ref.read(appLockProvider.notifier).lockNow(),
            ),
          ],
        ),
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
              trailing: Icon(Icons.chevron_right_rounded, color: bt.faint),
              onTap: () => context.push('/restore'),
            ),
            StatusRow(
              key: const Key('settings-history'),
              tone: Tone.info,
              icon: Icons.history_rounded,
              title: 'History',
              detail: 'Every change to the TV, with before and after',
              trailing: Icon(Icons.chevron_right_rounded, color: bt.faint),
              onTap: () => context.push('/history'),
            ),
          ],
        ),
        const SizedBox(height: Gap.lg),
        InfoCard(
          key: const Key('settings-advanced'),
          padding: EdgeInsets.zero,
          onTap: () => setState(() => _advanced = !_advanced),
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
                        'Connections, refresh, ADB key, maintenance',
                        style: text.bodySmall,
                      ),
                    ],
                  ),
                ),
                AnimatedRotation(
                  turns: _advanced ? 0.5 : 0,
                  duration: Motion.of(context, Motion.fast),
                  child: Icon(Icons.expand_more_rounded, color: bt.muted),
                ),
              ],
            ),
          ),
        ),
        if (_advanced) ...[
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
                    icon: active.can(c)
                        ? Icons.check_rounded
                        : Icons.close_rounded,
                    title: capabilityTitle(c),
                    detail:
                        !active.can(c) && caps.valueOrNull?.detail(c) != null
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
              InfoCard(
                padding: EdgeInsets.zero,
                child: SwitchListTile(
                  value: settings.maintenanceUnlocked.contains(active.id),
                  onChanged: (v) async {
                    if (v &&
                        !await confirmAction(
                          context,
                          title: 'Allow maintenance?',
                          message: 'boretube doesn\'t have a tested profile '
                              'for this TV. Fixes and app changes will be '
                              'allowed anyway — each one still asks first.',
                          confirmLabel: 'Allow',
                        )) {
                      return;
                    }
                    await ref
                        .read(appSettingsProvider.notifier)
                        .setMaintenanceUnlocked(active.id, v);
                  },
                  title: const Text('Allow maintenance'),
                  subtitle: const Text('Untested TV model'),
                ),
              ),
            ],
          ],
          const SectionHeader('Refresh what\'s on'),
          InfoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Check the TV every', style: text.titleSmall),
                const SizedBox(height: Gap.md),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<int>(
                    showSelectedIcon: false,
                    segments: [
                      for (final s in AppSettings.pollChoices)
                        ButtonSegment(value: s, label: Text('${s}s')),
                    ],
                    selected: {settings.pollSeconds},
                    onSelectionChanged: (s) => ref
                        .read(appSettingsProvider.notifier)
                        .setPollSeconds(s.first),
                  ),
                ),
                const SizedBox(height: Gap.sm),
                Text(
                  'Only while boretube is open.',
                  style: text.bodySmall,
                ),
              ],
            ),
          ),
          const SectionHeader('ADB key'),
          const _AdbKeyCard(),
        ],
        const SectionHeader('About'),
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
                      'Android TV parental controls',
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
      tv.ip,
      if (tv.model.isNotEmpty) tv.model,
      if (tv.lastSeen != null) 'seen ${relativeTime(tv.lastSeen!)}',
    ].join(' · ');
    return StatusRow(
      tone: active ? Tone.accent : Tone.idle,
      icon: active ? Icons.tv_rounded : Icons.tv_outlined,
      title: active ? '${tv.name} · active' : tv.name,
      detail: detail,
      onTap: active ? null : () => _menu(context, ref, 'active'),
      trailing: PopupMenuButton<String>(
        tooltip: 'TV options',
        onSelected: (v) => _menu(context, ref, v),
        itemBuilder: (_) => [
          if (!active)
            const PopupMenuItem(value: 'active', child: Text('Set active')),
          const PopupMenuItem(
            value: 'edit',
            child: Text('Rename or edit address'),
          ),
          const PopupMenuItem(value: 'forget', child: Text('Forget')),
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
