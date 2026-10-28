import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/log_entry.dart';
import '../../providers/providers.dart';
import '../../providers/tv_providers.dart';
import '../../ui/components.dart';
import '../../ui/controls.dart';
import '../../ui/format.dart';
import '../../ui/tokens.dart';
import '../whitelist_screen.dart';

/// Lock mode — mutually exclusive (as in v1).
enum ClassicMode { none, apps, volume }

/// Lock for a while: the v1 timed lock, every field kept: mode, duration
/// (1–1440 min), max volume (1–100 %), whitelist, and the check interval
/// (5–300 s) under Advanced options. The hero shows what and how long
/// with the one primary; every field lives in the setup sheet. Runs in the foreground service via
/// [LockService], so this phone has to stay on the Wi-Fi.
class ClassicLockCard extends ConsumerStatefulWidget {
  const ClassicLockCard({super.key});

  @override
  ConsumerState<ClassicLockCard> createState() => _ClassicLockCardState();
}

class _ClassicLockCardState extends ConsumerState<ClassicLockCard> {
  static const durations = [15, 30, 60, 120];

  ClassicMode _mode = ClassicMode.none;
  final _intervalCtrl = TextEditingController(text: '10');
  final _durationCtrl = TextEditingController(text: '60');
  int _maxVol = 15;
  bool _customDuration = false;
  bool _advanced = false;

  final List<LogEntry> _feed = [];
  int _remaining = 0;
  bool _active = false;

  StreamSubscription<LogEntry>? _logSub;
  StreamSubscription<int>? _remainingSub;
  StreamSubscription<bool>? _activeSub;

  @override
  void initState() {
    super.initState();
    final ls = ref.read(lockServiceProvider);
    _active = ls.isActive;
    _remaining = ls.lastRemaining;
    _feed.addAll(ls.log);
    _logSub = ls.logStream.listen((e) {
      if (mounted) setState(() => _feed.add(e));
    });
    _remainingSub = ls.remainingStream.listen((r) {
      if (mounted) setState(() => _remaining = r);
    });
    _activeSub = ls.activeStream.listen((a) {
      if (mounted) setState(() => _active = a);
    });
    _durationCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _changes.dispose();
    _intervalCtrl.dispose();
    _durationCtrl.dispose();
    _logSub?.cancel();
    _remainingSub?.cancel();
    _activeSub?.cancel();
    super.dispose();
  }

  int get _duration => (int.tryParse(_durationCtrl.text) ?? 60).clamp(1, 1440);

  Future<void> _start() async {
    if (_mode == ClassicMode.none) return;
    final tv = ref.read(activeTvProvider);
    if (tv == null) return;
    final whitelist = ref.read(whitelistProvider);
    final ls = ref.read(lockServiceProvider);
    final interval = (int.tryParse(_intervalCtrl.text) ?? 10).clamp(5, 300);
    final maxVol = _maxVol.clamp(1, 100);
    final duration = _duration;
    _intervalCtrl.text = '$interval';
    _durationCtrl.text = '$duration';
    unawaited(HapticFeedback.mediumImpact());
    setState(() => _feed.clear());
    await ls.start(
      host: tv.ip,
      castPort: tv.castPort,
      dialPort: tv.dialPort,
      lockApps: _mode == ClassicMode.apps,
      lockVolume: _mode == ClassicMode.volume,
      maxVolume: maxVol,
      intervalSeconds: interval,
      durationMinutes: duration,
      whitelist: whitelist,
    );
  }

  Future<void> _stop() async {
    unawaited(HapticFeedback.mediumImpact());
    await ref.read(lockServiceProvider).stop();
  }

  /// Ticks on every state change so the open setup sheet rebuilds.
  final _changes = ValueNotifier<int>(0);

  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
    _changes.value++;
  }

  String get _whatLabel => switch (_mode) {
        ClassicMode.none => 'Choose',
        ClassicMode.apps => 'Allowed apps',
        ClassicMode.volume => 'Volume ≤ $_maxVol%',
      };

  /// Every field of the lock, in one sheet.
  Future<void> _openSetup() => showBtSheet<void>(
        context,
        builder: (_) => ValueListenableBuilder<int>(
          valueListenable: _changes,
          builder: (c, tick, child) => SheetScaffold(
            key: const Key('classic-sheet'),
            title: 'Lock for a while',
            lead: const Text('This phone watches the TV and steps in.'),
            children: [
              _setup(c),
              const SizedBox(height: Gap.related),
              PrimaryButton(
                key: const Key('classic-sheet-done'),
                label: 'Done',
                kind: ButtonKind.ink,
                onPressed: () => Navigator.pop(c),
              ),
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final bt = context.bt;
    final locked = _active;
    // The setup sheet shows the allowed apps too.
    ref.listen(whitelistProvider, (_, __) => _changes.value++);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Surface(
          key: const Key('classic-lock'),
          borderColor: locked ? bt.sky : null,
          radius: Radii.hero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          locked ? 'Locked for a while' : 'Lock for a while',
                          style: text.headlineMedium,
                        ),
                        Text(
                          locked
                              ? 'Keep this phone on the Wi-Fi until it ends.'
                              : 'Keep this phone on the TV\'s Wi-Fi.',
                          style: text.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: Gap.inside),
                  IconTile(
                    icon:
                        locked ? Icons.lock_rounded : Icons.lock_clock_rounded,
                    color: locked ? bt.skyInk : bt.coralInk,
                    size: Sizes.avatar,
                  ),
                ],
              ),
              const SizedBox(height: Gap.inside),
              AnimatedSwitcher(
                duration: Motion.of(context, Motion.sheet),
                switchInCurve: Motion.enter,
                switchOutCurve: Motion.exit,
                child: locked ? _running(context) : _summary(context),
              ),
              const SizedBox(height: Gap.related),
              PrimaryButton(
                key: const Key('classic-start-stop'),
                label: locked
                    ? 'Stop the lock'
                    : _mode == ClassicMode.none
                        ? 'Pick what to lock'
                        : 'Lock for ${_durationWords(_duration)}',
                icon: locked ? Icons.stop_rounded : Icons.lock_rounded,
                kind: locked ? ButtonKind.berry : ButtonKind.coral,
                height: locked ? null : Sizes.primary,
                onPressed: locked
                    ? _stop
                    : (_mode == ClassicMode.none ? _openSetup : _start),
              ),
            ],
          ),
        ),
        if (_feed.isNotEmpty || locked) _feedView(context),
      ],
    );
  }

  /// What and how long, as two rows that open the sheet.
  Widget _summary(BuildContext context) {
    return RowList(
      key: const ValueKey('summary'),
      edges: true,
      children: [
        ListRow(
          key: const Key('classic-what'),
          title: 'What to lock',
          value: _whatLabel,
          onTap: _openSetup,
        ),
        ListRow(
          key: const Key('classic-how-long'),
          title: 'For how long',
          value: _durationWords(_duration),
          onTap: _openSetup,
        ),
      ],
    );
  }

  Widget _running(BuildContext context) {
    final bt = context.bt;
    final text = Theme.of(context).textTheme;
    return Column(
      key: const ValueKey('running'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _remaining > 0 ? formatRemaining(_remaining) : '…',
          key: const Key('classic-remaining'),
          style: Fonts.bricolage(
            TypeSize.hero,
            color: bt.skyInk,
            tabularFigures: true,
          ),
        ),
        Text(
          _mode == ClassicMode.volume
              ? 'left · volume kept at $_maxVol% or less'
              : 'left · only allowed apps play',
          style: text.bodySmall!.copyWith(color: bt.inkSoft),
        ),
      ],
    );
  }

  Widget _setup(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final bt = context.bt;
    final whitelist = ref.watch(whitelistProvider);
    final other = _customDuration || !durations.contains(_duration);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RowList(
          edges: true,
          children: [
            ChoiceCard(
              key: const Key('classic-mode-apps'),
              selected: _mode == ClassicMode.apps,
              icon: Icons.apps_rounded,
              title: 'Only allowed apps',
              body: 'Anything else is stopped and muted.',
              onTap: () => setState(
                () => _mode = _mode == ClassicMode.apps
                    ? ClassicMode.none
                    : ClassicMode.apps,
              ),
            ),
            ChoiceCard(
              key: const Key('classic-mode-volume'),
              selected: _mode == ClassicMode.volume,
              icon: Icons.volume_down_rounded,
              title: 'Cap the volume',
              body: 'Turning it up snaps back down.',
              onTap: () => setState(
                () => _mode = _mode == ClassicMode.volume
                    ? ClassicMode.none
                    : ClassicMode.volume,
              ),
            ),
          ],
        ),
        AnimatedSize(
          duration: Motion.of(context, Motion.sheet),
          curve: Motion.enter,
          alignment: Alignment.topCenter,
          child: _mode == ClassicMode.none
              ? const SizedBox(width: double.infinity)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_mode == ClassicMode.apps) ...[
                      GroupHeading(
                        'Allowed apps',
                        trailing: TextButton(
                          key: const Key('classic-whitelist'),
                          onPressed: () => context.push('/whitelist'),
                          child: const Text('Edit list'),
                        ),
                      ),
                      Wrap(
                        spacing: Gap.f8,
                        runSpacing: Gap.f8,
                        children: [
                          for (final e in whitelist)
                            _AllowedPill(
                              label: e.appId == kBackdropId
                                  ? 'Home screen'
                                  : e.friendlyName,
                              home: e.appId == kBackdropId,
                            ),
                          DashedAdd(
                            key: const Key('classic-whats-playing'),
                            label: 'What\'s playing',
                            onTap: () => allowWhatsPlaying(context, ref),
                          ),
                        ],
                      ),
                    ],
                    if (_mode == ClassicMode.volume) ...[
                      const SizedBox(height: Gap.f13),
                      ListRow(
                        key: const Key('classic-max-volume'),
                        title: 'Loudest',
                        value: '$_maxVol%',
                        valueColor: bt.ink,
                      ),
                      Slider(
                        key: const Key('classic-volume-slider'),
                        value: _maxVol.toDouble(),
                        min: 1,
                        max: 100,
                        label: '$_maxVol%',
                        onChanged: (v) => setState(() => _maxVol = v.round()),
                      ),
                    ],
                  ],
                ),
        ),
        const GroupHeading('For how long'),
        ChipRow(
          children: [
            for (final m in durations)
              BtChip(
                key: Key('classic-duration-$m'),
                label: _durationShort(m),
                selected: !other && _duration == m,
                onTap: () => setState(() {
                  _customDuration = false;
                  _durationCtrl.text = '$m';
                }),
              ),
          ],
        ),
        const SizedBox(height: Gap.f8),
        RowList(
          children: [
            ListRow(
              key: const Key('classic-duration-other'),
              title: 'Another length',
              value: other ? _durationWords(_duration) : null,
              chevron: false,
              trailing: Icon(
                other
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: Sizes.iconControl,
                color: other ? bt.coralInk : bt.faint,
              ),
              onTap: () => setState(() => _customDuration = true),
            ),
          ],
        ),
        AnimatedSize(
          duration: Motion.of(context, Motion.sheet),
          curve: Motion.enter,
          alignment: Alignment.topCenter,
          child: !other
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(bottom: Gap.f13),
                  child: _NumberField(
                    key: const Key('classic-duration'),
                    label: 'Minutes',
                    suffix: 'min',
                    hint: '1–1440',
                    controller: _durationCtrl,
                  ),
                ),
        ),
        const SizedBox(height: Gap.f8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: const Key('classic-advanced'),
            style: TextButton.styleFrom(
              foregroundColor: bt.muted,
              padding: const EdgeInsets.symmetric(horizontal: Gap.f8),
            ),
            onPressed: () => setState(() => _advanced = !_advanced),
            icon: AnimatedRotation(
              turns: _advanced ? 0.5 : 0,
              duration: Motion.of(context, Motion.flip),
              child: const Icon(Icons.expand_more_rounded, size: Sizes.icon),
            ),
            label: const Text('Advanced options'),
          ),
        ),
        AnimatedSize(
          duration: Motion.of(context, Motion.sheet),
          curve: Motion.enter,
          alignment: Alignment.topCenter,
          child: !_advanced
              ? const SizedBox(width: double.infinity)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _NumberField(
                      key: const Key('classic-interval'),
                      label: 'Check the TV every',
                      suffix: 'sec',
                      hint: '5–300',
                      controller: _intervalCtrl,
                    ),
                    const SizedBox(height: Gap.f4),
                    Text(
                      'Shorter catches apps sooner but uses more battery.',
                      style: text.bodySmall,
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  /// What the lock did, as plain lines on the canvas.
  Widget _feedView(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final bt = context.bt;
    final status = StatusColors.of(context);
    return Column(
      key: const Key('classic-feed'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GroupHeading(
          'What the lock did',
          trailing: _active
              ? Container(
                  width: Sizes.dot,
                  height: Sizes.dot,
                  decoration: BoxDecoration(
                    color: bt.sky,
                    shape: BoxShape.circle,
                  ),
                )
              : null,
        ),
        if (_feed.isEmpty)
          Text('Waiting for the first check…', style: text.bodySmall)
        else
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: Sizes.band * 2),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _feed.length,
              itemBuilder: (context, i) {
                final e = _feed[_feed.length - 1 - i];
                final color = e.isStopped
                    ? status.bad
                    : e.message.contains('whitelisted')
                        ? status.ok
                        : bt.inkSoft;
                return Padding(
                  padding: const EdgeInsets.only(bottom: Gap.f4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: Sizes.row,
                        child: Text(
                          clockTime(e.timestamp),
                          style: text.bodySmall!.copyWith(
                            fontFeatures: Fonts.tabular,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          e.message,
                          style: text.bodySmall!.copyWith(color: color),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  static String _durationShort(int m) =>
      m < 60 ? '$m min' : (m % 60 == 0 ? '${m ~/ 60} h' : '$m min');

  static String _durationWords(int m) {
    if (m < 60) return '$m min';
    final h = m ~/ 60;
    final r = m % 60;
    final hs = h == 1 ? '1 hour' : '$h hours';
    return r == 0 ? hs : '$hs $r min';
  }
}

class _AllowedPill extends StatelessWidget {
  final String label;
  final bool home;
  const _AllowedPill({required this.label, required this.home});

  @override
  Widget build(BuildContext context) {
    final bt = context.bt;
    return Container(
      constraints: const BoxConstraints(minHeight: Sizes.chip),
      padding: const EdgeInsets.symmetric(horizontal: Gap.f13),
      decoration: BoxDecoration(color: bt.wash, borderRadius: Radii.chip),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            home ? Icons.home_rounded : Icons.check_rounded,
            size: Sizes.iconSmall,
            color: home ? bt.muted : bt.mintInk,
          ),
          const SizedBox(width: Gap.f4),
          Text(label, style: Theme.of(context).textTheme.labelMedium),
        ],
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  final String label;
  final String suffix;
  final String hint;
  final TextEditingController controller;

  const _NumberField({
    super.key,
    required this.label,
    required this.suffix,
    required this.hint,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      children: [
        Expanded(child: Text(label, style: text.bodyMedium)),
        SizedBox(
          width: Sizes.band + Sizes.chip,
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            textAlign: TextAlign.center,
            style: text.titleSmall!.copyWith(fontFeatures: Fonts.tabular),
            decoration: InputDecoration(
              isDense: true,
              hintText: hint,
              suffixText: suffix,
            ),
          ),
        ),
      ],
    );
  }
}
