import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ops/clean_wizard.dart';
import '../../ops/device_profile.dart';
import '../../ops/tv_ops.dart';
import '../../providers/agent_providers.dart';
import '../../providers/clean_wizard_providers.dart';
import '../../providers/now_playing.dart';
import '../../providers/tv_providers.dart';
import '../../ui/components.dart';
import '../../ui/format.dart';
import '../../ui/tokens.dart';
import '../../ui/tubby.dart';
import 'apps_section.dart';
import 'clean_tv.dart';

/// One plain line on why each app can go.
const _why = {
  'com.sony.dtv.promos': 'Promo banners on the home screen',
  'com.sony.dtv.sonyselect': 'Sony\'s app store and its ads',
  'com.sony.dtv.sonytab': 'The Sony row on the home screen',
  'com.sony.dtv.multiscreendemo': 'Demo mode for TVs in shops',
  'com.sony.dtv.smarthelp': 'Sony\'s help app',
  'com.sony.dtv.helpguidecontents': 'Pages for the help app',
  'com.sonypicturescore': 'Sony\'s film store',
  'com.android.adservices.api': 'Picks ads from what you watch',
  'com.android.federatedcompute.services': 'Learns from viewing, for ads',
  'com.android.ondevicepersonalization.services': 'Personalises ads on the TV',
  'android.autoinstalls.config.google.gtvpai': 'Installs promoted apps by '
      'itself',
  'com.google.android.feedback': 'Sends problem reports to Google',
  'com.google.android.play.games': 'Google\'s games hub',
  'com.google.android.partnersetup': 'Left over from first setup',
  'com.google.android.onetimeinitializer': 'Ran once, at first setup',
  'com.google.android.syncadapters.calendar': 'Syncs a calendar the TV '
      'never shows',
  'com.android.printspooler': 'Printing, which a TV doesn\'t do',
  'com.android.gallery3d': 'A photo viewer, rarely opened',
  'com.sonyliv': 'A streaming app, back anytime',
  'com.amazon.amazonvideo.livingroom': 'A streaming app, back anytime',
  'com.apple.atve.androidtv.appletv': 'A streaming app, back anytime',
};

String _explain(CleanItem i) => _why[i.pkg] ?? i.label;

/// The groups the wizard offers: Clean TV's grouping, never-touch apps
/// left out.
Map<CleanGroup, List<CleanItem>> wizardGroups(
  TvOps ops,
  CleanupStatus status,
) =>
    {
      for (final e in cleanGroups(ops.profile, status).entries)
        if (e.value.where((i) => !ops.isProtected(i.pkg)).toList()
            case final items when items.isNotEmpty)
          e.key: items,
    };

/// Whether the profile has a tested clean-up list the wizard may use.
bool wizardSupported(DeviceProfile p) => !p.readOnly && p.cleanup.isNotEmpty;

/// Ticked by default: everything still showing, except optional apps.
Set<String> defaultSelection(Map<CleanGroup, List<CleanItem>> groups) => {
      for (final e in groups.entries)
        if (e.key != CleanGroup.optional)
          for (final i in e.value)
            if (i.state == CleanState.showing) i.pkg,
    };

/// Better TV › Clean TV › Clean up step by step: a restore point, a
/// choice, then one group at a time with a restart and checks in between.
class CleanWizardScreen extends ConsumerStatefulWidget {
  const CleanWizardScreen({super.key});

  @override
  ConsumerState<CleanWizardScreen> createState() => _CleanWizardState();
}

class _CleanWizardState extends ConsumerState<CleanWizardScreen> {
  CleanWizard? _wizard;
  Set<String>? _selected;

  @override
  void initState() {
    super.initState();
    final id = ref.read(activeTvIdProvider);
    if (id == null) return;
    final w = CleanWizard(
      tvId: id,
      store: ref.read(wizardProgressStoreProvider),
      ops: () => ref.read(tvOpsProvider.future),
      probes: ref.read(wizardProbesProvider),
      journal: ref.read(journalProvider),
      baselines: ref.read(baselineStoreProvider),
      clock: ref.read(wizardClockProvider),
      timing: ref.read(wizardTimingProvider),
      label: appLabel,
    )..addListener(_changed);
    _wizard = w;
    final saved = w.progress.selected;
    if (saved.isNotEmpty) _selected = {...saved};
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(w.resume());
    });
  }

  void _changed() {
    if (!mounted) return;
    setState(() {});
    final p = _wizard?.progress;
    if (p != null && p.step == WizardStep.done) {
      ref
        ..invalidate(journalEntriesProvider)
        ..invalidate(cleanStatusProvider)
        ..invalidate(healthProvider)
        ..invalidate(appsProvider);
    }
  }

  @override
  void dispose() {
    _wizard
      ?..removeListener(_changed)
      ..dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await _wizard?.finish();
    ref
      ..invalidate(cleanStatusProvider)
      ..invalidate(journalEntriesProvider);
    if (mounted) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final w = _wizard;
    final opsAsync = ref.watch(tvOpsProvider);
    final ops = opsAsync.valueOrNull;
    final Widget body;
    final String key;
    if (w == null || (!opsAsync.isLoading && ops == null)) {
      key = 'offline';
      body = const _Offline();
    } else if (ops == null) {
      key = 'loading';
      body = const Center(child: CircularProgressIndicator());
    } else if (!wizardSupported(ops.profile)) {
      key = 'generic';
      body = _Generic(
        onApps: () => Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(builder: (_) => const AppsScreen()),
        ),
      );
    } else {
      key = _keyOf(w);
      body = _bodyOf(w, ops);
    }
    final p = w?.progress;
    final steps =
        p == null || key == 'generic' || key == 'offline' ? null : _stepOf(p);
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (steps != null) _Header(index: steps.$1, count: steps.$2),
            Expanded(
              child: AnimatedSwitcher(
                duration: Motion.of(context, Motion.sheet),
                switchInCurve: Motion.enter,
                switchOutCurve: Motion.exit,
                transitionBuilder: _slide,
                child: KeyedSubtree(key: ValueKey(key), child: body),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// (index, count) for the step bar: restore point, choose, each
  /// batch, done.
  (int, int)? _stepOf(WizardProgress p) {
    final n = p.batches.isEmpty ? 1 : p.batches.length;
    final count = n + 3;
    return switch (p.step) {
      WizardStep.restorePoint => (0, count),
      WizardStep.choose => (1, count),
      WizardStep.batch => (2 + p.current, count),
      WizardStep.done => null,
    };
  }

  String _keyOf(CleanWizard w) {
    final p = w.progress;
    return switch (p.step) {
      WizardStep.batch => 'batch-${p.current}-${p.phase.name}-'
          '${w.timedOut}-${w.checksDone}',
      _ => p.step.name,
    };
  }

  Widget _bodyOf(CleanWizard w, TvOps ops) {
    final p = w.progress;
    switch (p.step) {
      case WizardStep.restorePoint:
        return _RestorePoint(wizard: w);
      case WizardStep.choose:
        return _chooseBody(w, ops);
      case WizardStep.done:
        return _Done(progress: p, onDone: _finish);
      case WizardStep.batch:
        final b = p.batch!;
        final next = p.isLastBatch ? null : p.batches[p.current + 1].title;
        return switch (p.phase) {
          BatchPhase.disabling => _Disabling(wizard: w, batch: b),
          BatchPhase.saving => _Saving(wizard: w, batch: b),
          BatchPhase.restart => _Restart(wizard: w, batch: b),
          BatchPhase.restarting => _Restarting(wizard: w),
          BatchPhase.checking || BatchPhase.failed => _Checks(
              wizard: w,
              batch: b,
              next: next,
              guard: ref.watch(hasAgentProvider),
            ),
          BatchPhase.undone => _Undone(wizard: w, batch: b, next: next),
        };
    }
  }

  Widget _chooseBody(CleanWizard w, TvOps ops) {
    final status = ref.watch(cleanStatusProvider);
    return status.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _Page(
        title: const Text('Couldn\'t read the TV'),
        lead: 'Is it on and on this Wi-Fi?',
        primary: PrimaryButton(
          label: 'Try again',
          icon: Icons.refresh_rounded,
          onPressed: () => ref.invalidate(cleanStatusProvider),
        ),
      ),
      data: (s) {
        if (s == null) return const _Offline();
        final groups = wizardGroups(ops, s);
        final showing = [
          for (final l in groups.values)
            for (final i in l)
              if (i.state == CleanState.showing) i.pkg,
        ];
        if (showing.isEmpty) return _AllTidy(onDone: _finish);
        final selected = (_selected ??= defaultSelection(groups))
            .where(showing.contains)
            .toSet();
        final pending = [
          for (final e in groups.entries)
            WizardBatch(
              group: e.key.name,
              title: e.key.title,
              pkgs: [
                for (final i in e.value)
                  if (i.state == CleanState.showing) i.pkg,
              ],
            ),
        ];
        return _Choose(
          groups: groups,
          selected: selected,
          onToggle: (pkg, on) {
            final next = {...selected};
            on ? next.add(pkg) : next.remove(pkg);
            setState(() => _selected = next);
            unawaited(w.select(next));
          },
          onStart: selected.isEmpty
              ? null
              : () => w.start(planBatches(pending, selected)),
        );
      },
    );
  }
}

/// Step change: a fade with a short 21 px slide (320 ms, easeOutCubic).
Widget _slide(Widget child, Animation<double> a) => FadeTransition(
      opacity: a,
      child: AnimatedBuilder(
        animation: a,
        builder: (context, child) => Transform.translate(
          offset: Offset(
            Motion.reduced(context) ? 0 : Gap.f21 * (1 - a.value),
            0,
          ),
          child: child,
        ),
        child: child,
      ),
    );

class _Header extends StatelessWidget {
  final int index;
  final int count;
  const _Header({required this.index, required this.count});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Gap.gutter),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Clean up · Step ${index + 1} of $count',
              style: text.labelMedium,
            ),
          ),
          StepIndicator(count: count, index: index),
        ],
      ),
    );
  }
}

/// One wizard screen: optional Tubby, a display title, one line of lead
/// (more behind ⓘ), the content, and the actions pinned at the bottom.
class _Page extends StatelessWidget {
  final Widget? hero;
  final Widget title;
  final String? lead;
  final InfoButton? info;
  final List<Widget> content;
  final Widget? primary;
  final Widget? secondary;

  const _Page({
    super.key,
    required this.title,
    this.hero,
    this.lead,
    this.info,
    this.content = const [],
    this.primary,
    this.secondary,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              Gap.gutter,
              Gap.section,
              Gap.gutter,
              Gap.related,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (hero != null) ...[
                  Center(child: hero),
                  const SizedBox(height: Gap.related),
                ],
                Semantics(
                  header: true,
                  liveRegion: true,
                  child: DefaultTextStyle.merge(
                    textAlign: TextAlign.center,
                    style: text.headlineLarge,
                    child: title,
                  ),
                ),
                if (lead != null) ...[
                  const SizedBox(height: Gap.f8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          lead!,
                          textAlign: TextAlign.center,
                          style: text.bodyLarge,
                        ),
                      ),
                      if (info != null) info!,
                    ],
                  ),
                ],
                if (content.isNotEmpty) ...[
                  const SizedBox(height: Gap.section),
                  ...content,
                ],
              ],
            ),
          ),
        ),
        if (primary != null || secondary != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Gap.gutter,
              Gap.inside,
              Gap.gutter,
              Gap.related,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (primary != null) primary!,
                if (primary != null && secondary != null)
                  const SizedBox(height: Gap.f8),
                if (secondary != null) Center(child: secondary),
              ],
            ),
          ),
      ],
    );
  }
}

String _plainError(Object e) {
  final s = '$e';
  if (s.contains('RestartTooSoon')) return 'The TV is still saving';
  if (s.contains('didn\'t restart')) return 'The TV didn\'t restart';
  return 'Is the TV on and on this Wi-Fi?';
}

class _ErrorRow extends StatelessWidget {
  final Object error;
  const _ErrorRow(this.error);

  @override
  Widget build(BuildContext context) => RowList(
        key: const Key('wizard-error'),
        edges: true,
        children: [
          StatusRow(
            tone: Tone.bad,
            icon: Icons.wifi_off_rounded,
            title: 'Couldn\'t reach the TV',
            detail: _plainError(error),
          ),
        ],
      );
}

// ── step 1 ──

class _RestorePoint extends StatelessWidget {
  final CleanWizard wizard;
  const _RestorePoint({required this.wizard});

  @override
  Widget build(BuildContext context) {
    final bt = context.bt;
    final err = wizard.error;
    return _Page(
      key: const Key('wizard-restore'),
      hero: const Tubby(mood: TubbyMood.cleaning, size: Sizes.tubbyLarge),
      title: const Text('First, a restore point'),
      lead: 'You can undo all of this anytime.',
      content: [
        if (err != null) ...[
          _ErrorRow(err),
          const SizedBox(height: Gap.related),
        ],
        RowList(
          edges: true,
          children: [
            ListRow(
              icon: Icons.layers_rounded,
              iconColor: bt.muted,
              title: 'One group at a time',
            ),
            ListRow(
              icon: Icons.restart_alt_rounded,
              iconColor: bt.muted,
              title: 'A restart after each, so it sticks',
            ),
            ListRow(
              icon: Icons.undo_rounded,
              iconColor: bt.muted,
              title: 'Switched off, never deleted',
            ),
          ],
        ),
      ],
      primary: PrimaryButton(
        key: const Key('wizard-restore-save'),
        label: wizard.busy
            ? 'Saving…'
            : err == null
                ? 'Save restore point'
                : 'Try again',
        icon: Icons.bookmark_add_rounded,
        onPressed: wizard.busy ? null : wizard.captureRestorePoint,
      ),
    );
  }
}

// ── step 2 ──

class _Choose extends StatelessWidget {
  final Map<CleanGroup, List<CleanItem>> groups;
  final Set<String> selected;
  final void Function(String pkg, bool on) onToggle;
  final VoidCallback? onStart;

  const _Choose({
    required this.groups,
    required this.selected,
    required this.onToggle,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    final n = selected.length;
    final batches = groups.entries
        .where((e) => e.value.any((i) => selected.contains(i.pkg)))
        .length;
    return _Page(
      key: const Key('wizard-choose'),
      title: const Text('Pick what to tidy'),
      lead: 'Ticked apps are switched off, group by group.',
      content: [
        for (final (gi, e) in groups.entries.indexed) ...[
          GroupHeading(e.key.title, first: gi == 0),
          RowList(
            key: Key('wizard-group-${e.key.name}'),
            children: [
              for (final i in e.value)
                _PickRow(
                  key: Key('wizard-pick-${i.pkg}'),
                  item: i,
                  chosen: selected.contains(i.pkg),
                  onChanged: (v) => onToggle(i.pkg, v),
                ),
            ],
          ),
        ],
      ],
      primary: PrimaryButton(
        key: const Key('wizard-start'),
        label: n == 0 ? 'Pick an app' : 'Tidy $n app${n == 1 ? '' : 's'}',
        note: n == 0 ? null : '$batches group${batches == 1 ? '' : 's'}',
        icon: Icons.auto_awesome_rounded,
        onPressed: onStart,
      ),
    );
  }
}

class _PickRow extends StatelessWidget {
  final CleanItem item;
  final bool chosen;
  final ValueChanged<bool> onChanged;

  const _PickRow({
    super.key,
    required this.item,
    required this.chosen,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final bt = context.bt;
    final done = item.state == CleanState.tidied;
    if (done) {
      return ListRow(
        icon: Icons.check_rounded,
        iconColor: StatusColors.of(context).ok,
        title: appLabel(item.pkg),
        subtitle: 'Already tidied away',
        dim: true,
      );
    }
    return Semantics(
      checked: chosen,
      child: ListRow(
        icon: chosen ? Icons.check_box_rounded : Icons.check_box_outline_blank,
        iconColor: chosen ? bt.coralInk : bt.faint,
        title: appLabel(item.pkg),
        subtitle: _explain(item),
        chevron: false,
        onTap: () => onChanged(!chosen),
      ),
    );
  }
}

class _AllTidy extends StatelessWidget {
  final VoidCallback onDone;
  const _AllTidy({required this.onDone});

  @override
  Widget build(BuildContext context) => _Page(
        key: const Key('wizard-all-tidy'),
        hero: const Tubby(
          mood: TubbyMood.calm,
          size: Sizes.tubbyLarge,
          beaming: true,
        ),
        title: const Text('Already tidy'),
        lead: 'Every app on the list is off.',
        primary: PrimaryButton(label: 'Done', onPressed: onDone),
      );
}

// ── step 3: a batch ──

class _Disabling extends StatelessWidget {
  final CleanWizard wizard;
  final WizardBatch batch;
  const _Disabling({required this.wizard, required this.batch});

  @override
  Widget build(BuildContext context) {
    final err = wizard.error;
    final n = batch.pkgs.length;
    return _Page(
      key: const Key('wizard-disabling'),
      hero: const Tubby(mood: TubbyMood.cleaning, size: Sizes.tubbyLarge),
      title: Text('Tidying ${batch.title}'),
      lead: 'Switching off $n app${n == 1 ? '' : 's'}.',
      content: [
        if (err != null) ...[
          _ErrorRow(err),
          const SizedBox(height: Gap.related),
        ],
        RowList(
          edges: true,
          children: [
            for (final (i, p) in batch.pkgs.indexed)
              StaggerIn(
                index: i,
                child: _AppLine(pkg: p, result: wizard.live[p]),
              ),
          ],
        ),
      ],
      primary: err == null
          ? null
          : PrimaryButton(
              key: const Key('wizard-retry'),
              label: 'Try again',
              icon: Icons.refresh_rounded,
              onPressed: wizard.runBatch,
            ),
    );
  }
}

class _AppLine extends StatelessWidget {
  final String pkg;
  final bool? result;
  final String okText;
  final String badText;

  const _AppLine({
    required this.pkg,
    required this.result,
    this.okText = 'Off',
    this.badText = 'Didn\'t switch off',
  });

  @override
  Widget build(BuildContext context) {
    final r = result;
    return StatusRow(
      key: Key('wizard-app-$pkg'),
      tone: r == null ? Tone.idle : (r ? Tone.ok : Tone.bad),
      icon: r == null
          ? Icons.radio_button_unchecked
          : (r ? Icons.check_rounded : Icons.close_rounded),
      title: appLabel(pkg),
      detail: r == null ? 'Waiting' : (r ? okText : badText),
    );
  }
}

class _Saving extends StatelessWidget {
  final CleanWizard wizard;
  final WizardBatch batch;
  const _Saving({required this.wizard, required this.batch});

  @override
  Widget build(BuildContext context) {
    final bt = context.bt;
    final total = wizard.timing.save.inMilliseconds;
    final left = wizard.saveLeft.inMilliseconds;
    final done = total == 0 ? 1.0 : 1 - left / total;
    return _Page(
      key: const Key('wizard-saving'),
      hero: const Tubby(mood: TubbyMood.calm, size: Sizes.tubbyLarge),
      title: const Text('Saving on the TV'),
      lead: 'Keep it on for a minute.',
      info: const InfoButton(
        title: 'Why wait?',
        body: 'The TV writes app changes to its memory a little later. If '
            'it restarts sooner, the apps come back. After a minute the '
            'change is safe.',
      ),
      content: [
        Center(
          child: Semantics(
            liveRegion: true,
            label: '${(left / 1000).ceil()} seconds left',
            excludeSemantics: true,
            child: Text(
              countdown(wizard.saveLeft),
              key: const Key('wizard-save-left'),
              style: Fonts.bricolage(
                TypeSize.hero,
                color: bt.ink,
                tabularFigures: true,
              ),
            ),
          ),
        ),
        const SizedBox(height: Gap.inside),
        ThinProgress(value: done, color: bt.mint),
        const SizedBox(height: Gap.related),
        RowList(
          edges: true,
          children: [
            for (final p in batch.pkgs)
              _AppLine(pkg: p, result: wizard.live[p] ?? true),
          ],
        ),
      ],
    );
  }
}

class _Restart extends StatelessWidget {
  final CleanWizard wizard;
  final WizardBatch batch;
  const _Restart({required this.wizard, required this.batch});

  @override
  Widget build(BuildContext context) {
    final err = wizard.error;
    return _Page(
      key: const Key('wizard-restart'),
      hero: const Tubby(mood: TubbyMood.calm, size: Sizes.tubbyLarge),
      title: const Text('Restart the TV'),
      lead: 'Recommended: it makes the change stick.',
      info: const InfoButton(
        title: 'Why restart?',
        body: 'A restart proves the TV keeps the change and still works. It '
            'takes about two minutes, then boretube checks the TV for you.',
      ),
      content: [
        if (err != null) _ErrorRow(err),
      ],
      primary: PrimaryButton(
        key: const Key('wizard-restart-tv'),
        label: wizard.busy
            ? 'Restarting…'
            : err == null
                ? 'Restart TV'
                : 'Try again',
        icon: Icons.restart_alt_rounded,
        note: wizard.busy ? null : 'about 2 min',
        onPressed: wizard.busy ? null : wizard.restart,
      ),
      secondary: TextButton(
        key: const Key('wizard-skip-restart'),
        onPressed: wizard.busy ? null : wizard.skipRestart,
        child: const Text('Skip restart'),
      ),
    );
  }
}

class _Restarting extends StatelessWidget {
  final CleanWizard wizard;
  const _Restarting({required this.wizard});

  @override
  Widget build(BuildContext context) {
    final bt = context.bt;
    final text = Theme.of(context).textTheme;
    final late = wizard.timedOut;
    final total = wizard.timing.timeout.inMilliseconds;
    return _Page(
      key: Key(late ? 'wizard-restart-late' : 'wizard-restarting'),
      hero: PulsingIcon(
        size: Sizes.tubbyLarge,
        color: bt.sky,
        child: const Tubby(mood: TubbyMood.asleep, size: Sizes.tubbyLarge),
      ),
      title: Text(late ? 'The TV is taking a while' : 'Restarting the TV'),
      lead: late
          ? 'Is it on, and on this Wi-Fi?'
          : 'Waiting for it to come back.',
      info: late
          ? const InfoButton(
              title: 'Still restarting?',
              body: 'If the TV shows its logo, give it another minute. If '
                  'the screen is dark, switch it on with the remote. If '
                  'the router restarted too, wait for the Wi-Fi.',
            )
          : null,
      content: [
        Center(
          child: Text(
            countdown(wizard.waited),
            key: const Key('wizard-waited'),
            style: Fonts.bricolage(
              TypeSize.hero,
              color: late ? bt.muted : bt.ink,
              tabularFigures: true,
            ),
          ),
        ),
        const SizedBox(height: Gap.inside),
        ThinProgress(
          value: total == 0 ? 1 : wizard.waited.inMilliseconds / total,
          color: late ? bt.sun : bt.sky,
        ),
        const SizedBox(height: Gap.f8),
        Text(
          late ? 'Still looking every few seconds' : 'Usually about 2 minutes',
          textAlign: TextAlign.center,
          style: text.bodySmall,
        ),
      ],
      primary: late
          ? PrimaryButton(
              key: const Key('wizard-keep-waiting'),
              label: 'Keep waiting',
              icon: Icons.hourglass_bottom_rounded,
              onPressed: wizard.keepWaiting,
            )
          : null,
      secondary: late
          ? TextButton(
              key: const Key('wizard-check-now'),
              onPressed: wizard.checkAgain,
              child: const Text('Check it now'),
            )
          : null,
    );
  }
}

String _checkTitle(WizardCheckId id, WizardBatch b, bool restarted) =>
    switch (id) {
      WizardCheckId.appsOff => '${b.title} still off',
      WizardCheckId.connected =>
        restarted ? 'TV back on Wi-Fi' : 'TV still on Wi-Fi',
      WizardCheckId.home => 'Home opens your home screen',
      WizardCheckId.guard => 'TV Guard running',
    };

class _Checks extends StatelessWidget {
  final CleanWizard wizard;
  final WizardBatch batch;
  final String? next;
  final bool guard;

  const _Checks({
    required this.wizard,
    required this.batch,
    required this.next,
    required this.guard,
  });

  @override
  Widget build(BuildContext context) {
    final p = wizard.progress;
    final failed = p.phase == BatchPhase.failed;
    final running = !failed && !wizard.checksDone;
    final restarted = !p.restartSkipped;
    final ids = p.checks.isNotEmpty
        ? [for (final c in p.checks) c.id]
        : [
            WizardCheckId.appsOff,
            WizardCheckId.connected,
            WizardCheckId.home,
            if (guard) WizardCheckId.guard,
          ];
    final byId = {for (final c in p.checks) c.id: c};
    final err = wizard.error;
    return _Page(
      key: Key(
        failed
            ? 'wizard-checks-failed'
            : running
                ? 'wizard-checking'
                : 'wizard-checks-passed',
      ),
      hero: Tubby(
        mood: TubbyMood.calm,
        size: Sizes.tubbyLarge,
        beaming: !running && !failed,
      ),
      title: Text(
        failed
            ? 'Something\'s off'
            : running
                ? 'Checking the TV'
                : 'All good',
      ),
      lead: failed
          ? 'Nothing else changes until you choose.'
          : running
              ? 'A few quick looks.'
              : '${batch.title} stayed tidy.',
      content: [
        if (err != null) ...[
          _ErrorRow(err),
          const SizedBox(height: Gap.related),
        ],
        RowList(
          key: const Key('wizard-checks'),
          edges: true,
          children: [
            for (final (i, id) in ids.indexed)
              StaggerIn(
                index: i,
                child: _CheckRow(
                  title: _checkTitle(id, batch, restarted),
                  check: byId[id],
                  id: id,
                ),
              ),
          ],
        ),
      ],
      primary: running
          ? null
          : failed
              ? PrimaryButton(
                  key: const Key('wizard-undo'),
                  label: wizard.busy ? 'Putting back…' : 'Undo this batch',
                  icon: Icons.undo_rounded,
                  onPressed: wizard.busy ? null : wizard.undoBatch,
                )
              : PrimaryButton(
                  key: const Key('wizard-next'),
                  label: next == null ? 'Finish' : 'Next: $next',
                  icon: next == null
                      ? Icons.check_rounded
                      : Icons.arrow_forward_rounded,
                  onPressed: wizard.next,
                ),
      secondary: failed
          ? TextButton(
              key: const Key('wizard-keep-going'),
              onPressed: wizard.busy ? null : wizard.keepGoing,
              child: const Text('Keep going'),
            )
          : null,
    );
  }
}

class _CheckRow extends StatelessWidget {
  final String title;
  final WizardCheck? check;
  final WizardCheckId id;

  const _CheckRow({required this.title, required this.check, required this.id});

  @override
  Widget build(BuildContext context) {
    final c = check;
    return Semantics(
      label: c == null
          ? '$title: checking'
          : '$title: ${c.ok ? 'passed' : 'failed'}',
      excludeSemantics: true,
      child: StatusRow(
        key: Key('wizard-check-${id.name}'),
        tone: c == null ? Tone.idle : (c.ok ? Tone.ok : Tone.bad),
        icon: c == null
            ? Icons.radio_button_unchecked
            : (c.ok ? Icons.check_rounded : Icons.close_rounded),
        title: title,
        detail: c == null
            ? 'Checking…'
            : c.ok
                ? null
                : c.detail,
      ),
    );
  }
}

class _Undone extends StatelessWidget {
  final CleanWizard wizard;
  final WizardBatch batch;
  final String? next;

  const _Undone({
    required this.wizard,
    required this.batch,
    required this.next,
  });

  @override
  Widget build(BuildContext context) {
    final r = wizard.progress.undoResult;
    final all = r.values.every((v) => v);
    return _Page(
      key: const Key('wizard-undone'),
      hero: const Tubby(mood: TubbyMood.calm, size: Sizes.tubbyLarge),
      title: Text(all ? 'Put back' : 'Mostly put back'),
      lead: all
          ? '${batch.title} are back the way they were.'
          : 'Switch the rest on in Apps on your TV.',
      content: [
        if (r.isNotEmpty)
          RowList(
            edges: true,
            children: [
              for (final e in r.entries)
                _AppLine(
                  pkg: e.key,
                  result: e.value,
                  okText: 'Back on',
                  badText: 'Still off',
                ),
            ],
          ),
      ],
      primary: PrimaryButton(
        key: const Key('wizard-next'),
        label: next == null ? 'Finish' : 'Next: $next',
        icon: next == null ? Icons.check_rounded : Icons.arrow_forward_rounded,
        onPressed: wizard.next,
      ),
    );
  }
}

// ── step 5 ──

class _Done extends StatelessWidget {
  final WizardProgress progress;
  final VoidCallback onDone;
  const _Done({required this.progress, required this.onDone});

  @override
  Widget build(BuildContext context) {
    final n = progress.tidiedCount;
    return _Page(
      key: const Key('wizard-done'),
      hero: const Tubby(
        mood: TubbyMood.cleaning,
        size: Sizes.tubbyLarge + Sizes.tubby,
        beaming: true,
      ),
      title: Text(n == 1 ? '1 app tidied away' : '$n apps tidied away'),
      lead: 'Every change is in History.',
      content: [
        RowList(
          edges: true,
          children: [
            for (final (i, b) in progress.batches.indexed)
              CheckLine(
                progress.undone.contains(i)
                    ? '${b.title} · put back'
                    : '${b.title} · ${b.pkgs.length} '
                        'app${b.pkgs.length == 1 ? '' : 's'}',
                done: !progress.undone.contains(i),
                minHeight: Sizes.row,
              ),
          ],
        ),
      ],
      primary: PrimaryButton(
        key: const Key('wizard-finish'),
        label: 'Done',
        onPressed: onDone,
      ),
    );
  }
}

// ── other TVs ──

class _Generic extends StatelessWidget {
  final VoidCallback onApps;
  const _Generic({required this.onApps});

  @override
  Widget build(BuildContext context) => _Page(
        key: const Key('wizard-generic'),
        hero: const Tubby(mood: TubbyMood.calm, size: Sizes.tubbyLarge),
        title: const Text('No tested list for this TV yet'),
        lead: 'boretube only tidies TVs it has checked app by app.',
        info: const InfoButton(
          title: 'Why not guess?',
          body: 'Switching off the wrong app can break the home screen or '
              'the remote. You can still switch single apps off yourself, '
              'and undo them anytime.',
        ),
        primary: PrimaryButton(
          key: const Key('wizard-open-apps'),
          label: 'Apps on your TV',
          icon: Icons.grid_view_rounded,
          onPressed: onApps,
        ),
      );
}

class _Offline extends StatelessWidget {
  const _Offline();

  @override
  Widget build(BuildContext context) => const _Page(
        key: Key('wizard-offline'),
        hero: Tubby(mood: TubbyMood.asleep, size: Sizes.tubbyLarge),
        title: Text('Connect to the TV first'),
        lead: 'Clean up needs Home mode on this TV.',
      );
}
