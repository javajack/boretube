import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../actions/actions_service.dart';
import '../../agent/agent_client.dart';
import '../../ops/health.dart';
import '../../ops/tv_ops.dart';
import '../../providers/agent_providers.dart';
import '../../providers/break_provider.dart';
import '../../providers/now_playing.dart';
import '../../providers/nudges.dart';
import '../../providers/tv_providers.dart';
import '../../providers/ui_providers.dart';
import '../../tv/tv.dart';
import '../../ui/celebrate.dart';
import '../../ui/components.dart';
import '../../ui/tokens.dart';
import '../../ui/tubby.dart';
import '../now/quick_actions.dart';
import '../rules_tab.dart';
import '../shell_screen.dart';
import '../tv/tv_guard_card.dart';
import 'home_cards.dart';
import 'home_hero.dart';
import 'home_logic.dart';
import 'home_sheets.dart';
import 'nudge_card.dart';
import 'plan.dart';

/// Home: right now. One hero, one big Pause button, a few quick actions,
/// today at a glance and the plan.
class HomeTab extends ConsumerStatefulWidget {
  const HomeTab({super.key});

  @override
  ConsumerState<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends ConsumerState<HomeTab> {
  final _inflight = <QuickAction>{};
  Timer? _tick;

  /// "Pause after this one" sent, until the TV's status says so.
  EndAfterArmed? _armedLocal;
  DateTime? _armedAt;

  /// Cancel sent: ignore a stale "armed" from a poll already on the wire.
  DateTime? _cancelledAt;
  bool _endAfterBusy = false;

  /// How long a local guess about "armed" outlives the TV's word.
  static const _armGrace = Duration(seconds: 10);

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  /// Ticks once a second while a break runs (the countdown).
  void _syncTicker(bool on) {
    if (on && _tick == null) {
      _tick = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else if (!on && _tick != null) {
      _tick!.cancel();
      _tick = null;
    }
  }

  // ── Quick actions: optimistic, haptic, ring only after 1.5 s ──

  /// Can [a] start while the actions in flight run? Quiet, volume and
  /// End app each touch one thing; boring and breaks touch both.
  bool _blocked(QuickAction a) =>
      _inflight.any((b) => _touches(a).intersection(_touches(b)).isNotEmpty);

  static Set<String> _touches(QuickAction a) => switch (a) {
        QuickAction.mute || QuickAction.restore => const {'sound'},
        QuickAction.volume => const {'sound'},
        QuickAction.stop => const {'app'},
        QuickAction.bore || QuickAction.takeBreak => const {'sound', 'app'},
      };

  /// Shows [optimistic] at once, runs [run], and only speaks up if it
  /// failed (rolling the change back).
  Future<bool> _run(
    QuickAction action,
    Future<ActionResult?> Function() run, {
    NowPlaying Function(NowPlaying s)? optimistic,
  }) async {
    if (_blocked(action)) return false;
    unawaited(HapticFeedback.lightImpact());
    final now = ref.read(nowPlayingProvider.notifier);
    setState(() => _inflight.add(action));
    final undo = optimistic == null ? null : now.patch(optimistic);
    now.hold();
    ActionResult? r;
    final sw = Stopwatch()..start();
    try {
      r = await run();
    } catch (e) {
      r = ActionResult(false, ActionTransport.none, detail: '$e');
    } finally {
      now.release();
    }
    final ok = r != null && r.ok;
    if (kDebugMode) {
      debugPrint('BTIME action ${action.name} ${sw.elapsedMilliseconds}ms '
          'ok=$ok via=${r?.via.name} ${r?.detail ?? ''}');
    }
    if (!ok && undo != null) now.revert(undo);
    if (!mounted) return ok;
    ref.invalidate(journalEntriesProvider);
    setState(() => _inflight.remove(action));
    if (ok) return true;
    showStatusSnack(
      context,
      r == null
          ? 'Didn\'t work: no TV selected'
          : 'Didn\'t work: ${r.detail.isEmpty ? 'TV unreachable' : r.detail}',
      ok: false,
    );
    return false;
  }

  ActionsService? get _actions => ref.read(actionsServiceProvider);

  BreakController get _break => ref.read(breakProvider.notifier);

  Future<void> _pause(int minutes, {bool silenceOnly = false}) async {
    final id = ref.read(activeTvIdProvider);
    final started = ref.read(breakClockProvider)();
    final ok = await _run(
      QuickAction.takeBreak,
      () => _break.start(minutes, silenceOnly: silenceOnly),
    );
    if (!ok || id == null) return;
    await ref.read(breakStartLogProvider).mark(id, started);
    if (!silenceOnly) await ref.read(nudgeStoreProvider).logPause(started);
    if (!silenceOnly &&
        await ref.read(momentsProvider).claim(Moments.firstPause) &&
        mounted) {
      unawaited(celebrate(context));
    }
  }

  Future<void> _endBreak() => _run(QuickAction.takeBreak, _break.end);

  Future<void> _extend() => _run(
        QuickAction.takeBreak,
        () => _break.extend(const Duration(minutes: 15)),
      );

  // ── When this ends ──

  /// Asks Always On to start a break when [m] ends (or after the cap).
  Future<void> _endAfter(AgentMedia m, int breakMin) async {
    final c = ref.read(agentForActionsProvider);
    if (c == null || _endAfterBusy) return;
    unawaited(HapticFeedback.lightImpact());
    final t = ref.read(breakClockProvider)();
    setState(() {
      _endAfterBusy = true;
      _cancelledAt = null;
      _armedAt = t;
      _armedLocal = (
        title: m.title,
        capAt: t.add(const Duration(minutes: kEndAfterCapMin)),
      );
    });
    String? failed;
    try {
      final r = await c.action(
        AgentAction.endAfter(capMin: kEndAfterCapMin, breakMin: breakMin),
      );
      if (!r.ok) {
        failed = 'The TV couldn\'t follow this video. Pause TV still works.';
      }
    } on AgentException catch (e) {
      failed = 'Didn\'t work: ${e.message}';
    }
    if (!mounted) return;
    setState(() {
      _endAfterBusy = false;
      if (failed != null) {
        _armedLocal = null;
        _armedAt = null;
      }
    });
    if (failed != null) {
      showStatusSnack(context, failed, ok: false);
      return;
    }
    unawaited(ref.read(agentStatusProvider.notifier).refresh());
  }

  Future<void> _cancelEndAfter() async {
    final c = ref.read(agentForActionsProvider);
    if (c == null || _endAfterBusy) return;
    unawaited(HapticFeedback.lightImpact());
    final before = (_armedLocal, _armedAt);
    setState(() {
      _endAfterBusy = true;
      _cancelledAt = ref.read(breakClockProvider)();
      _armedLocal = null;
      _armedAt = null;
    });
    String? failed;
    try {
      final r = await c.action(
        const AgentAction(AgentActionKind.cancelEndAfter),
      );
      if (!r.ok) failed = r.detail.isEmpty ? 'TV unreachable' : r.detail;
    } on AgentException catch (e) {
      failed = e.message;
    }
    if (!mounted) return;
    setState(() {
      _endAfterBusy = false;
      if (failed != null) {
        _cancelledAt = null;
        _armedLocal = before.$1;
        _armedAt = before.$2;
      }
    });
    if (failed != null) {
      showStatusSnack(context, 'Didn\'t cancel: $failed', ok: false);
      return;
    }
    unawaited(ref.read(agentStatusProvider.notifier).refresh());
  }

  /// What the hero shows as armed: the TV's word, or (briefly) ours.
  EndAfterArmed? _armed(AgentEndAfter? tv, DateTime t, bool onBreak) {
    if (onBreak) return null;
    final cancelled = _cancelledAt;
    if (cancelled != null && t.difference(cancelled) < _armGrace) return null;
    if (tv != null && tv.armed) return (title: tv.title, capAt: tv.capAt);
    final at = _armedAt;
    if (at != null && t.difference(at) < _armGrace) return _armedLocal;
    return null;
  }

  void _openVolume() => showBtSheet<void>(
        context,
        builder: (_) => VolumeSheet(
          onSet: (v) async {
            final before = ref.read(nowPlayingProvider).volume;
            final ok = await _run(
              QuickAction.volume,
              () async => _actions?.setVolume(v),
              optimistic: (s) => s.copyWith(volume: v),
            );
            if (ok && before != null && v < before) {
              await ref
                  .read(nudgeStoreProvider)
                  .logVolumeDown(ref.read(nudgeClockProvider)());
            }
          },
        ),
      );

  void _openMore(Set<QuickAction> supported) => showBtSheet<void>(
        context,
        builder: (_) => MoreSheet(
          onBore: supported.contains(QuickAction.bore)
              ? () => _run(
                    QuickAction.bore,
                    () async => _actions?.bore(),
                    optimistic: (s) => s.atHome().copyWith(muted: true),
                  )
              : null,
          onSoundBack: supported.contains(QuickAction.restore)
              ? () => ref.read(breakProvider).active
                  ? _endBreak()
                  : _run(
                      QuickAction.restore,
                      () async => _actions?.restore(),
                      optimistic: (s) => s.copyWith(muted: false),
                    )
              : null,
          onQuietFor: supported.contains(QuickAction.takeBreak)
              ? (m) => _pause(m, silenceOnly: true)
              : null,
        ),
      );

  void _openWhatWorks(Tv tv, Protection level, bool degraded) =>
      showBtSheet<void>(
        context,
        builder: (sheet) => WhatWorksSheet(
          tvName: tv.name,
          level: level,
          degraded: degraded,
          onUnlockHome: () {
            Navigator.pop(sheet);
            context.push('/adb-guide');
          },
          onAlwaysOn: () {
            Navigator.pop(sheet);
            runAgentSetup(context, ref, repair: false);
          },
        ),
      );

  // ── Problems: one fix each ──

  Future<void> _fix(ProblemFix fix) async {
    final c = ref.read(agentClientProvider);
    Future<void> agent(Future<void> Function(AgentClient c) f) async {
      if (c == null) return;
      try {
        await f(c);
        await ref.read(agentStatusProvider.notifier).refresh();
      } on AgentException catch (e) {
        if (mounted) {
          showStatusSnack(context, 'Didn\'t work: ${e.message}', ok: false);
        }
      }
    }

    switch (fix) {
      case ProblemFix.repair:
        await runAgentSetup(context, ref, repair: true);
      case ProblemFix.reconnect:
        await ref.read(capabilityProvider.notifier).probe();
        await ref.read(agentStatusProvider.notifier).refresh();
        if (!mounted) return;
        final link = ref.read(agentStatusProvider);
        showStatusSnack(
          context,
          link.up
              ? 'Always On is back'
              : 'Still not answering. Is the TV on and on this Wi-Fi?',
          ok: link.up,
        );
      case ProblemFix.approveUpdate:
        final ok = await confirmAction(
          context,
          title: 'Does the TV work normally?',
          message: 'Your TV installed a software update. Tidying up waits '
              'until you say the TV still works as it should.',
          confirmLabel: 'Yes, approve',
          icon: Icons.system_update_tv_rounded,
        );
        if (ok) await agent((c) => c.approveBuild());
      case ProblemFix.resume:
        await agent((c) => c.setMode(AgentMode.normal));
      case ProblemFix.approvePhone:
        await context.push('/adb-guide');
    }
  }

  // ── Nudges: one gentle suggestion per app open ──

  Future<void> _actOnNudge(Nudge n, String tvId) async {
    await ref.read(nudgeSessionProvider).acted();
    if (n.id == NudgeId.reviewUpdate) {
      await ref.read(nudgeStoreProvider).buildReviewed(tvId);
    }
    if (!mounted) return;
    switch (n.target) {
      case NudgeTarget.routines:
        ref.read(routinesFocusProvider.notifier).state = n.focus;
        ref.read(shellTabProvider.notifier).state = 1;
      case NudgeTarget.betterTv:
        ref.read(betterTvFocusProvider.notifier).state = n.focus;
        ref.read(shellTabProvider.notifier).state = 2;
      case NudgeTarget.addTv:
        await context.push('/onboarding?add=1');
    }
  }

  Nudge? _nudge({
    required Tv tv,
    required AgentLink link,
    required AgentRules? rules,
    required AppState? yt,
    required List<ActivityItem> activity,
    required DateTime? since,
    required bool busy,
    required bool problem,
  }) {
    final store = ref.watch(nudgeStoreProvider);
    final session = ref.watch(nudgeSessionProvider);
    final now = ref.read(nudgeClockProvider)();
    final hasAdb = tv.can(TvCapability.adb);
    final health = hasAdb
        ? ref.watch(healthProvider).valueOrNull ?? const <HealthCheck>[]
        : const <HealthCheck>[];
    final build = hasAdb
        ? ref.watch(profileMatchProvider).valueOrNull?.props.buildId
        : null;
    final inputs = NudgeInputs(
      now: now,
      pauses: store.pauses,
      volumeDowns: store.volumeDowns,
      activity: activity,
      alwaysOn: link.installed,
      hasAdb: hasAdb,
      adbSince: hasAdb ? store.adbSince(tv.id, now) : null,
      rules: rules,
      status: link.status,
      health: health,
      stockYouTubeInstalled: yt == null ? null : yt == AppState.enabled,
      firstOpen: store.firstOpen(now),
      lastVisit: since,
      buildChanged: build != null && store.noteBuild(tv.id, build),
      unsavedTvs: store.unsavedTvs,
      problem: problem,
    );
    return session.choose(nudgeCandidates(inputs), now: now, busy: busy);
  }

  void _planStep(PlanStep s) {
    final tab = ref.read(shellTabProvider.notifier);
    switch (s) {
      case PlanStep.remote:
        break;
      case PlanStep.unlockHome:
        context.push('/adb-guide');
      case PlanStep.noShorts || PlanStep.cleanTv:
        tab.state = 2;
        ref.read(betterTvFocusProvider.notifier).state =
            s == PlanStep.noShorts ? 'noShorts' : 'cleanTv';
      case PlanStep.bedtime:
        tab.state = 1;
      case PlanStep.alwaysOn:
        if (ref.read(activeHasAdbProvider)) {
          runAgentSetup(context, ref, repair: false);
        } else {
          context.push('/adb-guide');
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tv = ref.watch(activeTvProvider);
    if (tv == null) {
      return ListView(
        padding: const EdgeInsets.all(Gap.page),
        children: [
          const HomeHeader(),
          const SizedBox(height: Gap.xl),
          EmptyState(
            icon: Icons.tv_off_rounded,
            tubby: TubbyMood.calm,
            title: 'No TV yet',
            message: 'Find your TV on this Wi-Fi to get started.',
            actionLabel: 'Find my TV',
            onAction: () => context.push('/onboarding?add=1'),
          ),
        ],
      );
    }
    final bt = context.bt;
    final now = ref.watch(nowPlayingProvider);
    final brk = ref.watch(breakProvider);
    final link = ref.watch(agentStatusProvider);
    final adb = ref.watch(adbStateProvider).valueOrNull;
    final rules = link.installed ? ref.watch(rulesProvider).valueOrNull : null;
    final activity = ref.watch(activityProvider).valueOrNull ?? const [];
    final since = ref.watch(previousVisitProvider);
    final yt = ref.watch(stockYouTubeStateProvider).valueOrNull;
    final plan = ref.watch(planProvider);
    final clock = ref.watch(breakClockProvider);
    final t = clock();
    _syncTicker(brk.active);

    final supported = supportedActions(tv);
    final online = now.online;
    final offline = !online && !now.loading;
    final level = protectionOf(tv, link);
    final problem = online ? problemOf(tv: tv, link: link, adb: adb) : null;
    final degraded = link.kind == AgentLinkKind.down ||
        link.kind == AgentLinkKind.authFailed;
    final muted = now.muted == true || brk.active;
    final schedule = rules?.tvTime.schedule ?? const [];
    final bedtime = nextBedtime(schedule, t);
    final untilBed = minutesUntilBedtime(schedule, t);
    final alwaysOnNow = level == Protection.alwaysOn &&
        link.healthy &&
        link.status!.mode == AgentMode.normal;
    final media = level == Protection.alwaysOn ? heroMediaOf(link, now) : null;
    final armed =
        alwaysOnNow ? _armed(link.status!.endAfter, t, brk.active) : null;
    if (brk.active && _armedAt != null) {
      _armedLocal = null;
      _armedAt = null;
    }

    // Status sentence.
    final parts = <String>[
      if (problem?.serious ?? false)
        'Needs a hand'
      else if (now.muted == true)
        'Sound off'
      else
        'Calm',
      if (bedtime != null && bedtime.now)
        'Bedtime until ${friendlyTime(context, bedtime.end)}'
      else if (bedtime != null &&
          bedtime.start.difference(t) < const Duration(hours: 18))
        'Bedtime ${friendlyTime(context, bedtime.start)}',
      if (yt == AppState.disabled || yt == AppState.notInstalled) 'Shorts off',
    ];
    final sentence =
        offline ? 'Controls come back when it\'s on' : parts.join(' · ');
    final sentenceTone = offline
        ? Tone.idle
        : (problem?.serious ?? false)
            ? Tone.bad
            : now.muted == true
                ? Tone.warn
                : Tone.ok;

    // Today.
    final stops = stopsToday(activity, t);
    final shorts = link.up ? link.status!.shorts : null;
    final shortsStops = shortsStopsToday(activity, t);
    final TodayLine? shortsLine =
        shorts == null || shorts.mode == ShortsMode.off
            ? null
            : (
                icon: Icons.swipe_vertical_rounded,
                color: bt.coralInk,
                before: shortsStops > 0
                    ? 'Shorts stopped '
                    : shorts.todayCount == 0
                        ? 'No Shorts today'
                        : 'Shorts today: ',
                bold: shortsStops > 0
                    ? '$shortsStops×'
                    : shorts.todayCount == 0
                        ? ''
                        : '${shorts.todayCount}',
                after: shortsStops > 0
                    ? ' today'
                    : shorts.todayCount > 0 &&
                            shorts.mode == ShortsMode.budget &&
                            shorts.perDay != null
                        ? ' of ${shorts.perDay}'
                        : '',
              );
    final limit = rules?.tvTime.dailyLimitMin ?? 0;
    final today = <TodayLine>[
      if (bedtime != null && bedtime.now)
        (
          icon: Icons.bedtime_rounded,
          color: bt.sunInk,
          before: 'Bedtime now · until ',
          bold: friendlyTime(context, bedtime.end),
          after: '',
        )
      else if (bedtime != null &&
          bedtime.start.difference(t) < const Duration(hours: 24))
        (
          icon: Icons.bedtime_rounded,
          color: bt.sunInk,
          before: 'Bedtime in ',
          bold: spanLabel(bedtime.start.difference(t)),
          after: '',
        ),
      if (limit > 0)
        (
          icon: Icons.timer_rounded,
          color: bt.skyInk,
          before: 'Daily TV time: ',
          bold: spanLabel(Duration(minutes: limit)),
          after: ' limit',
        ),
      if (shortsLine != null) shortsLine,
      (
        icon: Icons.shield_rounded,
        color: bt.mintInk,
        before: stops == 0 ? 'Nothing stopped today' : 'Apps stopped ',
        bold: stops == 0 ? '' : '$stops×',
        after: stops == 0 ? '' : ' today',
      ),
    ];

    // During this break / while you were away.
    final breakSince = brk.active
        ? (ref.read(breakStartLogProvider).read(tv.id) ??
            t.subtract(const Duration(hours: 1)))
        : null;
    final breakLines = breakSince == null
        ? const <String>[]
        : breakDigest(activity, breakSince);
    final away = since == null ? null : awayDigest(activity, since);

    final pauseMinutes = ref.watch(pauseChoiceProvider);
    final chosen = pauseMinutes == 0 && untilBed == null ? 30 : pauseMinutes;
    final canPause = supported.contains(QuickAction.takeBreak) && !offline;
    final nudge = _nudge(
      tv: tv,
      link: link,
      rules: rules,
      yt: yt,
      activity: activity,
      since: since,
      busy: _inflight.isNotEmpty ||
          brk.active ||
          offline ||
          (problem?.serious ?? false),
      problem: problem != null,
    );

    final children = <Widget>[
      const HomeHeader(),
      AnimatedSwitcher(
        duration: Motion.of(context, Motion.medium),
        switchInCurve: Motion.settle,
        switchOutCurve: Motion.settle,
        transitionBuilder: (child, a) => FadeTransition(
          opacity: a,
          child: SizeTransition(
            sizeFactor: a,
            axisAlignment: -1,
            child: child,
          ),
        ),
        child: nudge == null
            ? const SizedBox(key: ValueKey('no-nudge'), width: double.infinity)
            : Padding(
                key: ValueKey('nudge-${nudge.id.name}'),
                padding: const EdgeInsets.only(top: Gap.sm),
                child: NudgeCard(
                  key: const Key('home-nudge'),
                  nudge: nudge,
                  onAct: () => _actOnNudge(nudge, tv.id),
                  onNotNow: () => ref
                      .read(nudgeSessionProvider)
                      .notNow(ref.read(nudgeClockProvider)()),
                ),
              ),
      ),
      const SizedBox(height: Gap.md + 2),
      AnimatedSwitcher(
        duration: Motion.of(context, Motion.slow),
        switchInCurve: Motion.settle,
        transitionBuilder: (child, a) => FadeTransition(
          opacity: a,
          child: ScaleTransition(
            scale: Tween(begin: 0.98, end: 1.0).animate(a),
            child: child,
          ),
        ),
        child: brk.active
            ? PausedHero(
                key: const ValueKey('paused'),
                left: _break.remaining(),
                until: brk.until!,
                byTv: brk.byTv,
                silenceOnly: brk.silenceOnly,
              )
            : problem != null && problem.serious
                ? Column(
                    key: const ValueKey('problem'),
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      NoticeBanner(
                        key: const Key('home-problem'),
                        kind: BannerKind.problem,
                        icon: Icons.gpp_maybe_rounded,
                        title: problem.title,
                        message: problem.message,
                        actionLabel: problem.fixLabel,
                        actionNote: problem.fixNote,
                        onAction: () => _fix(problem.fix),
                      ),
                      const SizedBox(height: Gap.md),
                      StillWorkingCard(
                        lines: stillWorking(tv),
                        protection: level,
                        onBadge: () => _openWhatWorks(tv, level, degraded),
                      ),
                    ],
                  )
                : HomeHero(
                    key: ValueKey('hero-$offline'),
                    tvName: tv.name,
                    now: now,
                    sentence: sentence,
                    sentenceTone: sentenceTone,
                    protection: level,
                    onBadge: () => _openWhatWorks(tv, level, degraded),
                    onRetry: () =>
                        ref.read(nowPlayingProvider.notifier).refresh(),
                    media: media,
                    armed: armed,
                    cancelling: _endAfterBusy && armed != null,
                    onCancelArmed: _cancelEndAfter,
                  ),
      ),
      if (problem != null && !problem.serious && !brk.active) ...[
        const SizedBox(height: Gap.md),
        NoticeBanner(
          key: const Key('home-info'),
          kind: BannerKind.info,
          icon: Icons.pause_circle_rounded,
          title: problem.title,
          message: problem.message,
          actionLabel: problem.fixLabel,
          onAction: () => _fix(problem.fix),
        ),
      ],
      const SizedBox(height: Gap.md + 2),
      if (brk.active) ...[
        Row(
          children: [
            Expanded(
              child: PrimaryButton(
                key: const Key('break-extend'),
                label: '+ 15 min',
                kind: ButtonKind.outline,
                onPressed: _blocked(QuickAction.takeBreak) ? null : _extend,
              ),
            ),
            const SizedBox(width: Gap.md),
            Expanded(
              child: PrimaryButton(
                key: const Key('break-end'),
                label: brk.silenceOnly ? 'Sound on' : 'End break',
                kind: ButtonKind.ink,
                onPressed: _blocked(QuickAction.takeBreak) ? null : _endBreak,
              ),
            ),
          ],
        ),
        const SizedBox(height: Gap.md + 2),
        DuringBreakCard(lines: breakLines),
      ] else ...[
        if (supported.isEmpty)
          InfoCard(
            child: EmptyState(
              icon: Icons.settings_remote_rounded,
              tubby: TubbyMood.calm,
              title: 'Your TV isn\'t answering yet',
              message: 'Check it\'s switched on and on the same Wi-Fi as '
                  'this phone.',
              actionLabel: 'Check again',
              onAction: () => ref.read(capabilityProvider.notifier).probe(),
            ),
          )
        else ...[
          PrimaryButton(
            key: const Key('action-break'),
            label: 'Pause TV',
            icon: Icons.pause_rounded,
            display: true,
            shadow: true,
            height: 72,
            semanticLabel: chosen == 0
                ? 'Pause TV until bedtime'
                : 'Pause TV for ${_minutesWords(chosen)}',
            onPressed: canPause && !_blocked(QuickAction.takeBreak)
                ? () => _pause(chosen == 0 ? untilBed! : chosen)
                : null,
          ),
          const SizedBox(height: Gap.md),
          Row(
            children: [
              for (final m in PauseChoiceNotifier.choices) ...[
                if (m != 15) const SizedBox(width: Gap.sm),
                Expanded(
                  child: PillChoice(
                    key: Key('pause-$m'),
                    label: m == 60 ? '1h' : '${m}m',
                    radius: Radii.input,
                    semanticLabel: _minutesWords(m),
                    selected: chosen == m,
                    onTap: canPause
                        ? () => ref.read(pauseChoiceProvider.notifier).set(m)
                        : null,
                  ),
                ),
              ],
              if (untilBed != null) ...[
                const SizedBox(width: Gap.sm),
                Expanded(
                  child: PillChoice(
                    key: const Key('pause-bedtime'),
                    label: 'Bedtime',
                    radius: Radii.input,
                    semanticLabel: 'Until bedtime',
                    selected: chosen == 0,
                    onTap: canPause
                        ? () => ref.read(pauseChoiceProvider.notifier).set(0)
                        : null,
                  ),
                ),
              ],
            ],
          ),
          // §8 "End after this one": only with Always On reading the
          // video, and only claiming a time when the TV knows it.
          AnimatedSize(
            duration: Motion.of(context, Motion.medium),
            curve: Motion.settle,
            alignment: Alignment.topCenter,
            child: alwaysOnNow && media != null && armed == null && canPause
                ? Padding(
                    padding: const EdgeInsets.only(top: Gap.sm),
                    child: PillChoice(
                      key: const Key('pause-end-after'),
                      label: endAfterLabel(media),
                      icon: Icons.hourglass_bottom_rounded,
                      radius: Radii.input,
                      selected: false,
                      semanticLabel: media.timed && media.left != null
                          ? 'Pause TV when this video ends, '
                              '${aboutMinutes(media.left!)} from now'
                          : 'Pause TV after this video',
                      onTap: _endAfterBusy || _blocked(QuickAction.takeBreak)
                          ? null
                          : () => _endAfter(
                                media,
                                endAfterBreakMinutes(schedule, t),
                              ),
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
          const SizedBox(height: Gap.md + 2),
          _SecondaryRow(
            supported: supported,
            muted: muted,
            onBreak: brk.active,
            disabled: offline,
            busy: _inflight,
            blocked: _blocked,
            onQuiet: () => _run(
              QuickAction.mute,
              () async => muted ? _actions?.unmute() : _actions?.mute(),
              optimistic: (s) => s.copyWith(muted: !muted),
            ),
            onEndApp: () => _run(
              QuickAction.stop,
              () async => _actions?.stopCurrentApp(),
              optimistic: (s) => s.atHome(),
            ),
            onVolume: _openVolume,
            onMore: () => _openMore(supported),
          ),
        ],
      ],
      if (away != null) ...[
        const SizedBox(height: Gap.md + 2),
        NoticeBanner(
          key: const Key('away-digest'),
          kind: BannerKind.digest,
          leading: const Tubby(
            size: 46,
            body: Color(0xFF8C7CFF),
            antennas: false,
            legs: false,
            animate: false,
          ),
          title: 'While you were away',
          message: away,
          onTap: () => context.push('/history'),
        ),
      ],
      TodayStrip(
        lines: today,
        onHistory: () => context.push('/history'),
      ),
      if (plan.any((p) => !p.done)) PlanCard(items: plan, onStep: _planStep),
    ];

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(nowPlayingProvider.notifier).refresh();
        ref.invalidate(journalEntriesProvider);
        ref.invalidate(agentJournalProvider);
      },
      child: ListView(
        key: const Key('home-list'),
        padding: const EdgeInsets.fromLTRB(
          Gap.page,
          Gap.sm,
          Gap.page,
          Gap.xxl,
        ),
        children: children,
      ),
    );
  }

  static String _minutesWords(int m) => m == 60 ? '1 hour' : '$m minutes';
}

/// Quiet · End app · Volume · ⋯
class _SecondaryRow extends StatelessWidget {
  final Set<QuickAction> supported;
  final bool muted;
  final bool onBreak;
  final bool disabled;
  final Set<QuickAction> busy;
  final bool Function(QuickAction) blocked;
  final VoidCallback onQuiet;
  final VoidCallback onEndApp;
  final VoidCallback onVolume;
  final VoidCallback onMore;

  const _SecondaryRow({
    required this.supported,
    required this.muted,
    required this.onBreak,
    required this.disabled,
    required this.busy,
    required this.blocked,
    required this.onQuiet,
    required this.onEndApp,
    required this.onVolume,
    required this.onMore,
  });

  @override
  Widget build(BuildContext context) {
    VoidCallback? tap(QuickAction a, VoidCallback f) =>
        disabled || blocked(a) ? null : f;
    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.4);
    final tiles = <Widget>[
      if (supported.contains(QuickAction.mute))
        ActionTile(
          key: const Key('action-mute'),
          icon: muted ? Icons.volume_up_rounded : Icons.volume_off_rounded,
          label: muted ? 'Unmute' : 'Quiet',
          active: muted,
          tone: Tone.warn,
          busy: busy.contains(QuickAction.mute),
          onTap: tap(QuickAction.mute, onQuiet),
        ),
      if (supported.contains(QuickAction.stop))
        ActionTile(
          key: const Key('action-stop'),
          icon: Icons.close_rounded,
          label: 'End app',
          busy: busy.contains(QuickAction.stop),
          onTap: tap(QuickAction.stop, onEndApp),
        ),
      if (supported.contains(QuickAction.volume))
        ActionTile(
          key: const Key('action-volume'),
          icon: Icons.tune_rounded,
          label: 'Volume',
          busy: busy.contains(QuickAction.volume),
          onTap: tap(QuickAction.volume, onVolume),
        ),
      ActionTile(
        key: const Key('action-more'),
        icon: Icons.more_horiz_rounded,
        label: 'More',
        onTap: disabled ? null : onMore,
      ),
    ];
    return SizedBox(
      height: 84 * scale,
      child: Row(
        children: [
          for (var i = 0; i < tiles.length; i++) ...[
            if (i > 0) const SizedBox(width: Gap.sm + 2),
            Expanded(child: tiles[i]),
          ],
        ],
      ),
    );
  }
}

/// Top of Home: the TV switcher and the avatar (Settings).
class HomeHeader extends StatelessWidget {
  const HomeHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final bt = context.bt;
    return Row(
      children: [
        const Expanded(
            child: Align(alignment: Alignment.centerLeft, child: TvSwitcher())),
        Semantics(
          button: true,
          label: 'Settings',
          excludeSemantics: true,
          child: Material(
            color: bt.coralTint,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              key: const Key('open-settings'),
              onTap: () => context.push('/settings'),
              child: SizedBox(
                width: 48,
                height: 48,
                child: Icon(Icons.person_rounded, color: bt.coralInk),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
