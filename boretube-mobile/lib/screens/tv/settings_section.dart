import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/security_providers.dart';
import '../../providers/settings_provider.dart';
import '../../providers/tv_providers.dart';
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

class SettingsSection extends ConsumerWidget {
  const SettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tvs = ref.watch(savedTvsProvider);
    final active = ref.watch(activeTvProvider);
    final settings = ref.watch(appSettingsProvider);
    final lock = ref.watch(appLockProvider);
    final bioAvailable =
        ref.watch(biometricAvailableProvider).valueOrNull ?? false;
    final caps = ref.watch(capabilityProvider);
    final match = ref.watch(profileMatchProvider).valueOrNull;
    final text = Theme.of(context).textTheme;

    return ListView(
      padding: tvListPadding,
      children: [
        SectionHeader(
          'Saved TVs',
          padding: const EdgeInsets.fromLTRB(
            Gap.xs,
            Gap.sm,
            Gap.xs,
            Gap.sm,
          ),
          trailing: TextButton.icon(
            onPressed: () => context.push('/onboarding?add=1'),
            icon: const Icon(Icons.radar_rounded, size: 18),
            label: const Text('Find TVs'),
          ),
        ),
        GroupCard(
          children: [
            for (final t in tvs) _TvRow(tv: t, active: t.id == active?.id),
          ],
        ),
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
                  detail: !active.can(c) &&
                          caps.valueOrNull?.detail(c) != null
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
                        message: 'Boretube doesn\'t have a tested profile '
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
        const SectionHeader('Now on TV'),
        InfoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Refresh every', style: text.titleSmall),
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
                'Only while Boretube is open.',
                style: text.bodySmall,
              ),
            ],
          ),
        ),
        const SectionHeader('Security'),
        GroupCard(
          children: [
            StatusRow(
              tone: Tone.accent,
              icon: Icons.pin_rounded,
              title: 'Change PIN',
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => showChangePinSheet(context, ref),
            ),
            if (bioAvailable)
              StatusRow(
                tone: Tone.accent,
                icon: Icons.fingerprint_rounded,
                title: 'Unlock with fingerprint',
                trailing: Switch(
                  value: lock.biometricEnabled,
                  onChanged: (v) => ref
                      .read(appLockProvider.notifier)
                      .setBiometricEnabled(v),
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
        const SectionHeader('ADB key'),
        const _AdbKeyCard(),
        const SectionHeader('About'),
        InfoCard(
          child: Row(
            children: [
              const BrandMark(size: 40),
              const SizedBox(width: Gap.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Boretube $appVersion', style: text.titleSmall),
                    Text(
                      'Parental remote for Google TV',
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
                    'before Boretube can use ADB.',
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
