import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../discovery/subnet_sweep.dart';
import '../providers/security_providers.dart';
import '../providers/tv_providers.dart';
import '../security/app_lock.dart';
import '../tv/capabilities.dart';
import '../tv/tv.dart';
import '../ui/components.dart';
import '../ui/tokens.dart';
import 'adb_guide_screen.dart';
import 'lock_screen.dart';
import 'pin_entry.dart';
import 'shell_screen.dart';
import 'tv_address_dialog.dart';

enum _Step { welcome, find, connect, adb, pin, done }

/// First run (or "Add TV"): Find → Connect → Unlock ADB → PIN → done.
class OnboardingScreen extends ConsumerStatefulWidget {
  /// From "Add TV": no welcome, no PIN step.
  final bool addMode;

  const OnboardingScreen({super.key, this.addMode = false});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingState();
}

class _OnboardingState extends ConsumerState<OnboardingScreen> {
  late final List<_Step> _steps;
  int _i = 0;
  Tv? _picked;

  @override
  void initState() {
    super.initState();
    final needsPin = ref.read(appLockProvider).phase == LockPhase.setup;
    _steps = [
      if (!widget.addMode) _Step.welcome,
      _Step.find,
      _Step.connect,
      _Step.adb,
      if (needsPin) _Step.pin,
      _Step.done,
    ];
  }

  _Step get _step => _steps[_i];

  void _next() => setState(() => _i = (_i + 1).clamp(0, _steps.length - 1));

  void _skipTo(_Step s) => setState(() => _i = _steps.indexOf(s));

  void _back() {
    if (_i > 0 && _step != _Step.done) {
      setState(() => _i--);
    } else if (widget.addMode) {
      context.pop();
    }
  }

  void _finish() {
    if (widget.addMode && context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_step == _Step.welcome) {
      return _Welcome(onStart: _next);
    }
    final visible = _steps.where((s) => s != _Step.welcome).toList();
    final idx = visible.indexOf(_step);
    final text = Theme.of(context).textTheme;
    final (title, subtitle) = switch (_step) {
      _Step.find => ('Find your TV', 'TVs on this Wi-Fi show up here.'),
      _Step.connect => ('Checking the TV', 'What can Boretube do here?'),
      _Step.adb => ('Unlock with ADB', 'Optional, but recommended.'),
      _Step.pin => ('Set a parent PIN', 'So only grown-ups open Boretube.'),
      _ => ('', ''),
    };
    final showBack =
        (_i > 0 && _step != _Step.done) || (widget.addMode && _i == 0);
    return PopScope(
      canPop: widget.addMode && _i == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leading: showBack
              ? IconButton(
                  tooltip: 'Back',
                  icon: Icon(
                    widget.addMode && _i == 0
                        ? Icons.close_rounded
                        : Icons.arrow_back_rounded,
                  ),
                  onPressed: _back,
                )
              : null,
          centerTitle: true,
          title: StepIndicator(count: visible.length, index: idx),
        ),
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_step != _Step.done && _step != _Step.pin)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Gap.page,
                    Gap.sm,
                    Gap.page,
                    Gap.md,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: text.headlineMedium),
                      const SizedBox(height: Gap.xs),
                      Text(subtitle, style: text.bodyMedium),
                    ],
                  ),
                ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 280),
                  transitionBuilder: (child, a) => FadeTransition(
                    opacity: a,
                    child: SlideTransition(
                      position: Tween(
                        begin: const Offset(0.04, 0),
                        end: Offset.zero,
                      ).animate(a),
                      child: child,
                    ),
                  ),
                  child: KeyedSubtree(
                    key: ValueKey(_step),
                    child: _body(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body() {
    switch (_step) {
      case _Step.welcome:
        return const SizedBox.shrink();
      case _Step.find:
        return FindTvsStep(
          onPicked: (tv) {
            _picked = tv;
            _next();
          },
        );
      case _Step.connect:
        return _ConnectStep(
          tv: _picked!,
          onAdb: _next,
          onSkip: () => _skipTo(_steps[_steps.indexOf(_Step.adb) + 1]),
        );
      case _Step.adb:
        return AdbGuide(onDone: _next, onSkip: _next);
      case _Step.pin:
        return Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(Gap.page),
            child: PinSetup(
              onDone: (pin) async {
                await ref.read(appLockProvider.notifier).setPin(pin);
                if (mounted) _next();
              },
            ),
          ),
        );
      case _Step.done:
        return _Done(onFinish: _finish);
    }
  }
}

class _Welcome extends StatelessWidget {
  final VoidCallback onStart;
  const _Welcome({required this.onStart});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    const points = [
      (Icons.volume_off_rounded, 'Mute, stop or pause the TV from here'),
      (Icons.lock_clock_rounded, 'Timed locks for apps and volume'),
      (Icons.health_and_safety_rounded, 'Keeps the TV clean after updates'),
    ];
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.alphaBlend(
                scheme.primary.withValues(alpha: 0.22),
                scheme.surface,
              ),
              scheme.surface,
              scheme.surface,
            ],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, c) => SingleChildScrollView(
              padding: const EdgeInsets.all(Gap.xl),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: c.maxHeight - 48),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: Gap.xxl),
                        const BrandMark(size: 72),
                        const SizedBox(height: Gap.xl),
                        Text(
                          'A calm remote\nfor the family TV.',
                          style: text.displaySmall,
                        ),
                        const SizedBox(height: Gap.md),
                        Text(
                          'Boretube helps when the cartoons won\'t stop '
                          'and the volume keeps creeping up.',
                          style: text.bodyLarge?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: Gap.xl),
                        for (final (icon, label) in points)
                          Padding(
                            padding: const EdgeInsets.only(bottom: Gap.md),
                            child: Row(
                              children: [
                                IconBadge(
                                  icon: icon,
                                  color: scheme.primary,
                                  size: 36,
                                ),
                                const SizedBox(width: Gap.md),
                                Expanded(
                                  child: Text(label, style: text.bodyMedium),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: Gap.xl),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        key: const Key('onboarding-start'),
                        onPressed: onStart,
                        child: const Text('Get started'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Live discovery results with sweep progress and manual entry.
class FindTvsStep extends ConsumerStatefulWidget {
  final ValueChanged<Tv> onPicked;
  const FindTvsStep({super.key, required this.onPicked});

  @override
  ConsumerState<FindTvsStep> createState() => _FindTvsStepState();
}

class _FindTvsStepState extends ConsumerState<FindTvsStep> {
  StreamSubscription<List<Tv>>? _sub;
  List<Tv> _found = const [];
  bool _searching = false;
  SweepEvent? _progress;

  @override
  void initState() {
    super.initState();
    _scan();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _scan() {
    _sub?.cancel();
    setState(() {
      _searching = true;
      _progress = null;
    });
    _sub = ref
        .read(discoveryServiceProvider)
        .discover(
          timeout: const Duration(seconds: 15),
          onSweepProgress: (e) {
            if (mounted) setState(() => _progress = e);
          },
        )
        .listen(
          (list) {
            if (mounted) setState(() => _found = list);
          },
          onDone: () {
            if (mounted) setState(() => _searching = false);
          },
          onError: (Object _) {
            if (mounted) setState(() => _searching = false);
          },
        );
  }

  Future<void> _manual() async {
    final tv = await showTvAddressDialog(context);
    if (tv != null) widget.onPicked(tv);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final saved = {for (final t in ref.watch(savedTvsProvider)) t.id};
    final p = _progress;
    return ListView(
      padding: const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.xl),
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: _searching
              ? Column(
                  key: const ValueKey('searching'),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        minHeight: 4,
                        value: p == null || p.total == 0
                            ? null
                            : p.scanned / p.total,
                      ),
                    ),
                    const SizedBox(height: Gap.sm),
                    Text(
                      p == null || p.total == 0
                          ? 'Looking on your Wi-Fi…'
                          : 'Looking on your Wi-Fi… '
                              '${p.scanned}/${p.total} addresses',
                      style: text.bodySmall,
                    ),
                  ],
                )
              : Align(
                  key: const ValueKey('done'),
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _scan,
                    icon: const Icon(Icons.refresh_rounded),
                    label: Text(
                      _found.isEmpty ? 'Search again' : 'Search again',
                    ),
                  ),
                ),
        ),
        const SizedBox(height: Gap.lg),
        if (_found.isEmpty && !_searching)
          const InfoCard(
            child: EmptyState(
              icon: Icons.tv_off_rounded,
              title: 'No TVs found',
              message: 'Make sure the TV is on and this phone is on the same '
                  'Wi-Fi. Or enter its address below.',
            ),
          )
        else if (_found.isEmpty)
          const SkeletonCard(rows: 2)
        else
          for (final tv in _found) ...[
            _FoundTvCard(
              tv: tv,
              saved: saved.contains(tv.id),
              onTap: () => widget.onPicked(tv),
            ),
            const SizedBox(height: Gap.md),
          ],
        const SizedBox(height: Gap.sm),
        OutlinedButton.icon(
          key: const Key('enter-ip'),
          onPressed: _manual,
          icon: const Icon(Icons.keyboard_rounded),
          label: const Text('Enter IP manually'),
        ),
      ],
    );
  }
}

class _FoundTvCard extends StatelessWidget {
  final Tv tv;
  final bool saved;
  final VoidCallback onTap;

  const _FoundTvCard({
    required this.tv,
    required this.saved,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final sub = [
      if (tv.manufacturer.isNotEmpty || tv.model.isNotEmpty)
        '${tv.manufacturer} ${tv.model}'.trim(),
      tv.ip,
    ].join(' · ');
    return InfoCard(
      onTap: onTap,
      child: Row(
        children: [
          IconBadge(icon: Icons.tv_rounded, color: scheme.primary, size: 48),
          const SizedBox(width: Gap.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tv.name, style: text.titleMedium),
                const SizedBox(height: 2),
                Text(sub, style: text.bodySmall),
                if (saved) ...[
                  const SizedBox(height: Gap.sm),
                  const TagChip('Already saved', tone: Tone.ok),
                ],
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
        ],
      ),
    );
  }
}

class _ConnectStep extends ConsumerStatefulWidget {
  final Tv tv;
  final VoidCallback onAdb;
  final VoidCallback onSkip;

  const _ConnectStep({
    required this.tv,
    required this.onAdb,
    required this.onSkip,
  });

  @override
  ConsumerState<_ConnectStep> createState() => _ConnectStepState();
}

class _ConnectStepState extends ConsumerState<_ConnectStep> {
  CapabilityReport? _report;

  @override
  void initState() {
    super.initState();
    // Not during initState: probing updates providers.
    Future.microtask(_probe);
  }

  Future<void> _probe() async {
    if (!mounted) return;
    setState(() => _report = null);
    final tv = widget.tv.copyWith(lastSeen: DateTime.now());
    final report = await ref
        .read(capabilityProvider.notifier)
        .probe(tv);
    if (!mounted || report == null) return;
    await ref.read(tvStoreProvider).setActive(report.tv.id);
    if (mounted) setState(() => _report = report);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final r = _report;
    final hasAdb = r?.capabilities.contains(TvCapability.adb) ?? false;
    return ListView(
      padding: const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.xl),
      children: [
        InfoCard(
          child: Row(
            children: [
              IconBadge(
                icon: Icons.tv_rounded,
                color: Theme.of(context).colorScheme.primary,
                size: 48,
              ),
              const SizedBox(width: Gap.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.tv.name, style: text.titleMedium),
                    Text(widget.tv.ip, style: text.bodySmall),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: Gap.md),
        GroupCard(
          children: [
            for (final c in TvCapability.values)
              StatusRow(
                tone: r == null
                    ? Tone.idle
                    : r.capabilities.contains(c)
                        ? Tone.ok
                        : Tone.idle,
                icon: r == null
                    ? Icons.more_horiz_rounded
                    : r.capabilities.contains(c)
                        ? Icons.check_rounded
                        : Icons.close_rounded,
                title: capabilityTitle(c),
                detail: capabilityMeaning(c),
                detailLines: 2,
                trailing: r == null
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : null,
              ),
          ],
        ),
        const SizedBox(height: Gap.xl),
        if (r != null && !hasAdb) ...[
          FilledButton.icon(
            onPressed: widget.onAdb,
            icon: const Icon(Icons.lock_open_rounded),
            label: const Text('Unlock ADB (recommended)'),
          ),
          const SizedBox(height: Gap.sm),
          TextButton(
            onPressed: widget.onSkip,
            child: const Text('Skip for now'),
          ),
        ] else if (r != null)
          FilledButton(
            onPressed: widget.onSkip,
            child: const Text('Continue'),
          ),
        if (r != null)
          TextButton.icon(
            onPressed: _probe,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Check again'),
          ),
      ],
    );
  }
}

class _Done extends ConsumerWidget {
  final VoidCallback onFinish;
  const _Done({required this.onFinish});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final tv = ref.watch(activeTvProvider);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Gap.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconBadge(
              icon: Icons.celebration_rounded,
              color: StatusColors.of(context).ok,
              size: 96,
            ),
            const SizedBox(height: Gap.xl),
            Text('You\'re all set', style: text.headlineMedium),
            const SizedBox(height: Gap.sm),
            Text(
              tv == null
                  ? 'Boretube is ready.'
                  : '${tv.name} is ready to be bored.',
              style: text.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: Gap.xxl),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onFinish,
                child: const Text('Open Boretube'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
