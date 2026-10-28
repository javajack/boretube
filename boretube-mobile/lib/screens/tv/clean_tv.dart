import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../ops/device_profile.dart';
import '../../ops/tv_ops.dart';
import '../../providers/providers.dart';
import '../../providers/tv_providers.dart';
import '../../ui/components.dart';
import '../../ui/controls.dart';
import '../../ui/learn.dart';
import '../../ui/tokens.dart';
import 'common.dart';

// ── grouping (pure) ──

enum CleanGroup { sony, ads, google, optional }

extension CleanGroupCopy on CleanGroup {
  String get title => switch (this) {
        CleanGroup.sony => 'Sony promos',
        CleanGroup.ads => 'Ads and tracking',
        CleanGroup.google => 'Google leftovers',
        CleanGroup.optional => 'Optional apps',
      };

  String get blurb => switch (this) {
        CleanGroup.sony => 'Banners, demos and Sony\'s app store on the home '
            'screen.',
        CleanGroup.ads => 'Things that learn what you watch to pick ads, or '
            'install promoted apps.',
        CleanGroup.google => 'Setup and phone features a TV doesn\'t need.',
        CleanGroup.optional => 'Streaming apps you may not use. Pick the ones '
            'to tidy away.',
      };

  IconData get icon => switch (this) {
        CleanGroup.sony => Icons.campaign_rounded,
        CleanGroup.ads => Icons.visibility_off_rounded,
        CleanGroup.google => Icons.inventory_2_rounded,
        CleanGroup.optional => Icons.live_tv_rounded,
      };
}

const _plain = {
  'com.android.adservices.api': 'Ad personalisation',
  'com.android.federatedcompute.services': 'Ad learning on the TV',
  'com.android.ondevicepersonalization.services': 'Personalised ads',
  'android.autoinstalls.config.google.gtvpai': 'Apps Google installs by '
      'itself',
  'com.google.android.feedback': 'Feedback reporter',
  'com.google.android.play.games': 'Play Games',
  'com.google.android.partnersetup': 'Setup leftovers',
  'com.google.android.onetimeinitializer': 'First-setup leftovers',
  'com.google.android.syncadapters.calendar': 'Calendar sync',
  'com.android.printspooler': 'Printing',
  'com.android.gallery3d': 'Photo gallery',
  'com.sony.dtv.sonyselect': 'Sony Select app store',
  'com.sony.dtv.multiscreendemo': 'Shop demo mode',
};

CleanGroup cleanGroupOf(String pkg, {bool extra = false}) {
  if (extra) return CleanGroup.optional;
  if (pkg.startsWith('com.sony')) return CleanGroup.sony;
  if (pkg.contains('adservices') ||
      pkg.contains('federatedcompute') ||
      pkg.contains('ondevicepersonalization') ||
      pkg.contains('autoinstalls')) {
    return CleanGroup.ads;
  }
  return CleanGroup.google;
}

enum CleanState { tidied, showing }

typedef CleanItem = ({String pkg, String label, CleanState state});

/// Profile clean-up (and optional) apps present on this TV, by group in
/// display order. Apps the TV doesn't have are left out.
Map<CleanGroup, List<CleanItem>> cleanGroups(
  DeviceProfile profile,
  CleanupStatus status,
) {
  final extras = {for (final e in profile.extras) e.pkg};
  final out = <CleanGroup, List<CleanItem>>{};
  for (final p in [...profile.cleanup, ...profile.extras]) {
    if (!status.present.contains(p.pkg)) continue;
    final g = cleanGroupOf(p.pkg, extra: extras.contains(p.pkg));
    final label = _plain[p.pkg] ?? (p.comment.isEmpty ? p.pkg : p.comment);
    (out[g] ??= []).add((
      pkg: p.pkg,
      label: label,
      state: status.disabled.contains(p.pkg)
          ? CleanState.tidied
          : CleanState.showing,
    ));
  }
  return {
    for (final g in CleanGroup.values)
      if (out[g] != null) g: out[g]!,
  };
}

// ── state ──

/// The optional apps the parent chose to tidy, per TV.
class CleanExtras {
  final SharedPreferences prefs;
  const CleanExtras(this.prefs);

  static String keyFor(String tvId) => 'ui.clean.extras.$tvId';

  Set<String> read(String tvId) =>
      (prefs.getStringList(keyFor(tvId)) ?? const []).toSet();

  Future<void> write(String tvId, Set<String> v) =>
      prefs.setStringList(keyFor(tvId), v.toList()..sort());
}

final cleanExtrasStoreProvider = Provider<CleanExtras>(
  (ref) => CleanExtras(ref.watch(sharedPrefsProvider)),
);

/// Status of every clean-up and optional app on the active TV.
final cleanStatusProvider = FutureProvider<CleanupStatus?>((ref) async {
  final ops = await ref.watch(tvOpsProvider.future);
  if (ops == null) return null;
  return ops.cleanupStatus(
    extras: {for (final e in ops.profile.extras) e.pkg},
  );
});

/// How many core clean-up apps are tidied, of those on the TV.
({int tidied, int present})? cleanCounts(
  DeviceProfile profile,
  CleanupStatus s,
) {
  final core = {for (final c in profile.cleanup) c.pkg};
  final present = s.present.where(core.contains).length;
  if (present == 0) return null;
  return (
    tidied: s.disabled.where(core.contains).length,
    present: present,
  );
}

// ── screen ──

class CleanTvScreen extends ConsumerStatefulWidget {
  const CleanTvScreen({super.key});

  @override
  ConsumerState<CleanTvScreen> createState() => _CleanTvScreenState();
}

class _CleanTvScreenState extends ConsumerState<CleanTvScreen> {
  Set<String>? _extras;

  Set<String> _chosen() {
    final id = ref.read(activeTvIdProvider);
    return _extras ??=
        id == null ? <String>{} : ref.read(cleanExtrasStoreProvider).read(id);
  }

  Future<void> _toggleExtra(String pkg, bool on) async {
    final id = ref.read(activeTvIdProvider);
    final next = {..._chosen()};
    on ? next.add(pkg) : next.remove(pkg);
    setState(() => _extras = next);
    if (id != null) await ref.read(cleanExtrasStoreProvider).write(id, next);
  }

  Future<void> _tidy(TvOps ops, int n) async {
    final ok = await confirmAction(
      context,
      title: n == 1 ? 'Tidy away 1 app?' : 'Tidy away $n apps?',
      message: 'They\'re switched off, not deleted. Undo brings them all '
          'back, and every change is kept in History.',
      confirmLabel: 'Tidy',
      icon: Icons.auto_awesome_rounded,
    );
    if (!ok || !mounted) return;
    await runMaintenance(
      context,
      ref,
      title: 'TV tidied',
      run: () => ops.applyCleanup(extras: _chosen()),
    );
    _refresh();
  }

  Future<void> _undo(TvOps ops) async {
    final ok = await confirmAction(
      context,
      title: 'Bring everything back?',
      message: 'Every app Clean TV switched off comes back, the way the TV '
          'came.',
      confirmLabel: 'Bring back',
      icon: Icons.undo_rounded,
    );
    if (!ok || !mounted) return;
    await runMaintenance(
      context,
      ref,
      title: 'Apps are back',
      run: () => ops.undoCleanup(
        extras: {for (final e in ops.profile.extras) e.pkg},
      ),
    );
    _refresh();
  }

  void _refresh() => ref
    ..invalidate(cleanStatusProvider)
    ..invalidate(healthProvider)
    ..invalidate(appsProvider);

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final bt = context.bt;
    final ops = ref.watch(tvOpsProvider).valueOrNull;
    final status = ref.watch(cleanStatusProvider);
    final canWrite =
        ops != null && (!ops.profile.readOnly || ops.maintenanceUnlocked);
    return DetailPage(
      title: 'Clean TV',
      titleTrailing: const InfoDot(LearnTerm.cleanTv),
      subtitle: 'Switch off the promo and leftover apps. Nothing is deleted.',
      onRefresh: () async {
        _refresh();
        await ref.read(cleanStatusProvider.future);
      },
      children: [
        ...status.when(
          loading: () => const [SkeletonCard(rows: 5)],
          error: (e, _) => [
            InfoCard(
              child: EmptyState(
                icon: Icons.wifi_off_rounded,
                tone: Tone.bad,
                title: 'Couldn\'t read the TV',
                message: 'Is it on and on this Wi-Fi? Then try again.',
                actionLabel: 'Try again',
                onAction: _refresh,
              ),
            ),
          ],
          data: (s) {
            if (s == null || ops == null) return const <Widget>[];
            final groups = cleanGroups(ops.profile, s);
            final chosen = _chosen();
            final todo = [
              for (final e in groups.entries)
                for (final i in e.value)
                  if (i.state == CleanState.showing &&
                      (e.key != CleanGroup.optional || chosen.contains(i.pkg)))
                    i,
            ];
            final tidied = [
              for (final l in groups.values)
                for (final i in l)
                  if (i.state == CleanState.tidied) i,
            ];
            if (groups.isEmpty) {
              return const [
                InfoCard(
                  child: EmptyState(
                    icon: Icons.auto_awesome_rounded,
                    tone: Tone.ok,
                    title: 'Nothing to tidy',
                    message: 'This TV doesn\'t have the promo apps boretube '
                        'knows about.',
                  ),
                ),
              ];
            }
            return [
              _CleanSummary(todo: todo.length, tidied: tidied.length),
              const SizedBox(height: Gap.md),
              if (todo.isNotEmpty)
                PrimaryButton(
                  key: const Key('clean-fix'),
                  label: 'Tidy ${todo.length} app'
                      '${todo.length == 1 ? '' : 's'}',
                  icon: Icons.auto_awesome_rounded,
                  onPressed: canWrite ? () => _tidy(ops, todo.length) : null,
                ),
              if (tidied.isNotEmpty) ...[
                const SizedBox(height: Gap.sm),
                PrimaryButton(
                  key: const Key('clean-undo'),
                  label: 'Undo · bring them back',
                  icon: Icons.undo_rounded,
                  kind: ButtonKind.outline,
                  height: 52,
                  onPressed: canWrite ? () => _undo(ops) : null,
                ),
              ],
              if (!canWrite) ...[
                const SizedBox(height: Gap.sm),
                Text(
                  'boretube hasn\'t been tested on this TV model, so this is '
                  'a preview. Allow changes in Settings › Advanced.',
                  style: text.bodySmall,
                ),
              ],
              for (final e in groups.entries) ...[
                SectionHeader(
                  '${e.key.title} · ${e.value.length}',
                  padding: const EdgeInsets.fromLTRB(
                    Gap.xs,
                    Gap.xl,
                    Gap.xs,
                    Gap.xs,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Gap.xs,
                    0,
                    Gap.xs,
                    Gap.sm,
                  ),
                  child: Text(e.key.blurb, style: text.bodySmall),
                ),
                GroupCard(
                  key: Key('clean-group-${e.key.name}'),
                  children: [
                    for (final i in e.value)
                      _CleanRow(
                        key: Key('clean-${i.pkg}'),
                        item: i,
                        group: e.key,
                        chosen: chosen.contains(i.pkg),
                        onChoose: e.key == CleanGroup.optional &&
                                i.state == CleanState.showing
                            ? (v) => _toggleExtra(i.pkg, v)
                            : null,
                      ),
                  ],
                ),
              ],
              const SizedBox(height: Gap.lg),
              Row(
                children: [
                  Icon(Icons.verified_user_rounded, size: 18, color: bt.muted),
                  const SizedBox(width: Gap.sm),
                  Expanded(
                    child: Text(
                      'Wi-Fi setup, the Google TV home screen and the voice '
                      'remote are never touched.',
                      style: text.bodySmall,
                    ),
                  ),
                ],
              ),
            ];
          },
        ),
      ],
    );
  }
}

class _CleanSummary extends StatelessWidget {
  final int todo;
  final int tidied;
  const _CleanSummary({required this.todo, required this.tidied});

  @override
  Widget build(BuildContext context) {
    final bt = context.bt;
    final text = Theme.of(context).textTheme;
    final done = todo == 0;
    return InfoCard(
      key: const Key('clean-summary'),
      color: done ? bt.mintTint : bt.lavenderTint,
      borderColor: done ? bt.mintTint : bt.lavenderTint,
      radius: Radii.hero,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  done ? 'Tidy' : '$todo to tidy',
                  style: Fonts.bricolage(
                    28,
                    color: done ? bt.mintInk : bt.lavenderInk,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  tidied == 0
                      ? 'Nothing tidied yet'
                      : '$tidied already tidied away',
                  style: text.bodyMedium!.copyWith(color: bt.inkSoft),
                ),
              ],
            ),
          ),
          Icon(
            done ? Icons.check_circle_rounded : Icons.auto_awesome_rounded,
            size: 40,
            color: done ? bt.mint : bt.lavender,
          ),
        ],
      ),
    );
  }
}

class _CleanRow extends StatelessWidget {
  final CleanItem item;
  final CleanGroup group;
  final bool chosen;
  final ValueChanged<bool>? onChoose;

  const _CleanRow({
    super.key,
    required this.item,
    required this.group,
    required this.chosen,
    this.onChoose,
  });

  @override
  Widget build(BuildContext context) {
    final tidied = item.state == CleanState.tidied;
    final optional = group == CleanGroup.optional;
    return StatusRow(
      tone: tidied ? Tone.ok : (optional && !chosen ? Tone.idle : Tone.warn),
      icon: tidied ? Icons.check_rounded : group.icon,
      title: item.label,
      detail: tidied
          ? 'Tidied away'
          : optional
              ? (chosen ? 'Will be tidied' : 'Stays on the TV')
              : 'Still showing · will be tidied',
      trailing:
          onChoose != null ? Switch(value: chosen, onChanged: onChoose) : null,
    );
  }
}
