import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../actions/actions_service.dart';
import '../discovery/subnet_sweep.dart';
import '../providers/security_providers.dart';
import '../providers/tv_providers.dart';
import '../providers/ui_providers.dart';
import '../security/app_lock.dart';
import '../tv/tv.dart';
import '../ui/celebrate.dart';
import '../ui/components.dart';
import '../ui/controls.dart';
import '../ui/tokens.dart';
import '../ui/tubby.dart';
import 'pin_entry.dart';
import 'tv_address_dialog.dart';

enum _Step { welcome, find, firstWin, pin, goals }

/// First run: Welcome → Find TV → First win → Parent PIN → Goals → Home.
/// "Add a TV" runs Find → First win only.
class OnboardingScreen extends ConsumerStatefulWidget {
  /// From "Add a TV": no welcome, PIN or goals.
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
      _Step.firstWin,
      if (needsPin) _Step.pin,
      if (!widget.addMode) _Step.goals,
    ];
  }

  _Step get _step => _steps[_i];

  void _next() {
    if (_i == _steps.length - 1) return _finish();
    setState(() => _i++);
  }

  void _back() {
    if (_i > 0) {
      setState(() => _i--);
    } else if (widget.addMode) {
      context.pop();
    }
  }

  void _finish() {
    if (widget.addMode && context.canPop()) {
      context.pop();
    } else {
      ref.read(shellTabProvider.notifier).state = 0;
      // Outside the app router (tests, previews) just close.
      if (GoRouter.maybeOf(context) == null) {
        Navigator.of(context).maybePop();
      } else {
        context.go('/');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_step == _Step.welcome) return _Welcome(onStart: _next);
    final visible = _steps.where((s) => s != _Step.welcome).toList();
    final idx = visible.indexOf(_step);
    final canBack = _i > 0 && _step != _Step.pin && _step != _Step.goals;
    final showBack = canBack || (widget.addMode && _i == 0);
    return PopScope(
      canPop: widget.addMode && _i == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && canBack) _back();
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leading: showBack
              ? IconButton(
                  tooltip: widget.addMode && _i == 0 ? 'Close' : 'Back',
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
          top: false,
          child: AnimatedSwitcher(
            duration: Motion.of(context, Motion.sheet),
            switchInCurve: Motion.enter,
            switchOutCurve: Motion.exit,
            transitionBuilder: stepTransition,
            child: KeyedSubtree(key: ValueKey(_step), child: _body()),
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
      case _Step.firstWin:
        return FirstWinStep(tv: _picked!, onContinue: _next);
      case _Step.pin:
        return _PinStep(onDone: _next);
      case _Step.goals:
        return GoalsStep(onDone: _finish);
    }
  }
}

/// Step change: a fade with a short 21 px slide (320 ms, easeOutCubic).
Widget stepTransition(Widget child, Animation<double> a) => FadeTransition(
      opacity: a,
      child: AnimatedBuilder(
        animation: a,
        builder: (context, child) => Transform.translate(
          offset:
              Offset(Motion.reduced(context) ? 0 : Gap.f21 * (1 - a.value), 0),
          child: child,
        ),
        child: child,
      ),
    );

/// One onboarding step: a hero, a display title, one line of lead, the
/// step's content, and the actions pinned at the bottom (one coral
/// primary, one quiet text secondary).
class _StepPage extends StatelessWidget {
  final Widget? hero;
  final String title;
  final String? lead;

  final List<Widget> content;
  final Widget? primary;
  final Widget? secondary;

  /// Content above the hero (the welcome wordmark).
  final Widget? top;

  /// Grow the hero area to fill spare height (welcome).
  final bool fill;

  /// Space under the hero; a haloed hero carries some of its own.
  final double heroGap;

  const _StepPage({
    required this.title,
    this.hero,
    this.lead,
    this.content = const [],
    this.primary,
    this.secondary,
    this.top,
    this.fill = false,
    this.heroGap = Gap.hero,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final head = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hero != null) ...[
          Center(child: hero),
          SizedBox(height: heroGap),
        ],
        Semantics(
          header: true,
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: text.headlineLarge,
          ),
        ),
        if (lead != null) ...[
          const SizedBox(height: Gap.inside),
          Text(lead!, textAlign: TextAlign.center, style: text.bodyLarge),
        ],
      ],
    );
    final body = fill
        ? Padding(
            padding: const EdgeInsets.fromLTRB(
              Gap.gutter,
              Gap.related,
              Gap.gutter,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (top != null) top!,
                Expanded(
                  child: Center(child: SingleChildScrollView(child: head)),
                ),
              ],
            ),
          )
        : SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              Gap.gutter,
              Gap.related,
              Gap.gutter,
              Gap.related,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (top != null) top!,
                if (top != null || hero == null)
                  const SizedBox(height: Gap.section),
                head,
                if (content.isNotEmpty) ...[
                  const SizedBox(height: Gap.section),
                  ...content,
                ],
              ],
            ),
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: body),
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

class _Welcome extends StatelessWidget {
  final VoidCallback onStart;
  const _Welcome({required this.onStart});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final bt = context.bt;
    return Scaffold(
      body: SafeArea(
        child: _StepPage(
          fill: true,
          top: Text(
            'boretube',
            style: Fonts.bricolage(TypeSize.headline, color: bt.ink),
          ),
          hero: const _WelcomeHero(),
          title: 'Calmer TV,\nin a few minutes.',
          lead: 'Pause it, set bedtimes, skip Shorts.',
          primary: PrimaryButton(
            key: const Key('onboarding-start'),
            label: 'Let\'s find your TV',
            icon: Icons.search_rounded,
            onPressed: onStart,
          ),
          secondary: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.restore_rounded,
                size: Sizes.iconSmall,
                color: bt.mintInk,
              ),
              const SizedBox(width: Gap.f8),
              Flexible(
                child: Text(
                  'Nothing changes without your OK.',
                  style: text.bodySmall,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tubby on a coral disc with two small sky and mint dots: 144 · 233 ·
/// 55 · 34, all Fibonacci.
class _WelcomeHero extends StatelessWidget {
  const _WelcomeHero();

  static const disc = Sizes.tubbyLarge * 2 + Sizes.tubby;

  @override
  Widget build(BuildContext context) {
    final bt = context.bt;
    return SizedBox(
      width: disc + Sizes.tubby,
      height: disc,
      child: Stack(
        alignment: Alignment.center,
        children: [
          _Dot(disc, bt.coralTint),
          Positioned(
            left: 0,
            top: Gap.f13,
            child: _Dot(Sizes.tubby, bt.skyTint),
          ),
          Positioned(
            right: Gap.f4,
            bottom: Gap.f21,
            child: _Dot(Sizes.tubbySmall, bt.mintTint),
          ),
          const Tubby(size: Sizes.tubbyLarge + Sizes.tubby, cheeks: true),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final double size;
  final Color color;
  const _Dot(this.size, this.color);

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}

/// Tubby inside a fixed hero box, with a soft sky halo while [busy].
class _StepHero extends StatelessWidget {
  final TubbyMood mood;
  final bool busy;
  const _StepHero({this.mood = TubbyMood.calm, this.busy = false});

  @override
  Widget build(BuildContext context) {
    final tubby = Tubby(mood: mood, size: Sizes.tubbyLarge);
    return SizedBox.square(
      dimension: Sizes.tubbyLarge * Phi.ratio,
      child: Center(
        child: busy
            ? PulsingIcon(
                size: Sizes.tubbyLarge,
                color: context.bt.sky,
                child: tubby,
              )
            : tubby,
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
    final bt = context.bt;
    final saved = {for (final t in ref.watch(savedTvsProvider)) t.id};
    final p = _progress;
    final none = _found.isEmpty && !_searching;
    return _StepPage(
      heroGap: Gap.section,
      hero: _StepHero(
        mood: none ? TubbyMood.asleep : TubbyMood.calm,
        busy: _searching,
      ),
      title: none ? 'No TVs found' : 'Find your TV',
      lead: none
          ? 'Is it on, and on this Wi-Fi?'
          : 'Make sure it\'s on. It shows up here.',
      content: [
        if (_found.isEmpty && _searching)
          const SkeletonCard(rows: 2)
        else if (_found.isNotEmpty)
          RowList(
            edges: true,
            children: [
              for (final (i, tv) in _found.indexed)
                StaggerIn(
                  index: i,
                  child: ListRow(
                    icon: Icons.tv_rounded,
                    title: tv.name,
                    subtitle: [
                      if (tv.manufacturer.isNotEmpty || tv.model.isNotEmpty)
                        '${tv.manufacturer} ${tv.model}'.trim(),
                      tv.ip,
                    ].join(' · '),
                    value: saved.contains(tv.id) ? 'Saved' : null,
                    onTap: () => widget.onPicked(tv),
                  ),
                ),
            ],
          ),
        const SizedBox(height: Gap.related),
        AnimatedSwitcher(
          duration: Motion.of(context, Motion.flip),
          child: _searching
              ? Column(
                  key: const ValueKey('searching'),
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    LinearProgressIndicator(
                      minHeight: Sizes.bar,
                      borderRadius: Radii.chip,
                      color: bt.sky,
                      backgroundColor: bt.wash,
                      value: p == null || p.total == 0
                          ? null
                          : p.scanned / p.total,
                    ),
                    const SizedBox(height: Gap.f8),
                    Text(
                      'Looking on your Wi-Fi…',
                      textAlign: TextAlign.center,
                      style: text.bodySmall,
                    ),
                  ],
                )
              : Center(
                  key: const ValueKey('done'),
                  child: TextButton.icon(
                    onPressed: _scan,
                    icon: const Icon(Icons.refresh_rounded, size: Sizes.icon),
                    label: const Text('Look again'),
                  ),
                ),
        ),
      ],
      secondary: TextButton.icon(
        key: const Key('enter-ip'),
        onPressed: _manual,
        icon: const Icon(Icons.keyboard_rounded, size: Sizes.icon),
        label: const Text('Type the TV\'s address'),
      ),
    );
  }
}

/// "Say hi to your TV": checks what the TV can do, then one big Mute over
/// whatever works (no setup), a celebration and Unmute.
class FirstWinStep extends ConsumerStatefulWidget {
  final Tv tv;
  final VoidCallback onContinue;

  const FirstWinStep({super.key, required this.tv, required this.onContinue});

  @override
  ConsumerState<FirstWinStep> createState() => _FirstWinStepState();
}

enum _Win { probing, ready, muting, won, unmuted, unreachable }

class _FirstWinStepState extends ConsumerState<FirstWinStep> {
  _Win _state = _Win.probing;
  String? _error;
  final _button = GlobalKey();

  @override
  void initState() {
    super.initState();
    // Not during initState: probing updates providers.
    Future.microtask(_probe);
  }

  Future<void> _probe() async {
    if (!mounted) return;
    setState(() {
      _state = _Win.probing;
      _error = null;
    });
    final tv = widget.tv.copyWith(lastSeen: DateTime.now());
    final report = await ref.read(capabilityProvider.notifier).probe(tv);
    if (!mounted) return;
    if (report == null) {
      setState(() => _state = _Win.unreachable);
      return;
    }
    await ref.read(tvStoreProvider).setActive(report.tv.id);
    if (!mounted) return;
    final c = report.capabilities;
    final canMute = c.contains(TvCapability.cast) ||
        c.contains(TvCapability.sonyRest) ||
        c.contains(TvCapability.adb);
    setState(() => _state = canMute ? _Win.ready : _Win.unreachable);
  }

  Future<void> _mute() async {
    final a = ref.read(actionsServiceProvider);
    if (a == null) return;
    unawaited(HapticFeedback.mediumImpact());
    setState(() {
      _state = _Win.muting;
      _error = null;
    });
    ActionResult r;
    try {
      r = await a.mute();
    } catch (e) {
      r = ActionResult(false, ActionTransport.none, detail: '$e');
    }
    if (!mounted) return;
    if (!r.ok) {
      setState(() {
        _state = _Win.ready;
        _error = r.detail.isEmpty
            ? 'The TV didn\'t answer. Is it on?'
            : 'The TV didn\'t take it: ${r.detail}';
      });
      return;
    }
    setState(() => _state = _Win.won);
    await ref.read(momentsProvider).claim(Moments.firstWin);
    final ctx = _button.currentContext;
    if (mounted) unawaited(celebrate(ctx ?? context));
  }

  Future<void> _unmute() async {
    final a = ref.read(actionsServiceProvider);
    if (a == null) return;
    final r = await a.unmute();
    if (!mounted) return;
    if (r.ok) {
      setState(() => _state = _Win.unmuted);
    } else {
      showStatusSnack(context, 'Didn\'t work: try the remote', ok: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final bt = context.bt;
    final won = _state == _Win.won || _state == _Win.unmuted;
    final probing = _state == _Win.probing;
    final shy = _state == _Win.unreachable;
    final sub = [
      if (widget.tv.manufacturer.isNotEmpty) widget.tv.manufacturer,
      probing
          ? 'saying hello…'
          : shy
              ? 'not answering yet'
              : 'found on your Wi-Fi',
    ].join(' · ');
    return _StepPage(
      top: Surface(
        key: const Key('first-win-tv'),
        padding: const EdgeInsets.symmetric(horizontal: Gap.inside),
        child: ListRow(
          icon: Icons.tv_rounded,
          iconColor: bt.skyInk,
          title: widget.tv.name,
          subtitle: sub,
          trailing: AnimatedSwitcher(
            duration: Motion.of(context, Motion.flip),
            child: probing
                ? const SizedBox.square(
                    key: ValueKey('p'),
                    dimension: Sizes.icon,
                    child: CircularProgressIndicator(strokeWidth: Sizes.focus),
                  )
                : shy
                    ? Icon(
                        Icons.wifi_off_rounded,
                        key: const ValueKey('x'),
                        size: Sizes.iconControl,
                        color: bt.muted,
                        semanticLabel: 'Not answering',
                      )
                    : Icon(
                        Icons.check_rounded,
                        key: const ValueKey('ok'),
                        size: Sizes.iconControl,
                        color: bt.mint,
                        semanticLabel: 'Connected',
                      ),
          ),
        ),
      ),
      title: shy ? 'Your TV is shy' : 'Say hi to your TV',
      lead: shy
          ? 'It isn\'t answering. Is it on and awake?'
          : 'Tap it and watch the TV go quiet.',
      content: [
        Center(
          child: _MuteButton(
            key: _button,
            state: _state,
            onTap: _state == _Win.ready ? _mute : null,
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: Gap.inside),
          Text(
            _error!,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text.bodyMedium!.copyWith(color: bt.berryFill),
          ),
        ],
        const SizedBox(height: Gap.related),
        AnimatedSwitcher(
          duration: Motion.of(context, Motion.sheet),
          switchInCurve: Motion.enter,
          switchOutCurve: Motion.exit,
          transitionBuilder: (child, a) =>
              FadeTransition(opacity: a, child: child),
          child: won
              ? NoticeBanner(
                  key: const Key('first-win-done'),
                  kind: BannerKind.success,
                  leading: Tubby(
                    mood: TubbyMood.cleaning,
                    body: bt.mint,
                    size: Sizes.tubbySmall,
                    antennas: false,
                    legs: false,
                  ),
                  title: 'Your TV listened!',
                  message: _state == _Win.unmuted
                      ? 'Sound is back. You\'re in charge now.'
                      : 'Unmute when you\'re ready.',
                  actionLabel: _state == _Win.won ? 'Unmute' : null,
                  onAction: _unmute,
                )
              : shy
                  ? Center(
                      child: PrimaryButton(
                        key: const Key('first-win-retry'),
                        label: 'Try again',
                        icon: Icons.refresh_rounded,
                        kind: ButtonKind.outline,
                        onPressed: _probe,
                      ),
                    )
                  : const SizedBox.shrink(),
        ),
      ],
      // Before the win the mute disc is the coral action; after it,
      // Continue takes over.
      primary: won
          ? PrimaryButton(
              key: const Key('first-win-continue'),
              label: 'Continue',
              onPressed: widget.onContinue,
            )
          : null,
      secondary: won
          ? null
          : TextButton(
              key: const Key('first-win-continue'),
              onPressed: probing ? null : widget.onContinue,
              child: const Text('Skip this'),
            ),
    );
  }
}

/// The hero: a 178 coral disc with two soft rings (13 and 21).
class _MuteButton extends StatelessWidget {
  final _Win state;
  final VoidCallback? onTap;

  const _MuteButton({super.key, required this.state, this.onTap});

  static const disc = Sizes.tubbyLarge * 2;

  @override
  Widget build(BuildContext context) {
    final bt = context.bt;
    final text = Theme.of(context).textTheme;
    final won = state == _Win.won || state == _Win.unmuted;
    final busy = state == _Win.muting;
    final enabled = onTap != null;
    final fill = won ? bt.mint : bt.coralFill;
    final fg = won ? const Color(0xFF06392A) : Colors.white;
    return Semantics(
      button: true,
      enabled: enabled,
      label: won ? 'The TV is muted' : 'Mute the TV',
      excludeSemantics: true,
      child: AnimatedOpacity(
        duration: Motion.of(context, Motion.flip),
        opacity:
            state == _Win.probing || state == _Win.unreachable ? Phi.minor : 1,
        child: AnimatedContainer(
          duration: Motion.of(context, Motion.sheet),
          curve: Motion.enter,
          width: disc,
          height: disc,
          margin: const EdgeInsets.all(Gap.f21),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: fill,
            boxShadow: [
              BoxShadow(
                color: won ? bt.mintTint : bt.coralTint,
                spreadRadius: Gap.f13,
              ),
              BoxShadow(
                color: won ? bt.mintTint.withValues(alpha: 0.5) : bt.coralWash,
                spreadRadius: Gap.f21,
              ),
            ],
          ),
          child: Material(
            type: MaterialType.transparency,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              key: const Key('first-win-mute'),
              onTap: onTap,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox.square(
                    dimension: Sizes.tubby,
                    child: busy
                        ? const Padding(
                            padding: EdgeInsets.all(Gap.f8),
                            child: CircularProgressIndicator(
                              strokeWidth: Sizes.bar,
                              color: Colors.white,
                            ),
                          )
                        : Icon(
                            won
                                ? Icons.check_rounded
                                : Icons.volume_off_rounded,
                            size: Sizes.tubby,
                            color: fg,
                          ),
                  ),
                  const SizedBox(height: Gap.f4),
                  Text(
                    won ? 'Muted' : 'Mute TV',
                    style: text.titleLarge!.copyWith(color: fg),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PinStep extends ConsumerStatefulWidget {
  final VoidCallback onDone;
  const _PinStep({required this.onDone});

  @override
  ConsumerState<_PinStep> createState() => _PinStepState();
}

class _PinStepState extends ConsumerState<_PinStep> {
  bool _set = false;

  @override
  Widget build(BuildContext context) {
    final bio = ref.watch(biometricAvailableProvider).valueOrNull ?? false;
    final lock = ref.watch(appLockProvider);
    if (!_set) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(Gap.gutter),
          child: PinSetup(
            onDone: (pin) async {
              await ref.read(appLockProvider.notifier).setPin(pin);
              if (!mounted) return;
              if (bio) {
                setState(() => _set = true);
              } else {
                widget.onDone();
              }
            },
          ),
        ),
      );
    }
    return _StepPage(
      heroGap: Gap.section,
      hero: const _StepHero(mood: TubbyMood.guard),
      title: 'PIN saved',
      lead: 'Use your fingerprint too? Kids can\'t.',
      content: [
        RowList(
          edges: true,
          children: [
            SwitchLine(
              key: const Key('onboarding-fingerprint'),
              leading: const Icon(Icons.fingerprint_rounded, size: Sizes.icon),
              title: 'Unlock with fingerprint',
              subtitle: 'The PIN still works',
              value: lock.biometricEnabled,
              onChanged: (v) =>
                  ref.read(appLockProvider.notifier).setBiometricEnabled(v),
            ),
          ],
        ),
      ],
      primary: PrimaryButton(label: 'Continue', onPressed: widget.onDone),
    );
  }
}

typedef _GoalLook = ({
  Goal goal,
  String title,
  String sub,
  IconData icon,
});

const _goalLooks = <_GoalLook>[
  (
    goal: Goal.shorts,
    title: 'Shorts and endless YouTube',
    sub: 'They scroll and can\'t stop',
    icon: Icons.smart_display_rounded,
  ),
  (
    goal: Goal.bedtime,
    title: 'Bedtime battles',
    sub: '"Just one more episode…"',
    icon: Icons.bedtime_rounded,
  ),
  (
    goal: Goal.loud,
    title: 'Way too loud',
    sub: 'The whole house can hear it',
    icon: Icons.volume_up_rounded,
  ),
  (
    goal: Goal.ads,
    title: 'Ads and clutter on the TV',
    sub: 'Promos, junk apps, slow menus',
    icon: Icons.cleaning_services_rounded,
  ),
  (
    goal: Goal.apps,
    title: 'Apps they shouldn\'t open',
    sub: 'Games, other streaming apps',
    icon: Icons.block_rounded,
  ),
];

/// "What's bugging you about TV time?" The picks order the plan.
class GoalsStep extends ConsumerStatefulWidget {
  final VoidCallback onDone;
  const GoalsStep({super.key, required this.onDone});

  @override
  ConsumerState<GoalsStep> createState() => _GoalsStepState();
}

class _GoalsStepState extends ConsumerState<GoalsStep> {
  late final List<Goal> _picked = [...ref.read(goalsProvider)];

  void _toggle(Goal g) {
    HapticFeedback.selectionClick();
    setState(() => _picked.contains(g) ? _picked.remove(g) : _picked.add(g));
  }

  Future<void> _save() async {
    await ref.read(goalsProvider.notifier).save(_picked);
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    return _StepPage(
      hero: const Tubby(size: Sizes.tubbyLarge),
      title: 'What\'s bugging you about TV time?',
      lead: 'Pick any. Nothing switches on yet.',
      content: [
        RowList(
          edges: true,
          children: [
            for (final g in _goalLooks)
              _GoalRow(
                look: g,
                on: _picked.contains(g.goal),
                onTap: () => _toggle(g.goal),
              ),
          ],
        ),
      ],
      primary: PrimaryButton(
        key: const Key('goals-done'),
        label: _picked.isEmpty ? 'Show my plan' : 'Show my calm-TV plan',
        onPressed: _save,
      ),
    );
  }
}

/// One goal: a plain one-line row, a check on the right when picked.
class _GoalRow extends StatelessWidget {
  final _GoalLook look;
  final bool on;
  final VoidCallback onTap;

  const _GoalRow({required this.look, required this.on, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final bt = context.bt;
    return Semantics(
      button: true,
      toggled: on,
      label: '${look.title}. ${look.sub}',
      excludeSemantics: true,
      child: ListRow(
        key: Key('goal-${look.goal.name}'),
        icon: look.icon,
        iconColor: on ? bt.ink : bt.muted,
        title: look.title,
        chevron: false,
        onTap: onTap,
        trailing: AnimatedSwitcher(
          duration: Motion.of(context, Motion.flip),
          child: Icon(
            on ? Icons.check_circle_rounded : Icons.circle_outlined,
            key: ValueKey(on),
            size: Sizes.iconControl,
            color: on ? bt.coralInk : bt.faint,
          ),
        ),
      ),
    );
  }
}
