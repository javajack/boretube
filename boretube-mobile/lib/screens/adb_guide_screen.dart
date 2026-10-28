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
      await Future<void>.delayed(Motion.slow + Motion.flip);
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
          lead: const Text('It shows for about 30 seconds. Remote ready?'),
          children: [
            const _Tips([
              'If you picked "Cancel", that\'s fine: just ask again.',
              'Tick "Always allow", so it doesn\'t ask every time.',
            ]),
            const SizedBox(height: Gap.related),
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
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(Gap.gutter, Gap.f8, Gap.f8, 0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: Sizes.touch),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    done
                        ? 'Home mode is on'
                        : 'Unlock Home mode · Step $n of 5',
                    style: text.labelMedium,
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
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Gap.gutter),
          child: Semantics(
            label: done ? 'All steps done' : 'Step $n of 5',
            excludeSemantics: true,
            child: ThinProgress(value: done ? 1 : n / 5, color: context.bt.sky),
          ),
        ),
        Expanded(
          child: AnimatedSwitcher(
            duration: Motion.of(context, Motion.sheet),
            switchInCurve: Motion.enter,
            switchOutCurve: Motion.exit,
            transitionBuilder: _slide,
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
          title: const ('Open ', 'About', ''),
          lead: 'Settings › System › About',
          more: 'On the TV: press the settings button on the remote (or pick '
              'the gear on the home screen), then System › About.',
          menu: const _TvMenu(
            heading: 'System',
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
          title: const ('Press ', 'OK', ' 7 times'),
          lead: 'Highlight "Android TV OS build"',
          more: 'Scroll down to the build line and keep pressing OK. The TV '
              'counts down, then says you\'re a developer.',
          menu: _TvMenu(
            heading: 'About',
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
          title: const ('Turn on ', 'USB debugging', ''),
          lead: 'In System › Developer options',
          more: 'Go back to System. A new "Developer options" menu is there '
              'now. Open it and switch on USB debugging. Then pick OK on '
              '"Allow USB debugging?" if it asks.',
          menu: const _TvMenu(
            heading: 'Developer options',
            rows: ['Stay awake', 'USB debugging', 'Wireless debugging'],
            target: 1,
            toggle: true,
          ),
          remote: const _RemoteKey(label: 'OK'),
          remoteNote: 'Then OK if the TV asks.',
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

/// One guide screen: optional hero, a display title, one line of lead
/// (more behind ⓘ), the content, and the actions pinned at the bottom.
class _GuidePage extends StatelessWidget {
  final Widget? hero;
  final Widget title;
  final InlineSpan? lead;
  final InfoButton? info;
  final List<Widget> top;
  final List<Widget> content;
  final Widget? primary;
  final Widget? secondary;

  const _GuidePage({
    super.key,
    required this.title,
    this.hero,
    this.lead,
    this.info,
    this.top = const [],
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
                ...top,
                if (hero != null) ...[
                  Center(child: hero),
                  const SizedBox(height: Gap.section),
                ],
                Semantics(
                  header: true,
                  child: DefaultTextStyle.merge(
                    textAlign: TextAlign.center,
                    style: text.headlineLarge,
                    child: title,
                  ),
                ),
                if (lead != null) ...[
                  const SizedBox(height: Gap.inside),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text.rich(
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

/// Why this switch, and the promise that it can be undone.
class _Why extends StatelessWidget {
  final VoidCallback onStart;
  const _Why({required this.onStart});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final bt = context.bt;
    return _GuidePage(
      key: const Key('helper-why'),
      hero: const Tubby(mood: TubbyMood.cleaning, size: Sizes.tubbyLarge),
      title: const Text('Flip one TV switch'),
      lead: const TextSpan(text: 'It lets this phone do a lot more.'),
      content: [
        Surface(
          padding: const EdgeInsets.fromLTRB(
            Gap.inside,
            Gap.f8,
            Gap.f4,
            Gap.f8,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const CheckLine('End app that really ends the app', done: true),
              const CheckLine('YouTube without Shorts', done: true),
              const CheckLine('A tidier TV, fewer promos', done: true),
              const CheckLine('The way to Always On', done: true),
              Padding(
                padding: const EdgeInsets.only(
                  top: Gap.f8,
                  bottom: Gap.f4,
                  right: Gap.inside,
                ),
                child: Divider(
                  height: Sizes.hairline,
                  thickness: Sizes.hairline,
                  color: bt.hairline,
                ),
              ),
              Row(
                children: [
                  SizedBox(
                    width: Sizes.iconControl,
                    child: Icon(
                      Icons.restore_rounded,
                      size: Sizes.icon,
                      color: bt.mintInk,
                    ),
                  ),
                  const SizedBox(width: Gap.inside),
                  Expanded(
                    child: Text(
                      'We can put the TV back',
                      style: text.titleSmall!.copyWith(color: bt.mintInk),
                    ),
                  ),
                  const InfoButton(
                    title: 'We can put the TV back',
                    body: 'It\'s Google\'s own switch, and you can turn it '
                        'off any time. "Put the TV back the way it was" '
                        'undoes everything boretube changed.',
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
      primary: PrimaryButton(
        key: const Key('helper-start'),
        label: 'I have the remote',
        icon: Icons.settings_remote_rounded,
        onPressed: onStart,
      ),
      secondary: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_outlined, size: Sizes.iconSmall, color: bt.muted),
          const SizedBox(width: Gap.f8),
          Flexible(
            child: Text('About 3 minutes', style: text.bodySmall),
          ),
        ],
      ),
    );
  }
}

/// A "Do this on the TV now" screen.
class _DoOnTv extends StatelessWidget {
  /// Before, highlighted, after.
  final (String, String, String) title;
  final String lead;

  /// The longer how-to, behind ⓘ.
  final String more;
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
    required this.more,
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
    final (a, hl, b) = title;
    return _GuidePage(
      title: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: a),
            TextSpan(text: hl, style: TextStyle(color: bt.coral)),
            TextSpan(text: b),
          ],
        ),
      ),
      lead: TextSpan(text: lead),
      info: InfoButton(title: 'On the TV', body: more),
      content: [
        menu,
        const SizedBox(height: Gap.related),
        if (counter != null) counter!,
        if (remote != null)
          Row(
            children: [
              remote!,
              const SizedBox(width: Gap.inside),
              Expanded(
                child: Text(remoteNote ?? '', style: text.bodyMedium),
              ),
            ],
          ),
        const SizedBox(height: Gap.related),
        const _Watching(),
      ],
      primary: PrimaryButton(
        key: const Key('helper-next'),
        label: 'Done',
        onPressed: onNext,
      ),
      secondary: TextButton(
        key: const Key('helper-help'),
        onPressed: onHelp,
        child: const Text('I don\'t see that'),
      ),
    );
  }
}

/// "Watching for the switch. We'll move on."
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
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox.square(
            dimension: Sizes.iconSmall,
            child: Motion.reduced(context)
                ? Icon(
                    Icons.sync_rounded,
                    size: Sizes.iconSmall,
                    color: bt.skyInk,
                  )
                : CircularProgressIndicator(
                    strokeWidth: Sizes.focus,
                    color: bt.skyInk,
                  ),
          ),
          const SizedBox(width: Gap.f8),
          Flexible(
            child: Text(
              'Watching for the switch. We\'ll move on.',
              style: text.labelMedium!.copyWith(color: bt.skyInk),
            ),
          ),
        ],
      ),
    );
  }
}

/// Text on the drawn TV screen (always dark, in both themes).
const _onScreen = Color(0xFFD6D7EE);
const _onScreenMuted = Color(0xFFA9AACB);

/// A mocked TV settings screen with the row to pick highlighted, on a
/// small stand: the drawn TV is the step's hero.
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
    final row = text.bodyMedium!.copyWith(
      color: _onScreen,
      height: TypeSize.tightLeading,
    );
    return Semantics(
      label: 'On the TV, pick ${rows[target]}',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: bt.screen,
              borderRadius: Radii.hero,
              border: Border.all(color: bt.border, width: Sizes.hairline),
            ),
            child: Padding(
              padding: const EdgeInsets.all(Gap.inside),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Gap.f4,
                      vertical: Gap.f4,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.tv_rounded,
                          size: Sizes.iconSmall,
                          color: _onScreen,
                        ),
                        const SizedBox(width: Gap.f8),
                        Expanded(
                          child: Text(
                            'Do this on the TV now',
                            style: text.labelMedium!.copyWith(
                              color: _onScreen,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Text(
                          heading,
                          style: text.labelMedium!.copyWith(
                            color: _onScreenMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  for (var i = 0; i < rows.length; i++) ...[
                    const SizedBox(height: Gap.f8),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: i == target ? Colors.white : bt.screenInner,
                        borderRadius: Radii.control,
                        border: i == target
                            ? Border.all(color: bt.coral, width: Sizes.focus)
                            : null,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: Gap.inside,
                          vertical: Gap.inside,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                rows[i],
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: i == target
                                    ? row.copyWith(
                                        color: BtColors.light.ink,
                                        fontWeight: FontWeight.w700,
                                      )
                                    : row,
                              ),
                            ),
                            if (i == target) ...[
                              if (toggle) ...[
                                const _MiniToggle(),
                                const SizedBox(width: Gap.f8),
                              ],
                              Text(
                                '← here',
                                style: row.copyWith(
                                  color: BtColors.light.coralPressed,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          // The stand.
          Center(
            child: Container(
              width: Sizes.row,
              height: Sizes.bar,
              decoration: BoxDecoration(
                color: bt.screen,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(Radii.chipR),
                ),
              ),
            ),
          ),
        ],
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
    duration: Motion.slow * 5,
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
          duration: Motion.flip,
          curve: Motion.enter,
          width: Sizes.tile,
          height: Sizes.icon,
          padding: const EdgeInsets.all(Sizes.focus),
          alignment: on ? Alignment.centerRight : Alignment.centerLeft,
          decoration: BoxDecoration(
            color: on ? bt.mint : BtColors.light.faint,
            borderRadius: const BorderRadius.all(
              Radius.circular(Sizes.icon / 2),
            ),
          ),
          child: Container(
            width: Sizes.iconSmall,
            height: Sizes.iconSmall,
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

/// A remote key with a pulsing halo (55, in an 89 band).
class _RemoteKey extends StatelessWidget {
  final String? label;
  final IconData? icon;
  static const double size = Sizes.row;

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
          decoration: BoxDecoration(
            color: bt.screenInner,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Container(
            width: size * Phi.major,
            height: size * Phi.major,
            decoration: BoxDecoration(color: bt.coral, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: icon != null
                ? Icon(icon, size: Sizes.icon, color: Colors.white)
                : Text(
                    label ?? '',
                    style: Fonts.bricolage(
                      TypeSize.caption,
                      color: Colors.white,
                      height: TypeSize.tightLeading,
                    ),
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
        padding: const EdgeInsets.fromLTRB(
          Gap.f4,
          Gap.f4,
          Gap.related,
          Gap.f4,
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
                      done ? TypeSize.headline : TypeSize.title,
                      color: bt.ink,
                      height: TypeSize.tightLeading,
                      tabularFigures: true,
                    ),
                  ),
                  const SizedBox(height: Gap.f8),
                  Row(
                    children: [
                      for (var i = 0; i < 7; i++) ...[
                        if (i > 0) const SizedBox(width: Gap.f4),
                        Expanded(
                          child: AnimatedContainer(
                            duration: Motion.of(context, Motion.flip),
                            curve: Motion.enter,
                            height: Sizes.dot,
                            decoration: BoxDecoration(
                              color: i < presses
                                  ? (done ? bt.mint : bt.coral)
                                  : bt.wash,
                              borderRadius: Radii.chip,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: Gap.f8),
                  Text(
                    done ? 'Moving on…' : 'Tap each time you press OK.',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
    final key = ref.watch(adbKeyProvider).valueOrNull;
    final fp = key == null ? null : adbFingerprint(key);
    const bold = TextStyle(fontWeight: FontWeight.w700);
    return _GuidePage(
      key: const Key('helper-rehearse'),
      top: [
        if (detected && !failed) ...[
          const NoticeBanner(
            key: Key('helper-detected'),
            kind: BannerKind.success,
            icon: Icons.check_circle_rounded,
            title: 'The switch is on',
            message: 'Nice work. One last OK and you\'re done.',
          ),
          const SizedBox(height: Gap.section),
        ],
        if (failed) ...[
          NoticeBanner(
            key: const Key('helper-failed'),
            kind: BannerKind.problem,
            icon: Icons.error_rounded,
            title: rejected ? 'The TV said no' : 'We couldn\'t reach the TV',
            message: rejected
                ? 'No harm done. Ask again, and pick "Allow".'
                : 'Is USB debugging on and the TV awake?',
          ),
          const SizedBox(height: Gap.section),
        ],
      ],
      title: const Text('Your TV will ask one question'),
      lead: const TextSpan(
        children: [
          TextSpan(text: 'Tick '),
          TextSpan(text: 'Always allow', style: bold),
          TextSpan(text: ', then '),
          TextSpan(text: 'Allow', style: bold),
          TextSpan(text: '.'),
        ],
      ),
      info: const InfoButton(
        title: 'What this allows',
        body: 'This only lets boretube on this phone talk to the TV. Remove '
            'it any time in the TV\'s Developer options.',
      ),
      content: [_PromptMock(fingerprint: fp)],
      primary: PrimaryButton(
        key: const Key('adb-connect'),
        label: failed ? 'Ask my TV again' : 'Ready: ask my TV',
        icon: Icons.tv_rounded,
        onPressed: onConnect,
      ),
      secondary: TextButton(
        onPressed: onBack,
        child: const Text('Back to the TV steps'),
      ),
    );
  }
}

/// A mock of Android's "Allow USB debugging?" dialog, drawn on the TV.
class _PromptMock extends StatelessWidget {
  final String? fingerprint;
  const _PromptMock({this.fingerprint});

  @override
  Widget build(BuildContext context) {
    final bt = context.bt;
    final text = Theme.of(context).textTheme;
    final ring = Border.all(color: bt.coral, width: Sizes.focus);
    final step = Fonts.bricolage(
      TypeSize.caption,
      color: bt.coral,
      height: TypeSize.tightLeading,
    );
    return Semantics(
      label: 'The TV prompt: tick Always allow, then pick Allow',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: bt.screen,
          borderRadius: Radii.hero,
          border: Border.all(color: bt.border, width: Sizes.hairline),
        ),
        child: Padding(
          padding: const EdgeInsets.all(Gap.related),
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
                style: text.bodySmall!.copyWith(color: _onScreenMuted),
              ),
              const SizedBox(height: Gap.inside),
              DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: Radii.control,
                  border: ring,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(Gap.f8),
                  child: Row(
                    children: [
                      Container(
                        width: Sizes.icon,
                        height: Sizes.icon,
                        decoration: BoxDecoration(
                          color: bt.mint,
                          borderRadius: BorderRadius.circular(Gap.f4),
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          size: Sizes.iconSmall,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: Gap.f8),
                      Expanded(
                        child: Text(
                          'Always allow from this computer',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.bodySmall!.copyWith(color: _onScreen),
                        ),
                      ),
                      Text('1', style: step),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: Gap.inside),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Cancel',
                    style: text.labelMedium!.copyWith(color: _onScreenMuted),
                  ),
                  const SizedBox(width: Gap.related),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: Radii.control,
                      border: ring,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Gap.inside,
                        vertical: Gap.f8,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Allow',
                            style: text.labelMedium!.copyWith(
                              color: BtColors.light.ink,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: Gap.f8),
                          Text('2', style: step),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
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
          const SizedBox.square(
            dimension: Sizes.row,
            child: CircularProgressIndicator(strokeWidth: Sizes.bar),
          ),
          const SizedBox(height: Gap.related),
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
    const bold = TextStyle(fontWeight: FontWeight.w700);
    return Center(
      child: SingleChildScrollView(
        key: const Key('helper-look-at-tv'),
        padding: const EdgeInsets.all(Gap.gutter),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PulsingIcon(
              size: Sizes.tubbyLarge,
              color: bt.coral,
              child: Tubby(size: Sizes.tubbyLarge, body: bt.sky),
            ),
            const SizedBox(height: Gap.section),
            Semantics(
              liveRegion: true,
              child: Text(
                'Look at your TV',
                style: text.headlineLarge,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: Gap.inside),
            Text.rich(
              const TextSpan(
                children: [
                  TextSpan(text: 'Tick '),
                  TextSpan(text: 'Always allow', style: bold),
                  TextSpan(text: ', then '),
                  TextSpan(text: 'Allow', style: bold),
                  TextSpan(text: '.'),
                ],
              ),
              style: text.bodyLarge,
              textAlign: TextAlign.center,
            ),
            if (key != null) ...[
              const SizedBox(height: Gap.section),
              Text('The TV shows this code', style: text.bodySmall),
              const SizedBox(height: Gap.f4),
              Text(
                adbFingerprint(key),
                textAlign: TextAlign.center,
                style: text.bodySmall!.copyWith(
                  fontFamily: 'monospace',
                  color: bt.inkSoft,
                ),
              ),
            ],
            const SizedBox(height: Gap.section),
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
    return _GuidePage(
      key: const Key('helper-done'),
      hero: const Tubby(
        mood: TubbyMood.cleaning,
        size: Sizes.tubbyLarge + Sizes.tubby,
        beaming: true,
      ),
      title: const Text('Home mode is on'),
      lead: TextSpan(text: '$tvName trusts this phone now.'),
      content: const [
        RowList(
          edges: true,
          children: [
            CheckLine(
              'End app now really ends the app',
              done: true,
              minHeight: Sizes.row,
            ),
            CheckLine(
              'YouTube without Shorts is ready',
              done: true,
              minHeight: Sizes.row,
            ),
            CheckLine(
              'Clean TV is ready',
              done: true,
              minHeight: Sizes.row,
            ),
          ],
        ),
      ],
      primary: PrimaryButton(
        key: const Key('helper-finish'),
        label: 'Back to Home',
        onPressed: onDone,
      ),
    );
  }
}

/// Plain tip rows with hairlines, for the troubleshooting sheets.
class _Tips extends StatelessWidget {
  final List<String> tips;
  const _Tips(this.tips);

  @override
  Widget build(BuildContext context) {
    final bt = context.bt;
    final text = Theme.of(context).textTheme;
    return RowList(
      edges: true,
      children: [
        for (final t in tips)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: Gap.inside),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: Sizes.iconControl,
                  child: Icon(
                    Icons.lightbulb_outline_rounded,
                    size: Sizes.icon,
                    color: bt.muted,
                  ),
                ),
                const SizedBox(width: Gap.inside),
                Expanded(child: Text(t, style: text.bodyMedium)),
              ],
            ),
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
        _Tips(tips),
        const SizedBox(height: Gap.related),
        PrimaryButton(
          label: 'Got it',
          kind: ButtonKind.ink,
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }
}
