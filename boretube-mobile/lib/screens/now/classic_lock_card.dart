import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/log_entry.dart';
import '../../providers/providers.dart';
import '../../providers/tv_providers.dart';
import '../../ui/components.dart';
import '../../ui/format.dart';
import '../../ui/tokens.dart';

/// Lock mode — mutually exclusive (as in v1).
enum ClassicMode { none, apps, volume }

/// The v1 timed lock, ported: mode, check interval (5–300 s), max volume
/// (1–100 %), duration (1–1440 min), start/stop, countdown and live
/// feed. Runs in the foreground service via [LockService].
class ClassicLockCard extends ConsumerStatefulWidget {
  const ClassicLockCard({super.key});

  @override
  ConsumerState<ClassicLockCard> createState() => _ClassicLockCardState();
}

class _ClassicLockCardState extends ConsumerState<ClassicLockCard> {
  ClassicMode _mode = ClassicMode.none;
  final _intervalCtrl = TextEditingController(text: '10');
  final _maxVolCtrl = TextEditingController(text: '15');
  final _durationCtrl = TextEditingController(text: '60');

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
  }

  @override
  void dispose() {
    _intervalCtrl.dispose();
    _maxVolCtrl.dispose();
    _durationCtrl.dispose();
    _logSub?.cancel();
    _remainingSub?.cancel();
    _activeSub?.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    if (_mode == ClassicMode.none) return;
    final tv = ref.read(activeTvProvider);
    if (tv == null) return;
    final whitelist = ref.read(whitelistProvider);
    final ls = ref.read(lockServiceProvider);
    final interval = (int.tryParse(_intervalCtrl.text) ?? 10).clamp(5, 300);
    final maxVol = (int.tryParse(_maxVolCtrl.text) ?? 15).clamp(1, 100);
    final duration = (int.tryParse(_durationCtrl.text) ?? 60).clamp(1, 1440);
    _intervalCtrl.text = '$interval';
    _maxVolCtrl.text = '$maxVol';
    _durationCtrl.text = '$duration';
    HapticFeedback.mediumImpact();
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
    HapticFeedback.mediumImpact();
    await ref.read(lockServiceProvider).stop();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final status = StatusColors.of(context);
    final disabled = _active;
    return InfoCard(
      borderColor: _active ? status.info.withValues(alpha: 0.6) : null,
      padding: const EdgeInsets.all(Gap.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconBadge(
                icon: _active ? Icons.lock_rounded : Icons.lock_clock_rounded,
                color: _active ? status.info : scheme.primary,
              ),
              const SizedBox(width: Gap.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _active ? 'Lock running' : 'Timed lock',
                      style: text.titleMedium,
                    ),
                    Text(
                      'This phone checks the TV and steps in.',
                      style: text.bodySmall,
                    ),
                  ],
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: _active && _remaining > 0
                    ? TagChip(
                        '${formatRemaining(_remaining)} left',
                        key: const ValueKey('remaining'),
                        tone: Tone.info,
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
          const SizedBox(height: Gap.lg),
          _ModeOption(
            mode: ClassicMode.none,
            selected: _mode,
            icon: Icons.lock_open_rounded,
            label: 'No lock',
            subtitle: 'TV is unrestricted',
            disabled: disabled,
            onSelect: _select,
          ),
          const SizedBox(height: Gap.sm),
          _ModeOption(
            mode: ClassicMode.apps,
            selected: _mode,
            icon: Icons.block_rounded,
            label: 'Lock apps',
            subtitle: 'Only whitelisted apps allowed',
            disabled: disabled,
            onSelect: _select,
          ),
          const SizedBox(height: Gap.sm),
          _ModeOption(
            mode: ClassicMode.volume,
            selected: _mode,
            icon: Icons.volume_down_rounded,
            label: 'Lock volume',
            subtitle: 'Cap max volume',
            disabled: disabled,
            onSelect: _select,
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: _mode == ClassicMode.none
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(top: Gap.lg),
                    child: _options(disabled),
                  ),
          ),
          const SizedBox(height: Gap.lg),
          FilledButton.icon(
            key: const Key('classic-start-stop'),
            onPressed:
                _active ? _stop : (_mode == ClassicMode.none ? null : _start),
            style: _active
                ? FilledButton.styleFrom(
                    backgroundColor: context.bt.berryFill,
                    foregroundColor: Colors.white,
                  )
                : null,
            icon: Icon(_active ? Icons.stop_rounded : Icons.lock_rounded),
            label: Text(_active ? 'Stop lock' : 'Start lock'),
          ),
          const SizedBox(height: Gap.lg),
          _feedView(context),
        ],
      ),
    );
  }

  void _select(ClassicMode m) => setState(() => _mode = m);

  Widget _options(bool disabled) {
    final interval = _NumberField(
      label: 'Check every',
      suffix: 'sec',
      controller: _intervalCtrl,
      enabled: !disabled,
      hint: '5–300',
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_mode == ClassicMode.volume) ...[
          _NumberField(
            label: 'Max volume',
            suffix: '%',
            controller: _maxVolCtrl,
            enabled: !disabled,
            hint: '1–100',
          ),
          const SizedBox(height: Gap.md),
        ],
        interval,
        const SizedBox(height: Gap.md),
        _NumberField(
          label: 'Duration',
          suffix: 'min',
          controller: _durationCtrl,
          enabled: !disabled,
          hint: '1–1440',
          icon: Icons.timer_outlined,
        ),
        if (_mode == ClassicMode.apps) ...[
          const SizedBox(height: Gap.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => context.push('/whitelist'),
              icon: const Icon(Icons.checklist_rounded),
              label: const Text('Whitelist'),
            ),
          ),
        ],
      ],
    );
  }

  Widget _feedView(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final status = StatusColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: Radii.tile,
      ),
      padding: const EdgeInsets.all(Gap.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('LIVE FEED', style: text.labelSmall),
              const Spacer(),
              if (_active)
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: status.info,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
          const SizedBox(height: Gap.sm),
          if (_feed.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Gap.md),
              child: Text(
                _active
                    ? 'Waiting for first check…'
                    : 'Start a lock to see activity',
                style: text.bodySmall,
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _feed.length,
                itemBuilder: (context, i) {
                  final e = _feed[_feed.length - 1 - i];
                  final t = e.timestamp;
                  final ts = '${t.hour.toString().padLeft(2, '0')}:'
                      '${t.minute.toString().padLeft(2, '0')}:'
                      '${t.second.toString().padLeft(2, '0')}';
                  final color = e.isStopped
                      ? status.bad
                      : e.message.contains('whitelisted')
                          ? status.ok
                          : scheme.onSurfaceVariant;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Text(
                      '[$ts] ${e.message}',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12.5,
                        color: color,
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _ModeOption extends StatelessWidget {
  final ClassicMode mode;
  final ClassicMode selected;
  final IconData icon;
  final String label;
  final String subtitle;
  final bool disabled;
  final ValueChanged<ClassicMode> onSelect;

  const _ModeOption({
    required this.mode,
    required this.selected,
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.disabled,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final on = mode == selected;
    return Semantics(
      selected: on,
      button: true,
      enabled: !disabled,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: on
              ? scheme.primary.withValues(alpha: 0.12)
              : scheme.surfaceContainer,
          borderRadius: Radii.tile,
          border: Border.all(
            color: on ? scheme.primary : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            key: Key('classic-mode-${mode.name}'),
            borderRadius: Radii.tile,
            onTap: disabled ? null : () => onSelect(mode),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Gap.md,
                vertical: Gap.md,
              ),
              child: Row(
                children: [
                  Icon(
                    icon,
                    color: on ? scheme.primary : scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: Gap.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: text.titleSmall?.copyWith(
                            color: disabled && !on
                                ? scheme.onSurfaceVariant
                                : null,
                          ),
                        ),
                        Text(subtitle, style: text.bodySmall),
                      ],
                    ),
                  ),
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: on ? 1 : 0,
                    child: Icon(
                      Icons.check_circle_rounded,
                      color: scheme.primary,
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

class _NumberField extends StatelessWidget {
  final String label;
  final String suffix;
  final String hint;
  final TextEditingController controller;
  final bool enabled;
  final IconData? icon;

  const _NumberField({
    required this.label,
    required this.suffix,
    required this.hint,
    required this.controller,
    required this.enabled,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 18),
          const SizedBox(width: Gap.sm),
        ],
        Expanded(child: Text(label, style: text.bodyMedium)),
        SizedBox(
          width: 120,
          child: TextField(
            controller: controller,
            enabled: enabled,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            textAlign: TextAlign.center,
            style: text.titleSmall,
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
