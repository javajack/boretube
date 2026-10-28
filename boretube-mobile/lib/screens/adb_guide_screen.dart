import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../adb/adb_key.dart';
import '../adb/adb_session.dart';
import '../providers/tv_providers.dart';
import '../providers/ui_providers.dart';
import '../tv/tv.dart';
import '../ui/components.dart';
import '../ui/format.dart';
import '../ui/tokens.dart';
import '../ui/tubby.dart';

/// How often the guide checks whether the TV's switch is on.
final helperPollIntervalProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 3),
);

/// "Unlock Home mode": the helper-switch guide, full screen.
class AdbGuideScreen extends StatelessWidget {
  const AdbGuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: HelperSwitchGuide(
          onDone: () => Navigator.of(context).maybePop(),
          onSkip: () => Navigator.of(context).maybePop(),
        ),
      ),
    );
  }
}

/// The steps. [approve] is the rehearsal, the TV prompt and the result.
enum HelperStep { why, openAbout, pressOk, debugging, approve }

/// One action per screen on the TV, a mocked TV menu with the row to
/// pick, a pulsing remote key, a counter for the 7 OK presses, and live
/// detection that moves on by itself once the switch is on.
class HelperSwitchGuide extends ConsumerStatefulWidget {
  final VoidCallback onDone;
  final VoidCallback onSkip;

  const HelperSwitchGuide({
    super.key,
    required this.onDone,
    required this.onSkip,
  });

  @override
  ConsumerState<HelperSwitchGuide> createState() => _HelperSwitchState();
}

enum _Approve { rehearse, asking, connected, failed }

class _HelperSwitchState extends ConsumerState<HelperSwitchGuide> {
  HelperStep _step = HelperStep.why;
  int _presses = 0;
  _Approve _approve = _Approve.rehearse;
  bool _rejected = false;
  Timer? _poll;
  bool _probing = false;

  /// Set when live detection jumped ahead (shown as a small note).
  bool _detected = false;

  String? get _tvId => ref.read(activeTvIdProvider);

  @override
  void initState() {
    super.initState();
    final id = _tvId;
    if (id != null) {
      final p = ref.read(helperProgressProvider);
      final s = p.step(id).clamp(0, HelperStep.values.length - 1);
      _step = HelperStep.values[s];
      _presses = p.okPresses(id).clamp(0, 7);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncPoll());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _go(HelperStep s) async {
    setState(() => _step = s);
    final id = _tvId;
    if (id != null) {
      await ref.read(helperProgressProvider).setStep(id, s.index);
    }
    _syncPoll();
  }

  /// Polls while the parent is busy on the TV (steps 2–4).
  void _syncPoll() {
    final watch = _step == HelperStep.openAbout ||
        _step == HelperStep.pressOk ||
        _step == HelperStep.debugging;
    if (!watch) {
      _poll?.cancel();
      _poll = null;
      return;
    }
    _poll ??= Timer.periodic(ref.read(helperPollIntervalProvider), (_) {
      _check();
    });
  }

  /// One quiet look at the TV's developer port (never shows a prompt).
  Future<void> _check() async {
    final tv = ref.read(activeTvProvider);
    if (tv == null || _probing || !mounted) return;
    _probing = true;
    try {
      AdbKey? key;
      try {
        key = await ref
            .read(adbKeyProvider.future)
            .timeout(const Duration(seconds: 2));
      } catch (_) {
        key = null;
      }
      final o = await ref
          .read(capabilityProberProvider)
          .adbProbe(tv, key, const Duration(seconds: 2));
      if (!mounted) return;
      if (o.ok) {
        // Already trusted: nothing left to do on the TV.
        await _go(HelperStep.approve);
        await _connect();
      } else if (o.detail != 'closed' && _step != HelperStep.approve) {
        unawaited(HapticFeedback.mediumImpact());
        setState(() => _detected = true);
        await _go(HelperStep.approve);
      }
    } catch (_) {
      // Keep watching.
    } finally {
      _probing = false;
    }
  }

  Future<void> _press() async {
    if (_presses >= 7) return;
    unawaited(HapticFeedback.selectionClick());
    setState(() => _presses++);
    final id = _tvId;
    if (id != null) {
      await ref.read(helperProgressProvider).setOkPresses(id, _presses);
    }
    if (_presses == 7) {
      await Future<void>.delayed(const Duration(milliseconds: 700));
      if (mounted && _step == HelperStep.pressOk) {
        await _go(HelperStep.debugging);
      }
    }
  }

  Future<void> _connect() async {
    setState(() {
      _approve = _Approve.asking;
      _rejected = false;
    });
    try {
      await ref.read(adbKeyProvider.future);
      final session = ref.read(adbSessionProvider);
      if (session == null) throw StateError('No TV selected');
      await session.connect();
      await ref.read(capabilityProvider.notifier).probe();
      final id = _tvId;
      if (id != null) await ref.read(helperProgressProvider).clear(id);
      if (mounted) {
        unawaited(HapticFeedback.mediumImpact());
        setState(() => _approve = _Approve.connected);
      }
    } catch (_) {
      if (!mounted) return;
      final s = ref.read(adbStateProvider).valueOrNull;
      setState(() {
        _approve = _Approve.failed;
        _rejected = s is AdbFailed && s.authRejected;
      });
    }
  }

  void _help() => showBtSheet<void>(
        context,
        builder: (_) => _TroubleSheet(step: _step),
      );

  void _promptGone() => showBtSheet<void>(
        context,
        builder: (sheet) => SheetScaffold(
          key: const Key('helper-prompt-gone'),
          title: 'The prompt disappeared',
          lead: const Text(
            'The TV only shows it for about 30 seconds. Have the remote '
            'ready, then ask again.',
          ),
          children: [
            const CheckLine(
              'If you picked "Cancel", that\'s fine: just ask again.',
              done: true,
            ),
            const CheckLine(
              'Tick "Always allow", so it doesn\'t ask every time.',
              done: true,
            ),
            const SizedBox(height: Gap.f13),
            PrimaryButton(
              label: 'Ask my TV again',
              kind: ButtonKind.ink,
              onPressed: () {
                Navigator.pop(sheet);
                _connect();
              },
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final tv = ref.watch(activeTvProvider);
    final adb = ref.watch(adbStateProvider).valueOrNull;
    final asking = _step == HelperStep.approve &&
        _approve == _Approve.asking &&
        adb is AdbAwaitingApproval;
    final done = _step == HelperStep.approve && _approve == _Approve.connected;
    final n = _step.index + 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(Gap.f21, Gap.f13, Gap.f13, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  done ? 'Home mode is on' : 'Unlock Home mode · Step $n of 5',
                  style: Theme.of(context).textTheme.titleSmall!.copyWith(
                        color: context.bt.muted,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                ),
              ),
              if (!done)
                TextButton(
                  key: const Key('helper-skip'),
                  onPressed: widget.onSkip,
                  child: const Text('Skip for now'),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(Gap.f21, Gap.f4, Gap.f21, 0),
          child: _Progress(value: done ? 1 : n / 5),
        ),
        Expanded(
          child: AnimatedSwitcher(
            duration: Motion.of(context, Motion.sheet),
            switchInCurve: Motion.enter,
            transitionBuilder: (child, a) => FadeTransition(
              opacity: a,
              child: SlideTransition(
                position: Tween(
                  begin: const Offset(0.05, 0),
                  end: Offset.zero,
                ).animate(a),
                child: child,
              ),
            ),
            child: KeyedSubtree(
              key: ValueKey('$_step-$_approve-$asking'),
              child: _body(tv, asking, done),
            ),
          ),
        ),
      ],
    );
  }

  Widget _body(Tv? tv, bool asking, bool done) {
    switch (_step) {
      case HelperStep.why:
        return _Why(onStart: () => _go(HelperStep.openAbout));
      case HelperStep.openAbout:
        return _DoOnTv(
          key: const Key('helper-open-about'),
          title: const [
            TextSpan(text: 'Open '),
            TextSpan(text: 'About', style: _hl),
            TextSpan(text: ' in the TV\'s settings'),
          ],
          lead: 'On the TV: press the settings button on the remote (or pick '
              'the gear on the home screen), then System › About.',
          menu: const _TvMenu(
            heading: 'Your TV · Settings › System',
            rows: ['Date & time', 'Language', 'About'],
            target: 2,
          ),
          remote: const _RemoteKey(icon: Icons.settings_rounded),
          remoteNote: 'Use the arrows, then OK.',
          onNext: () => _go(HelperStep.pressOk),
          onHelp: _help,
        );
      case HelperStep.pressOk:
        return _DoOnTv(
          key: const Key('helper-press-ok'),
          title: const [
            TextSpan(text: 'Press '),
            TextSpan(text: 'OK', style: _hl),
            TextSpan(text: ' 7 times on "Android TV OS build"'),
          ],
          lead: 'Scroll down to the build line and keep pressing OK. The TV '
              'counts down, then says you\'re a developer.',
          menu: _TvMenu(
            heading: 'Your TV · About',
            rows: [
              'Model · ${tv?.model.isNotEmpty == true ? tv!.model : 'TV'}',
              'Android TV OS build',
              'Android TV OS version',
            ],
            target: 1,
          ),
          counter: _OkCounter(presses: _presses, onPress: _press),
          onNext: () => _go(HelperStep.debugging),
          onHelp: _help,
        );
      case HelperStep.debugging:
        return _DoOnTv(
          key: const Key('helper-debugging'),
          title: const [
            TextSpan(text: 'Turn on '),
            TextSpan(text: 'USB debugging', style: _hl),
          ],
          lead: 'Go back to System. A new "Developer options" menu is there '
              'now. Open it and switch on USB debugging.',
          menu: const _TvMenu(
            heading: 'Your TV · Developer options',
            rows: ['Stay awake', 'USB debugging', 'Wireless debugging'],
            target: 1,
            toggle: true,
          ),
          remote: const _RemoteKey(label: 'OK'),
          remoteNote: 'Then OK on "Allow USB debugging?" if it asks.',
          onNext: () => _go(HelperStep.approve),
          onHelp: _help,
        );
      case HelperStep.approve:
        if (done) {
          return _Done(tvName: tv?.name ?? 'Your TV', onDone: widget.onDone);
        }
        if (asking) {
          return _LookAtTv(onGone: _promptGone);
        }
        if (_approve == _Approve.asking) {
          return const _Waiting();
        }
        return _Rehearse(
          detected: _detected,
          failed: _approve == _Approve.failed,
          rejected: _rejected,
          onConnect: _connect,
          onBack: () => _go(HelperStep.debugging),
        );
    }
  }
}

const _hl = TextStyle(color: Color(0xFFFF6B4A));

class _Progress extends StatelessWidget {
  final double value;
  const _Progress({required this.value});

  @override
  Widget build(BuildContext context) {
    final bt = context.bt;
    return Semantics(
      label: '${(value * 100).round()}% done',
      excludeSemantics: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: SizedBox(
          height: 6,
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: value),
            duration: Motion.of(context, Motion.sheet),
            curve: Motion.enter,
            builder: (context, v, _) => Stack(
              children: [
                Positioned.fill(child: ColoredBox(color: bt.border)),
                FractionallySizedBox(
                  widthFactor: v,
                  heightFactor: 1,
                  child: ColoredBox(
                    color: bt.sky,
                    child: const SizedBox.expand(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Why this switch, and the promise that it can be undone.
class _Why extends StatelessWidget {
  final VoidCallback onStart;
  const _Why({required this.onStart});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final bt = context.bt;
    return ListView(
      key: const Key('helper-why'),
      padding: const EdgeInsets.fromLTRB(Gap.f21, Gap.f21, Gap.f21, Gap.f21),
      children: [
        const Center(child: Tubby(mood: TubbyMood.cleaning, size: 120)),
        const SizedBox(height: Gap.f21),
        Text('One switch on the TV', style: text.headlineLarge),
        const SizedBox(height: Gap.f8),
        Text(
          'Google TVs have a switch made for people who look after the TV. '
          'Turning it on lets this phone do more.',
          style: text.bodyLarge,
        ),
        const SizedBox(height: Gap.f13),
        Surface(
          padding: const EdgeInsets.fromLTRB(Gap.f13, Gap.f13, Gap.f13, Gap.f8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('WHAT YOU GET', style: text.labelSmall),
              const SizedBox(height: Gap.f4),
              const CheckLine('End app that really ends the app', done: true),
              const CheckLine('YouTube without Shorts', done: true),
              const CheckLine('A tidier TV: fewer promos and junk apps',
                  done: true),
              const CheckLine('The way to Always On', done: true),
            ],
          ),
        ),
        const SizedBox(height: Gap.f13),
        NoticeBanner(
          kind: BannerKind.success,
          icon: Icons.restore_rounded,
          title: 'We can put the TV back',
          message: 'It\'s Google\'s own switch, and you can turn it off any '
              'time. "Put the TV back the way it was" undoes everything '
              'boretube changed.',
        ),
        const SizedBox(height: Gap.f21),
        Row(
          children: [
            Icon(Icons.timer_outlined, size: 18, color: bt.muted),
            const SizedBox(width: Gap.f8),
            Expanded(
              child: Text(
                'About 3 minutes. Grab the TV remote.',
                style: text.bodyMedium,
              ),
            ),
          ],
        ),
        const SizedBox(height: Gap.f13),
        PrimaryButton(
          key: const Key('helper-start'),
          label: 'I have the remote',
          icon: Icons.settings_remote_rounded,
          onPressed: onStart,
        ),
      ],
    );
  }
}

/// A "Do this on the TV now" screen.
class _DoOnTv extends StatelessWidget {
  final List<InlineSpan> title;
  final String lead;
  final _TvMenu menu;
  final _RemoteKey? remote;
  final String? remoteNote;
  final Widget? counter;
  final VoidCallback onNext;
  final VoidCallback onHelp;

  const _DoOnTv({
    super.key,
    required this.title,
    required this.lead,
    required this.menu,
    required this.onNext,
    required this.onHelp,
    this.remote,
    this.remoteNote,
    this.counter,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final bt = context.bt;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            padding:
                const EdgeInsets.fromLTRB(Gap.f21, Gap.f13, Gap.f21, Gap.f13),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Gap.f13 + 2,
                    vertical: Gap.f8,
                  ),
                  decoration: BoxDecoration(
                    color: bt.inkFill,
                    borderRadius: BorderRadius.circular(Radii.chipR),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.tv_rounded, size: 16, color: bt.onInkFill),
                      const SizedBox(width: Gap.f8),
                      Flexible(
                        child: Text(
                          'DO THIS ON THE TV NOW',
                          style: text.labelSmall!.copyWith(
                            color: bt.onInkFill,
                            letterSpacing: 0.8,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: Gap.f13 + 2),
              Semantics(
                header: true,
                child: Text.rich(
                  TextSpan(children: title),
                  style: text.headlineLarge!.copyWith(fontSize: 28),
                ),
              ),
              const SizedBox(height: Gap.f8),
              Text(lead, style: text.bodyMedium),
              const SizedBox(height: Gap.f13),
              menu,
              const SizedBox(height: Gap.f13 + 2),
              if (counter != null) counter!,
              if (remote != null)
                Surface(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Gap.f13,
                    vertical: Gap.f8,
                  ),
                  child: Row(
                    children: [
                      remote!,
                      const SizedBox(width: Gap.f8),
                      Expanded(
                        child: Text(
                          remoteNote ?? '',
                          style: text.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: Gap.f13 + 2),
              const _Watching(),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(Gap.f21, 0, Gap.f21, Gap.f13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: PrimaryButton(
                      key: const Key('helper-help'),
                      label: 'I don\'t see that',
                      kind: ButtonKind.outline,
                      height: 52,
                      onPressed: onHelp,
                    ),
                  ),
                  const SizedBox(width: Gap.f13),
                  Expanded(
                    child: PrimaryButton(
                      key: const Key('helper-next'),
                      label: 'Done',
                      kind: ButtonKind.ink,
                      height: 52,
                      onPressed: onNext,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Gap.f8 + 2),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shield_rounded, size: 15, color: bt.mintInk),
                  const SizedBox(width: Gap.f8),
                  Flexible(
                    child: Text(
                      'Google\'s own switch. Turn it off anytime.',
                      style: text.bodySmall,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// "Watching for the switch. We'll move on by ourselves."
class _Watching extends StatelessWidget {
  const _Watching();

  @override
  Widget build(BuildContext context) {
    final bt = context.bt;
    final text = Theme.of(context).textTheme;
    return Semantics(
      liveRegion: true,
      child: Row(
        key: const Key('helper-watching'),
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: Motion.reduced(context)
                ? Icon(Icons.sync_rounded, size: 16, color: bt.skyInk)
                : CircularProgressIndicator(strokeWidth: 2, color: bt.skyInk),
          ),
          const SizedBox(width: Gap.f13),
          Expanded(
            child: Text(
              'Watching for the switch. We\'ll move on by ourselves.',
              style: text.titleSmall!.copyWith(
                color: bt.skyInk,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A mocked TV settings screen with the row to pick highlighted.
class _TvMenu extends StatelessWidget {
  final String heading;
  final List<String> rows;
  final int target;
  final bool toggle;

  const _TvMenu({
    required this.heading,
    required this.rows,
    required this.target,
    this.toggle = false,
  });

  @override
  Widget build(BuildContext context) {
    final bt = context.bt;
    final text = Theme.of(context).textTheme;
    return Semantics(
      label: 'On the TV, pick ${rows[target]}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(Gap.f13),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1D3A),
          borderRadius: Radii.hero,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              heading.toUpperCase(),
              style: text.labelSmall!.copyWith(
                color: const Color(0xFFA9AACB),
                letterSpacing: 1,
              ),
            ),
            for (var i = 0; i < rows.length; i++) ...[
              const SizedBox(height: Gap.f8),
              i == target
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Gap.f13,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: Radii.control,
                        border: Border.all(color: bt.coral, width: 3),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              rows[i],
                              style: text.titleSmall!.copyWith(
                                color: const Color(0xFF1C1D3A),
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          if (toggle) ...[
                            const _MiniToggle(),
                            const SizedBox(width: Gap.f8),
                          ],
                          Text(
                            '← here',
                            style: text.titleSmall!.copyWith(
                              color: const Color(0xFFD94A2B),
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    )
                  : Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Gap.f13,
                        vertical: 10,
                      ),
                      decoration: const BoxDecoration(
                        color: Color(0xFF2A2B4D),
                        borderRadius: Radii.control,
                      ),
                      child: Text(
                        rows[i],
                        style: text.bodyMedium!.copyWith(
                          color: const Color(0xFFD6D7EE),
                          fontSize: 14,
                        ),
                      ),
                    ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A small switch that slides on, on a loop (unless motion is reduced).
class _MiniToggle extends StatefulWidget {
  const _MiniToggle();

  @override
  State<_MiniToggle> createState() => _MiniToggleState();
}

class _MiniToggleState extends State<_MiniToggle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.reduced(context)) {
      _c.value = 1;
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bt = context.bt;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final on = Motion.reduced(context) || _c.value > 0.45;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          width: 34,
          height: 20,
          padding: const EdgeInsets.all(2),
          alignment: on ? Alignment.centerRight : Alignment.centerLeft,
          decoration: BoxDecoration(
            color: on ? bt.mint : const Color(0xFFCFC6BA),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Container(
            width: 16,
            height: 16,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }
}

/// A remote key with a pulsing halo.
class _RemoteKey extends StatelessWidget {
  final String? label;
  final IconData? icon;
  static const double size = 64;

  const _RemoteKey({this.label, this.icon});

  @override
  Widget build(BuildContext context) {
    final bt = context.bt;
    return ExcludeSemantics(
      child: PulsingIcon(
        size: size,
        color: bt.coral,
        child: Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(
            color: Color(0xFF2A2B4D),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Container(
            width: size * 0.46,
            height: size * 0.46,
            decoration: BoxDecoration(color: bt.coral, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: icon != null
                ? Icon(icon, size: size * 0.26, color: Colors.white)
                : Text(
                    label ?? '',
                    style: Fonts.bricolage(size * 0.18, color: Colors.white),
                  ),
          ),
        ),
      ),
    );
  }
}

/// The tap counter for the 7 OK presses.
class _OkCounter extends StatelessWidget {
  final int presses;
  final VoidCallback onPress;

  const _OkCounter({required this.presses, required this.onPress});

  @override
  Widget build(BuildContext context) {
    final bt = context.bt;
    final text = Theme.of(context).textTheme;
    final done = presses >= 7;
    return Semantics(
      button: true,
      label: done ? 'All 7 presses done' : 'I pressed OK. $presses of 7 so far',
      excludeSemantics: true,
      child: Surface(
        key: const Key('helper-ok-counter'),
        onTap: done ? null : onPress,
        padding: const EdgeInsets.symmetric(
          horizontal: Gap.f13,
          vertical: Gap.f8,
        ),
        child: Row(
          children: [
            const _RemoteKey(label: 'OK'),
            const SizedBox(width: Gap.f4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    done ? 'You\'re a developer!' : '$presses of 7',
                    key: const Key('helper-ok-count'),
                    style: Fonts.bricolage(
                      done ? 20 : 26,
                      color: bt.ink,
                      tabularFigures: true,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      for (var i = 0; i < 7; i++) ...[
                        if (i > 0) const SizedBox(width: 4),
                        Expanded(
                          child: AnimatedContainer(
                            duration: Motion.of(context, Motion.flip),
                            curve: Motion.enter,
                            height: 8,
                            decoration: BoxDecoration(
                              color: i < presses
                                  ? (done ? bt.mint : bt.coral)
                                  : bt.border,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    done
                        ? 'Moving on…'
                        : 'Tap here each time you press OK. Keep going!',
                    style: text.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Rehearses the TV prompt before it appears.
class _Rehearse extends ConsumerWidget {
  final bool detected;
  final bool failed;
  final bool rejected;
  final VoidCallback onConnect;
  final VoidCallback onBack;

  const _Rehearse({
    required this.detected,
    required this.failed,
    required this.rejected,
    required this.onConnect,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final bt = context.bt;
    final key = ref.watch(adbKeyProvider).valueOrNull;
    final fp = key == null ? null : adbFingerprint(key);
    return ListView(
      key: const Key('helper-rehearse'),
      padding: const EdgeInsets.fromLTRB(Gap.f21, Gap.f13, Gap.f21, Gap.f21),
      children: [
        if (detected && !failed) ...[
          const NoticeBanner(
            key: Key('helper-detected'),
            kind: BannerKind.success,
            icon: Icons.check_circle_rounded,
            title: 'The switch is on',
            message: 'Nice work. One last OK and you\'re done.',
          ),
          const SizedBox(height: Gap.f13),
        ],
        if (failed) ...[
          NoticeBanner(
            key: const Key('helper-failed'),
            kind: BannerKind.problem,
            icon: Icons.error_rounded,
            title: rejected ? 'The TV said no' : 'We couldn\'t reach the TV',
            message: rejected
                ? 'No harm done. Ask again, and this time pick "Allow".'
                : 'Check USB debugging is on and the TV is awake, then ask '
                    'again.',
          ),
          const SizedBox(height: Gap.f13),
        ],
        Semantics(
          header: true,
          child: Text(
            'Your TV will ask one question',
            style: text.headlineLarge!.copyWith(fontSize: 28),
          ),
        ),
        const SizedBox(height: Gap.f8),
        Text.rich(
          TextSpan(
            style: text.bodyMedium,
            children: const [
              TextSpan(text: 'When it does: tick '),
              TextSpan(
                text: 'Always allow',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              TextSpan(text: ', then pick '),
              TextSpan(
                text: 'Allow',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              TextSpan(text: '. It looks like this:'),
            ],
          ),
        ),
        const SizedBox(height: Gap.f13),
        _PromptMock(fingerprint: fp),
        const SizedBox(height: Gap.f21),
        PrimaryButton(
          key: const Key('adb-connect'),
          label: failed ? 'Ask my TV again' : 'Ready: ask my TV',
          icon: Icons.tv_rounded,
          onPressed: onConnect,
        ),
        const SizedBox(height: Gap.f8),
        TextButton(
          onPressed: onBack,
          child: const Text('Back to the TV steps'),
        ),
        const SizedBox(height: Gap.f8),
        Text(
          'This only lets boretube on this phone talk to the TV. Remove it '
          'any time in the TV\'s Developer options.',
          textAlign: TextAlign.center,
          style: text.bodySmall!.copyWith(color: bt.muted),
        ),
      ],
    );
  }
}

/// A mock of Android's "Allow USB debugging?" dialog.
class _PromptMock extends StatelessWidget {
  final String? fingerprint;
  const _PromptMock({this.fingerprint});

  @override
  Widget build(BuildContext context) {
    final bt = context.bt;
    final text = Theme.of(context).textTheme;
    const light = Color(0xFFD6D7EE);
    return Semantics(
      label: 'The TV prompt: tick Always allow, then pick Allow',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(Gap.f13),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1D3A),
          borderRadius: Radii.hero,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Allow USB debugging?',
              style: text.titleMedium!.copyWith(color: Colors.white),
            ),
            const SizedBox(height: Gap.f4),
            Text(
              'The computer\'s RSA key fingerprint is:\n'
              '${fingerprint ?? 'AB:CD:…'}',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: text.bodySmall!.copyWith(color: const Color(0xFFA9AACB)),
            ),
            const SizedBox(height: Gap.f13),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: Gap.f8,
                vertical: Gap.f8,
              ),
              decoration: BoxDecoration(
                borderRadius: Radii.control,
                border: Border.all(color: bt.coral, width: 2),
              ),
              child: Row(
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: bt.mint,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: Gap.f8),
                  Expanded(
                    child: Text(
                      'Always allow from this computer',
                      style: text.bodyMedium!.copyWith(
                        color: light,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Text(
                    '1',
                    style: Fonts.bricolage(14, color: bt.coral),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Gap.f13),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'Cancel',
                  style: text.labelLarge!.copyWith(
                    color: const Color(0xFF8A8BAE),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: Gap.f13),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Gap.f13 + 2,
                    vertical: Gap.f8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: Radii.control,
                    border: Border.all(color: bt.coral, width: 3),
                  ),
                  child: Text(
                    'Allow  2',
                    style: text.labelLarge!.copyWith(
                      color: const Color(0xFF1C1D3A),
                      fontSize: 14,
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

class _Waiting extends StatelessWidget {
  const _Waiting();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 56,
            height: 56,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          const SizedBox(height: Gap.f13),
          Text('Saying hello to the TV…', style: text.titleMedium),
        ],
      ),
    );
  }
}

/// Big, calm "Look at your TV" while the prompt is up.
class _LookAtTv extends ConsumerWidget {
  final VoidCallback onGone;
  const _LookAtTv({required this.onGone});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final bt = context.bt;
    final key = ref.watch(adbKeyProvider).valueOrNull;
    return Center(
      child: SingleChildScrollView(
        key: const Key('helper-look-at-tv'),
        padding: const EdgeInsets.all(Gap.f21),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PulsingIcon(
              size: 120,
              color: bt.coral,
              child: Tubby(size: 120, body: bt.sky),
            ),
            const SizedBox(height: Gap.f13),
            Semantics(
              liveRegion: true,
              child: Text(
                'Look at your TV',
                style: text.displaySmall,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: Gap.f13),
            Text.rich(
              TextSpan(
                style: text.bodyLarge,
                children: const [
                  TextSpan(text: 'Tick '),
                  TextSpan(
                    text: 'Always allow',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  TextSpan(text: ', then '),
                  TextSpan(
                    text: 'Allow',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  TextSpan(text: '.'),
                ],
              ),
              textAlign: TextAlign.center,
            ),
            if (key != null) ...[
              const SizedBox(height: Gap.f13),
              Text('THE TV SHOWS THIS CODE', style: text.labelSmall),
              const SizedBox(height: Gap.f4),
              Text(
                adbFingerprint(key),
                textAlign: TextAlign.center,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ],
            const SizedBox(height: Gap.f21),
            TextButton(
              key: const Key('helper-prompt-gone-open'),
              onPressed: onGone,
              child: const Text('The prompt disappeared'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Done extends StatelessWidget {
  final String tvName;
  final VoidCallback onDone;
  const _Done({required this.tvName, required this.onDone});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ListView(
      key: const Key('helper-done'),
      padding: const EdgeInsets.all(Gap.f21),
      children: [
        const SizedBox(height: Gap.f21),
        const Center(child: Tubby(mood: TubbyMood.cleaning, size: 140)),
        const SizedBox(height: Gap.f21),
        Text(
          'Home mode is on',
          style: text.displaySmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: Gap.f8),
        Text(
          '$tvName trusts this phone now.',
          style: text.bodyLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: Gap.f21),
        const Surface(
          padding: EdgeInsets.fromLTRB(Gap.f13, Gap.f8, Gap.f13, Gap.f8),
          child: Column(
            children: [
              CheckLine('End app now really ends the app', done: true),
              CheckLine('YouTube without Shorts is ready', done: true),
              CheckLine('Clean TV is ready', done: true),
            ],
          ),
        ),
        const SizedBox(height: Gap.f21),
        PrimaryButton(
          key: const Key('helper-finish'),
          label: 'Back to Home',
          kind: ButtonKind.ink,
          onPressed: onDone,
        ),
      ],
    );
  }
}

/// "I don't see that menu": where else it hides, per step.
class _TroubleSheet extends StatelessWidget {
  final HelperStep step;
  const _TroubleSheet({required this.step});

  @override
  Widget build(BuildContext context) {
    final (title, tips) = switch (step) {
      HelperStep.pressOk => (
          'Nothing happens when I press OK',
          [
            'Make sure "Android TV OS build" is highlighted, not the line '
                'above or below.',
            'If it says "No need, you are already a developer", you\'re '
                'done: tap Done.',
            'Some TVs ask for the TV\'s PIN after the last press.',
          ],
        ),
      HelperStep.debugging => (
          'I can\'t find Developer options',
          [
            'It only appears after the 7 OK presses. Go back one step if '
                'you\'re not sure.',
            'Look at the bottom of Settings › System, or under Device '
                'Preferences on some TVs.',
            'Turn on "USB debugging". If you also see "Wireless debugging", '
                'leave it as it is.',
          ],
        ),
      _ => (
          'I don\'t see that menu',
          [
            'On the remote, press the gear button. No gear? Pick your '
                'profile picture at the top right of the home screen, then '
                'Settings.',
            'Some TVs put About under Device Preferences instead of '
                'System.',
            'Sony: Settings › System › About.',
          ],
        ),
    };
    return SheetScaffold(
      key: const Key('helper-trouble'),
      title: title,
      children: [
        for (final t in tips) ...[
          CheckLine(t, done: true),
          const SizedBox(height: Gap.f4),
        ],
        const SizedBox(height: Gap.f13),
        PrimaryButton(
          label: 'Got it',
          kind: ButtonKind.ink,
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }
}
