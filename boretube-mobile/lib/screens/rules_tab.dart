import 'package:flutter/material.dart';

import '../ui/components.dart';
import '../ui/tokens.dart';

/// P1 placeholder: TV Guard rules arrive in the next phase.
class RulesTab extends StatelessWidget {
  const RulesTab({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    const items = [
      (Icons.apps_rounded, 'Allowed apps', 'Only the apps you pick open.'),
      (Icons.volume_down_rounded, 'Volume limit', 'A cap kids can\'t beat.'),
      (Icons.schedule_rounded, 'TV time', 'Daily limits and quiet hours.'),
      (Icons.visibility_off_rounded, 'Sneaky or explicit', 'Quietly stop, '
          'or show a friendly "TV time is over" card.'),
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        Gap.page,
        Gap.sm,
        Gap.page,
        Gap.xxl,
      ),
      children: [
        InfoCard(
          padding: const EdgeInsets.all(Gap.xl),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.alphaBlend(
                StatusColors.of(context).ok.withValues(alpha: 0.14),
                scheme.surfaceContainerLow,
              ),
              scheme.surfaceContainerLow,
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconBadge(
                icon: Icons.shield_moon_rounded,
                color: StatusColors.of(context).ok,
                size: 52,
              ),
              const SizedBox(height: Gap.lg),
              Text('TV Guard is coming', style: text.headlineSmall),
              const SizedBox(height: Gap.sm),
              Text(
                'Rules will live on the TV itself and work 24/7 — even '
                'when your phone is away or off. It arrives in the next '
                'update.',
                style: text.bodyMedium,
              ),
              const SizedBox(height: Gap.lg),
              const TagChip('Coming in the next phase', tone: Tone.ok),
            ],
          ),
        ),
        const SectionHeader('What you\'ll be able to set'),
        GroupCard(
          children: [
            for (final (icon, title, body) in items)
              StatusRow(
                tone: Tone.idle,
                icon: icon,
                title: title,
                detail: body,
                detailLines: 2,
              ),
          ],
        ),
        const SectionHeader('Until then'),
        InfoCard(
          child: Row(
            children: [
              Icon(Icons.lock_clock_rounded, color: scheme.primary),
              const SizedBox(width: Gap.md),
              Expanded(
                child: Text(
                  'Use the Classic lock on the Now tab. It runs from this '
                  'phone while it\'s on home Wi-Fi.',
                  style: text.bodySmall,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
