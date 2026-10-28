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
import '../ui/tokens.dart';
import '../ui/tubby.dart';
import 'lock_screen.dart';
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
            duration: Motion.of(context, Motion.medium),
            switchInCurve: Motion.settle,
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

/// Title + lead at the top of an onboarding step.
class _StepTitle extends StatelessWidget {
  final String title;
  final String lead;
  final bool center;

  const _StepTitle(this.title, this.lead, {this.center = false});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final align = center ? TextAlign.center : TextAlign.start;
    return Column(
      crossAxisAlignment:
          center ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(title, style: text.headlineLarge, textAlign: align),
        ),
        const SizedBox(height: Gap.sm),
        Text(lead, style: text.bodyLarge, textAlign: align),
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
        child: LayoutBuilder(
          builder: (context, c) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              Gap.xl,
              Gap.xl,
              Gap.xl,
              Gap.xl,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: c.maxHeight - 48),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Wordmark(),
                      const SizedBox(height: Gap.xl),
                      SizedBox(
                        height: 250,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 230,
                              height: 230,
                              decoration: BoxDecoration(
                                color: bt.coralTint,
                                shape: BoxShape.circle,
                              ),
                            ),
                            Positioned(
                              left: 12,
                              top: 22,
                              child: _Dot(56, bt.skyTint),
                            ),
                            Positioned(
                              right: 16,
                              bottom: 28,
                              child: _Dot(40, bt.mintTint),
                            ),
                            const Tubby(size: 176, cheeks: true),
                          ],
                        ),
                      ),
                      const SizedBox(height: Gap.lg),
                      Text(
                        'Calmer TV,\nin a few minutes.',
                        textAlign: TextAlign.center,
                        style: text.displaySmall,
                      ),
                      const SizedBox(height: Gap.md),
                      Text(
                        'Pause it from your phone, set bedtimes that stick, and '
                        'get YouTube without Shorts.',
                        textAlign: TextAlign.center,
                        style: text.bodyLarge!.copyWith(fontSize: 17),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: Gap.xxl),
                      PrimaryButton(
                        key: const Key('onboarding-start'),
                        label: 'Let\'s find your TV',
                        icon: Icons.search_rounded,
                        height: 60,
                        onPressed: onStart,
                      ),
                      const SizedBox(height: Gap.md + 2),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.restore_rounded,
                              size: 16, color: bt.mintInk),
                          const SizedBox(width: Gap.sm),
                          Flexible(
                            child: Text(
                              'Nothing changes without your OK. Undo anytime.',
                              style: text.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ],
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
      padding: const EdgeInsets.fromLTRB(Gap.xl, Gap.sm, Gap.xl, Gap.xl),
      children: [
        const _StepTitle(
          'Find your TV',
          'Make sure it\'s on. TVs on this Wi-Fi show up here.',
        ),
        const SizedBox(height: Gap.lg),
        AnimatedSwitcher(
          duration: Motion.of(context, Motion.fast),
          child: _searching
              ? Column(
                  key: const ValueKey('searching'),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        minHeight: 6,
                        value: p == null || p.total == 0
                            ? null
                            : p.scanned / p.total,
                      ),
                    ),
                    const SizedBox(height: Gap.sm),
                    Text(
                      'Looking on your Wi-Fi…',
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
                    label: const Text('Look again'),
                  ),
                ),
        ),
        const SizedBox(height: Gap.md),
        if (_found.isEmpty && !_searching)
          const InfoCard(
            child: EmptyState(
              icon: Icons.tv_off_rounded,
              tubby: TubbyMood.asleep,
              title: 'No TVs found',
              message: 'Make sure the TV is on and this phone is on the same '
                  'Wi-Fi. Or type its address below.',
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
          label: const Text('Type the TV\'s address'),
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
    final bt = context.bt;
    final sub = [
      if (tv.manufacturer.isNotEmpty || tv.model.isNotEmpty)
        '${tv.manufacturer} ${tv.model}'.trim(),
      tv.ip,
    ].join(' · ');
    return InfoCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: Gap.lg,
        vertical: Gap.md + 2,
      ),
      child: Row(
        children: [
          IconBadge(icon: Icons.tv_rounded, color: bt.sky, size: 48),
          const SizedBox(width: Gap.md + 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tv.name, style: text.titleMedium!.copyWith(fontSize: 17)),
                const SizedBox(height: 2),
                Text(sub, style: text.bodySmall!.copyWith(fontSize: 14)),
                if (saved) ...[
                  const SizedBox(height: Gap.sm),
                  const BtBadge('Already saved', tone: Tone.ok),
                ],
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: bt.faint),
        ],
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
    final sub = [
      if (widget.tv.manufacturer.isNotEmpty) widget.tv.manufacturer,
      probing
          ? 'saying hello…'
          : _state == _Win.unreachable
              ? 'not answering yet'
              : 'found on your Wi-Fi',
    ].join(' · ');
    return LayoutBuilder(
      builder: (context, c) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(Gap.xl, Gap.sm, Gap.xl, Gap.xl),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: c.maxHeight - Gap.xl - 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InfoCard(
                key: const Key('first-win-tv'),
                padding: const EdgeInsets.symmetric(
                  horizontal: Gap.lg,
                  vertical: Gap.md + 2,
                ),
                child: Row(
                  children: [
                    IconBadge(icon: Icons.tv_rounded, color: bt.sky, size: 48),
                    const SizedBox(width: Gap.md + 2),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.tv.name,
                            style: text.titleMedium!.copyWith(fontSize: 17),
                          ),
                          Text(
                            sub,
                            style: text.bodySmall!.copyWith(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                    AnimatedSwitcher(
                      duration: Motion.of(context, Motion.fast),
                      child: probing
                          ? const SizedBox(
                              key: ValueKey('p'),
                              width: 22,
                              height: 22,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2.5),
                            )
                          : _state == _Win.unreachable
                              ? Icon(
                                  Icons.wifi_off_rounded,
                                  key: const ValueKey('x'),
                                  color: bt.muted,
                                  semanticLabel: 'Not answering',
                                )
                              : Icon(
                                  Icons.check_rounded,
                                  key: const ValueKey('ok'),
                                  color: bt.mint,
                                  size: 26,
                                  semanticLabel: 'Connected',
                                ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Gap.xxl),
              _StepTitle(
                _state == _Win.unreachable
                    ? 'Your TV is shy'
                    : 'Say hi to your TV',
                _state == _Win.unreachable
                    ? 'We found it, but it isn\'t answering. Check it\'s on '
                        'and awake, then try again.'
                    : 'Tap the big button and watch the TV go quiet. No '
                        'setup needed for this part.',
                center: true,
              ),
              const SizedBox(height: Gap.xl),
              Center(
                child: _MuteButton(
                  key: _button,
                  state: _state,
                  onTap: _state == _Win.ready ? _mute : null,
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: Gap.md),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: text.bodyMedium!.copyWith(color: bt.berryFill),
                ),
              ],
              const SizedBox(height: Gap.xl),
              AnimatedSwitcher(
                duration: Motion.of(context, Motion.medium),
                switchInCurve: Motion.spring,
                transitionBuilder: (child, a) => FadeTransition(
                  opacity: a,
                  child: ScaleTransition(
                    scale: Tween(begin: 0.92, end: 1.0).animate(a),
                    child: child,
                  ),
                ),
                child: won
                    ? NoticeBanner(
                        key: const Key('first-win-done'),
                        kind: BannerKind.success,
                        leading: Tubby(
                          mood: TubbyMood.cleaning,
                          body: bt.mint,
                          size: 46,
                          antennas: false,
                          legs: false,
                        ),
                        title: 'Your TV listened!',
                        message: _state == _Win.unmuted
                            ? 'Sound is back. That\'s boretube: you, in '
                                'charge, from the sofa.'
                            : 'That was the phone, talking to the TV. Bring '
                                'the sound back when you\'re ready.',
                        actionLabel: _state == _Win.won ? 'Unmute' : null,
                        onAction: _unmute,
                      )
                    : _state == _Win.unreachable
                        ? OutlinedButton.icon(
                            key: const Key('first-win-retry'),
                            onPressed: _probe,
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Try again'),
                          )
                        : const SizedBox(height: 0),
              ),
              const SizedBox(height: Gap.lg),
              PrimaryButton(
                key: const Key('first-win-continue'),
                label: won ? 'Continue' : 'Skip this',
                kind: won ? ButtonKind.ink : ButtonKind.outline,
                onPressed: probing ? null : widget.onContinue,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 176 dp coral circle with two soft rings.
class _MuteButton extends StatelessWidget {
  final _Win state;
  final VoidCallback? onTap;

  const _MuteButton({super.key, required this.state, this.onTap});

  @override
  Widget build(BuildContext context) {
    final bt = context.bt;
    final text = Theme.of(context).textTheme;
    final won = state == _Win.won || state == _Win.unmuted;
    final busy = state == _Win.muting;
    final enabled = onTap != null;
    final fill = won ? bt.mint : bt.coralFill;
    return Semantics(
      button: true,
      enabled: enabled,
      label: won ? 'The TV is muted' : 'Mute the TV',
      excludeSemantics: true,
      child: AnimatedOpacity(
        duration: Motion.of(context, Motion.fast),
        opacity: state == _Win.probing || state == _Win.unreachable ? 0.4 : 1,
        child: AnimatedContainer(
          duration: Motion.of(context, Motion.slow),
          curve: Motion.spring,
          width: 176,
          height: 176,
          margin: const EdgeInsets.all(30),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: fill,
            boxShadow: [
              BoxShadow(
                color: won ? bt.mintTint : bt.coralTint,
                spreadRadius: 14,
              ),
              BoxShadow(
                color: won ? bt.mintTint.withValues(alpha: 0.5) : bt.coralWash,
                spreadRadius: 30,
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
                  busy
                      ? const SizedBox(
                          width: 44,
                          height: 44,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: Colors.white,
                          ),
                        )
                      : Icon(
                          won ? Icons.check_rounded : Icons.volume_off_rounded,
                          size: 54,
                          color: won ? const Color(0xFF06392A) : Colors.white,
                        ),
                  const SizedBox(height: 6),
                  Text(
                    won ? 'Muted' : 'Mute TV',
                    style: text.labelLarge!.copyWith(
                      fontSize: 19,
                      color: won ? const Color(0xFF06392A) : Colors.white,
                    ),
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
    final text = Theme.of(context).textTheme;
    if (!_set) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(Gap.xl),
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
    return Padding(
      padding: const EdgeInsets.all(Gap.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _StepTitle(
            'PIN saved',
            'Want to open boretube with your fingerprint too? Kids '
                'can\'t use yours.',
          ),
          const SizedBox(height: Gap.xl),
          InfoCard(
            padding: EdgeInsets.zero,
            child: SwitchListTile(
              key: const Key('onboarding-fingerprint'),
              value: lock.biometricEnabled,
              onChanged: (v) =>
                  ref.read(appLockProvider.notifier).setBiometricEnabled(v),
              secondary: const Icon(Icons.fingerprint_rounded, size: 28),
              title: const Text('Unlock with fingerprint'),
              subtitle: Text(
                'The PIN still works',
                style: text.bodySmall,
              ),
            ),
          ),
          const Spacer(),
          PrimaryButton(
            label: 'Continue',
            kind: ButtonKind.ink,
            onPressed: widget.onDone,
          ),
        ],
      ),
    );
  }
}

typedef _GoalLook = ({
  Goal goal,
  String title,
  String sub,
  IconData icon,
  Tone tone,
});

const _goalLooks = <_GoalLook>[
  (
    goal: Goal.shorts,
    title: 'Shorts and endless YouTube',
    sub: 'They scroll and can\'t stop',
    icon: Icons.smart_display_rounded,
    tone: Tone.accent,
  ),
  (
    goal: Goal.bedtime,
    title: 'Bedtime battles',
    sub: '"Just one more episode…"',
    icon: Icons.bedtime_rounded,
    tone: Tone.warn,
  ),
  (
    goal: Goal.loud,
    title: 'Way too loud',
    sub: 'The whole house can hear it',
    icon: Icons.volume_up_rounded,
    tone: Tone.info,
  ),
  (
    goal: Goal.ads,
    title: 'Ads and clutter on the TV',
    sub: 'Promos, junk apps, slow menus',
    icon: Icons.cleaning_services_rounded,
    tone: Tone.idle,
  ),
  (
    goal: Goal.apps,
    title: 'Apps they shouldn\'t open',
    sub: 'Games, other streaming apps',
    icon: Icons.block_rounded,
    tone: Tone.ok,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Gap.xl, Gap.sm, Gap.xl, Gap.lg),
            children: [
              const _StepTitle(
                'What\'s bugging you about TV time?',
                'Pick any. We\'ll build your plan around them. Nothing '
                    'switches on yet.',
              ),
              const SizedBox(height: Gap.lg),
              for (final g in _goalLooks) ...[
                _GoalCard(
                  look: g,
                  on: _picked.contains(g.goal),
                  onTap: () => _toggle(g.goal),
                ),
                const SizedBox(height: Gap.sm + 2),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(Gap.xl, 0, Gap.xl, Gap.lg),
          child: PrimaryButton(
            key: const Key('goals-done'),
            label: _picked.isEmpty ? 'Show my plan' : 'Show my calm-TV plan',
            height: 58,
            onPressed: _save,
          ),
        ),
      ],
    );
  }
}

class _GoalCard extends StatelessWidget {
  final _GoalLook look;
  final bool on;
  final VoidCallback onTap;

  const _GoalCard({required this.look, required this.on, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final bt = context.bt;
    final text = Theme.of(context).textTheme;
    final hue = look.tone == Tone.idle ? bt.lavender : look.tone.hue(context);
    final ink =
        look.tone == Tone.idle ? bt.lavenderInk : look.tone.color(context);
    final tint =
        look.tone == Tone.idle ? bt.lavenderTint : look.tone.tint(context);
    return Semantics(
      button: true,
      toggled: on,
      label: '${look.title}. ${look.sub}',
      excludeSemantics: true,
      child: AnimatedContainer(
        key: Key('goal-${look.goal.name}'),
        duration: Motion.of(context, Motion.fast),
        curve: Motion.settle,
        decoration: BoxDecoration(
          color: bt.surface,
          borderRadius: Radii.card,
          border: Border.all(color: on ? hue : bt.border, width: 2),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: Radii.card,
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 72),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: Gap.md + 2,
                  vertical: Gap.md,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: tint,
                        borderRadius: Radii.icon,
                      ),
                      child: Icon(look.icon, color: ink, size: 22),
                    ),
                    const SizedBox(width: Gap.md + 2),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(look.title, style: text.titleMedium),
                          Text(
                            look.sub,
                            style: text.bodySmall!.copyWith(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: Gap.sm),
                    AnimatedContainer(
                      duration: Motion.of(context, Motion.fast),
                      curve: Motion.spring,
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: on ? hue : bt.border,
                      ),
                      child: Icon(
                        Icons.check_rounded,
                        size: 16,
                        color: on ? Colors.white : Colors.transparent,
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
