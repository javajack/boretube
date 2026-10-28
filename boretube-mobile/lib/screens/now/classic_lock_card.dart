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
/// (5–300 s) under Advanced options. Runs in the foreground service via
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

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final bt = context.bt;
    final locked = _active;
    return Surface(
      key: const Key('classic-lock'),
      borderColor: locked ? bt.sky : null,
      radius: Radii.hero,
      padding: const EdgeInsets.all(Gap.f13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconTile(
                icon: locked ? Icons.lock_rounded : Icons.lock_clock_rounded,
                color: locked ? bt.skyInk : bt.coralInk,
                size: 44,
              ),
              const SizedBox(width: Gap.f13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      locked ? 'Locked for a while' : 'Lock for a while',
                      style: text.titleLarge,
                    ),
                    Text(
                      locked
                          ? 'Keep this phone on the Wi-Fi until it ends.'
                          : 'This phone watches the TV and steps in.',
                      style: text.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          AnimatedSize(
            duration: Motion.of(context, Motion.sheet),
            curve: Motion.enter,
            alignment: Alignment.topCenter,
            child: locked
                ? _running(context)
                : Padding(
                    padding: const EdgeInsets.only(top: Gap.f13),
                    child: _setup(context),
                  ),
          ),
          const SizedBox(height: Gap.f13),
          PrimaryButton(
            key: const Key('classic-start-stop'),
            label: locked
                ? 'Stop the lock'
                : _mode == ClassicMode.none
                    ? 'Pick what to lock'
                    : 'Lock for ${_durationWords(_duration)}',
            icon: locked ? Icons.stop_rounded : Icons.lock_rounded,
            kind: locked ? ButtonKind.berry : ButtonKind.coral,
            onPressed:
                locked ? _stop : (_mode == ClassicMode.none ? null : _start),
          ),
          if (_feed.isNotEmpty || locked) ...[
            const SizedBox(height: Gap.f13),
            _feedView(context),
          ],
        ],
      ),
    );
  }

  Widget _running(BuildContext context) {
    final bt = context.bt;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: Gap.f13),
      child: Container(
        padding: const EdgeInsets.all(Gap.f13),
        decoration: BoxDecoration(
          color: bt.skyTint,
          borderRadius: Radii.control,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _remaining > 0 ? formatRemaining(_remaining) : '…',
                    key: const Key('classic-remaining'),
                    style: Fonts.bricolage(
                      34,
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
              ),
            ),
            Icon(Icons.lock_rounded, color: bt.sky, size: 32),
          ],
        ),
      ),
    );
  }

  Widget _setup(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final bt = context.bt;
    final whitelist = ref.watch(whitelistProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('WHAT TO LOCK', style: text.labelSmall),
        const SizedBox(height: Gap.f8),
        ChoiceCard(
          key: const Key('classic-mode-apps'),
          selected: _mode == ClassicMode.apps,
          icon: Icons.apps_rounded,
          title: 'Only allowed apps',
          body: 'Anything else is stopped and muted.',
          onTap: () => setState(
            () => _mode =
                _mode == ClassicMode.apps ? ClassicMode.none : ClassicMode.apps,
          ),
        ),
        const SizedBox(height: Gap.f8),
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
                      const SizedBox(height: Gap.f13),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'ALLOWED · ${whitelist.length}',
                              style: text.labelSmall,
                            ),
                          ),
                          TextButton(
                            key: const Key('classic-whitelist'),
                            onPressed: () => context.push('/whitelist'),
                            child: const Text('Edit'),
                          ),
                        ],
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
                      Row(
                        children: [
                          Expanded(
                            child: Text('LOUDEST', style: text.labelSmall),
                          ),
                          Text(
                            '$_maxVol%',
                            key: const Key('classic-max-volume'),
                            style: Fonts.bricolage(
                              20,
                              color: bt.ink,
                              tabularFigures: true,
                            ),
                          ),
                        ],
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
        const SizedBox(height: Gap.f13),
        Text('FOR HOW LONG', style: text.labelSmall),
        const SizedBox(height: Gap.f8),
        Wrap(
          spacing: Gap.f8,
          runSpacing: Gap.f8,
          children: [
            for (final m in durations)
              BtChip(
                key: Key('classic-duration-$m'),
                label: _durationShort(m),
                selected: !_customDuration && _duration == m,
                onTap: () => setState(() {
                  _customDuration = false;
                  _durationCtrl.text = '$m';
                }),
              ),
            BtChip(
              key: const Key('classic-duration-other'),
              label: 'Other',
              selected: _customDuration || !durations.contains(_duration),
              onTap: () => setState(() => _customDuration = true),
            ),
          ],
        ),
        AnimatedSize(
          duration: Motion.of(context, Motion.sheet),
          curve: Motion.enter,
          alignment: Alignment.topCenter,
          child: !(_customDuration || !durations.contains(_duration))
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: Gap.f13),
                  child: _NumberField(
                    key: const Key('classic-duration'),
                    label: 'Minutes',
                    suffix: 'min',
                    hint: '1–1440',
                    controller: _durationCtrl,
                  ),
                ),
        ),
        const SizedBox(height: Gap.f13),
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
              child: const Icon(Icons.expand_more_rounded, size: 20),
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

  Widget _feedView(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final bt = context.bt;
    final status = StatusColors.of(context);
    return Container(
      key: const Key('classic-feed'),
      decoration: BoxDecoration(
        color: bt.canvas,
        borderRadius: Radii.control,
        border: Border.all(color: bt.hairline),
      ),
      padding: const EdgeInsets.all(Gap.f13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('WHAT THE LOCK DID', style: text.labelSmall),
              const Spacer(),
              if (_active)
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: bt.sky,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
          const SizedBox(height: Gap.f8),
          if (_feed.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Gap.f8),
              child:
                  Text('Waiting for the first check…', style: text.bodySmall),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
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
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 64,
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
      ),
    );
  }

  static String _durationShort(int m) =>
      m < 60 ? '${m}m' : (m % 60 == 0 ? '${m ~/ 60}h' : '${m}m');

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
      constraints: const BoxConstraints(minHeight: 44),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: ShapeDecoration(
        color: bt.hairline,
        shape: const StadiumBorder(),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            home ? Icons.home_rounded : Icons.check_rounded,
            size: 16,
            color: home ? bt.muted : bt.mintInk,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style:
                Theme.of(context).textTheme.labelLarge!.copyWith(fontSize: 14),
          ),
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
          width: 128,
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
