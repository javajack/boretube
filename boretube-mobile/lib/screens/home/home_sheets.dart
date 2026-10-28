import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/now_playing.dart';
import '../../ui/components.dart';
import '../../ui/learn.dart';
import '../../ui/tokens.dart';
import 'home_logic.dart';

/// One line in "What works right now" and the level it needs.
typedef WorksLine = ({String label, Protection needs});

const worksLines = <WorksLine>[
  (
    label: 'Pause, Quiet and End app from your phone',
    needs: Protection.remote,
  ),
  (label: 'Lock for a while, while this app is open', needs: Protection.remote),
  (label: 'YouTube without Shorts, Clean TV', needs: Protection.home),
  (
    label: 'Bedtime and quiet hours when you\'re away',
    needs: Protection.alwaysOn,
  ),
  (
    label: 'Tidying up by itself after TV updates',
    needs: Protection.alwaysOn,
  ),
];

/// "What works right now": the three levels, where this TV is, what each
/// one allows, and the one step up.
class WhatWorksSheet extends StatelessWidget {
  final String tvName;
  final Protection level;

  /// Always On is installed but not answering: its lines are not working.
  final bool degraded;
  final VoidCallback? onUnlockHome;
  final VoidCallback? onAlwaysOn;

  const WhatWorksSheet({
    super.key,
    required this.tvName,
    required this.level,
    this.degraded = false,
    this.onUnlockHome,
    this.onAlwaysOn,
  });

  bool _works(Protection needs) {
    if (needs.index > level.index) return false;
    if (needs == Protection.alwaysOn && degraded) return false;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final bt = context.bt;
    final text = Theme.of(context).textTheme;
    final levelColor = level.tone.color(context);
    return SheetScaffold(
      key: const Key('what-works'),
      title: 'What works right now',
      lead: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: '$tvName is in '),
            TextSpan(
              text: level.label,
              style: TextStyle(
                color: levelColor,
                fontWeight: FontWeight.w700,
              ),
            ),
            TextSpan(text: '. ${level.reach}'),
          ],
        ),
      ),
      children: [
        Row(
          children: [
            for (final p in Protection.values) ...[
              if (p != Protection.remote) const SizedBox(width: Gap.f8),
              Expanded(child: _LevelTile(level: p, current: level)),
            ],
          ],
        ),
        const SizedBox(height: Gap.f4),
        const Wrap(
          spacing: Gap.f4,
          children: [
            _LearnLink('What\'s Home mode?', LearnTerm.homeMode),
            _LearnLink('What\'s Always On?', LearnTerm.alwaysOn),
          ],
        ),
        const SizedBox(height: Gap.f8),
        RowList(
          children: [
            for (var i = 0; i < worksLines.length; i++)
              CheckLine(
                worksLines[i].label,
                key: Key('works-$i'),
                done: _works(worksLines[i].needs),
                minHeight: Sizes.control,
              ),
          ],
        ),
        const SizedBox(height: Gap.related),
        switch (level) {
          Protection.remote => PrimaryButton(
              key: const Key('works-unlock'),
              label: 'Unlock Home mode',
              icon: Icons.home_rounded,
              kind: ButtonKind.ink,
              onPressed: onUnlockHome,
            ),
          Protection.home => PrimaryButton(
              key: const Key('works-always-on'),
              label: 'Make it Always On',
              icon: Icons.shield_rounded,
              kind: ButtonKind.mint,
              onPressed: onAlwaysOn,
            ),
          Protection.alwaysOn => Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  degraded ? Icons.error_rounded : Icons.verified_rounded,
                  color: degraded ? bt.berryFill : bt.mintInk,
                  size: Sizes.icon,
                ),
                const SizedBox(width: Gap.f8),
                Flexible(
                  child: Text(
                    degraded
                        ? 'Always On needs a hand. Fix it from Home.'
                        : 'You\'re all set. Nothing more to unlock.',
                    style: text.titleSmall,
                  ),
                ),
              ],
            ),
        },
        const SizedBox(height: Gap.f8),
        if (level != Protection.alwaysOn)
          Text(
            level == Protection.remote
                ? 'One switch on the TV, about 3 minutes. We can put it '
                    'back any time.'
                : 'A tiny helper on the TV. One tap here, one OK on the TV.',
            textAlign: TextAlign.center,
            style: text.bodySmall,
          ),
      ],
    );
  }
}

/// "What's Home mode? ⓘ": a quiet link to the term's Learn sheet.
class _LearnLink extends StatelessWidget {
  final String label;
  final LearnTerm term;

  const _LearnLink(this.label, this.term);

  @override
  Widget build(BuildContext context) {
    final bt = context.bt;
    return TextButton.icon(
      key: Key('works-learn-${term.name}'),
      style: TextButton.styleFrom(
        foregroundColor: bt.skyInk,
        padding: const EdgeInsets.symmetric(horizontal: Gap.f8),
      ),
      onPressed: () => showLearnSheet(context, term),
      icon: const Icon(Icons.info_outline_rounded, size: Sizes.iconSmall),
      label: Text(label),
    );
  }
}

class _LevelTile extends StatelessWidget {
  final Protection level;
  final Protection current;

  const _LevelTile({required this.level, required this.current});

  @override
  Widget build(BuildContext context) {
    final bt = context.bt;
    final text = Theme.of(context).textTheme;
    final here = level == current;
    final done = level.index < current.index;
    final next = level.index == current.index + 1;
    final ink = level.tone.color(context);
    final state = here
        ? 'you are here'
        : done
            ? 'done'
            : next
                ? 'one step'
                : 'later';
    return Semantics(
      label: '${level.label}: $state',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Gap.f4,
          vertical: Gap.f13,
        ),
        decoration: BoxDecoration(
          color: here ? level.tone.tint(context) : Colors.transparent,
          borderRadius: Radii.control,
          border: here
              ? Border.all(
                  color: level.tone.hue(context).withValues(alpha: 0.6))
              : Border.all(
                  color: next
                      ? level.tone.hue(context).withValues(
                            alpha: 0.4,
                          )
                      : bt.border,
                ),
        ),
        child: Column(
          children: [
            Icon(
              done ? Icons.check_rounded : level.icon,
              size: Sizes.iconControl,
              color: done ? bt.mint : (here || next ? ink : bt.faint),
            ),
            const SizedBox(height: Gap.f4),
            Text(
              level.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.labelMedium!.copyWith(
                fontWeight: FontWeight.w700,
                color: here ? ink : bt.ink,
              ),
            ),
            Text(
              state,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.bodySmall!.copyWith(
                color: here ? ink : bt.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Volume, with a big number and a slider; sends on release.
class VolumeSheet extends ConsumerStatefulWidget {
  final void Function(int target) onSet;

  const VolumeSheet({super.key, required this.onSet});

  @override
  ConsumerState<VolumeSheet> createState() => _VolumeSheetState();
}

class _VolumeSheetState extends ConsumerState<VolumeSheet> {
  double? _drag;

  void _send(int v) {
    final t = v.clamp(0, 100);
    setState(() => _drag = null);
    widget.onSet(t);
  }

  @override
  Widget build(BuildContext context) {
    final bt = context.bt;
    final text = Theme.of(context).textTheme;
    final now = ref.watch(nowPlayingProvider);
    final current = (now.volume ?? 0).toDouble().clamp(0.0, 100.0);
    final shown = _drag ?? current;
    final muted = now.muted == true;
    return SheetScaffold(
      key: const Key('volume-sheet'),
      title: 'Volume',
      lead: Text(muted ? 'The TV is muted.' : 'Changes when you let go.'),
      children: [
        Center(
          child: Text(
            '${shown.round()}',
            style: text.displayMedium!.copyWith(
              color: muted ? bt.muted : bt.ink,
            ),
          ),
        ),
        const SizedBox(height: Gap.f8),
        Row(
          children: [
            IconButton(
              key: const Key('volume-down'),
              tooltip: 'Quieter',
              onPressed: () => _send(shown.round() - 5),
              icon: const Icon(Icons.volume_down_rounded),
            ),
            Expanded(
              child: Slider(
                key: const Key('volume-slider'),
                value: shown,
                max: 100,
                divisions: 100,
                label: '${shown.round()}',
                onChanged: (v) {
                  if (v.round() != shown.round()) {
                    HapticFeedback.selectionClick();
                  }
                  setState(() => _drag = v);
                },
                onChangeEnd: (v) => _send(v.round()),
              ),
            ),
            IconButton(
              key: const Key('volume-up'),
              tooltip: 'Louder',
              onPressed: () => _send(shown.round() + 5),
              icon: const Icon(Icons.volume_up_rounded),
            ),
          ],
        ),
      ],
    );
  }
}

/// ⋯: the optional tricks.
class MoreSheet extends StatelessWidget {
  final VoidCallback? onBore;
  final VoidCallback? onSoundBack;
  final void Function(int minutes)? onQuietFor;

  const MoreSheet({
    super.key,
    this.onBore,
    this.onSoundBack,
    this.onQuietFor,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    void pop(VoidCallback f) {
      Navigator.pop(context);
      f();
    }

    return SheetScaffold(
      key: const Key('more-sheet'),
      title: 'More',
      children: [
        RowList(
          children: [
            if (onBore != null)
              StatusRow(
                key: const Key('action-bore'),
                tone: Tone.info,
                icon: Icons.bedtime_rounded,
                title: 'Make it boring',
                detail: 'Closes the app and mutes. The TV just sits there.',
                trailing: const InfoDot(LearnTerm.makeItBoring),
                onTap: () => pop(onBore!),
              ),
            if (onSoundBack != null)
              StatusRow(
                key: const Key('action-restore'),
                tone: Tone.ok,
                icon: Icons.volume_up_rounded,
                title: 'Sound back on',
                detail: 'Unmutes and ends any quiet time.',
                onTap: () => pop(onSoundBack!),
              ),
          ],
        ),
        if (onQuietFor != null) ...[
          const GroupHeading('Quiet for a while'),
          Text(
            'Mutes now; the show keeps playing. Sound comes back by itself.',
            style: text.bodySmall,
          ),
          const SizedBox(height: Gap.f13),
          ChipRow(
            children: [
              for (final m in const [15, 30, 60])
                BtChip(
                  key: Key('quiet-$m'),
                  label: m == 60 ? '1 hour' : '$m min',
                  selected: false,
                  onTap: () {
                    Navigator.pop(context);
                    onQuietFor!(m);
                  },
                ),
            ],
          ),
        ],
      ],
    );
  }
}
