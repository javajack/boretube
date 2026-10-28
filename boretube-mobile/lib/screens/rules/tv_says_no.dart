import 'package:flutter/material.dart';

import '../../agent/agent_models.dart';
import '../../ui/tokens.dart';
import '../../ui/tubby.dart';

/// A small picture of the TV at the moment a rule kicks in: Tubby's
/// friendly card, or (quietly) just the home screen.
class TvSaysNoPreview extends StatelessWidget {
  final RuleStyle style;

  /// "7:00 am": when TV time comes back, for the friendly card.
  final String? backAt;

  /// Other words for the friendly card (e.g. the Shorts card).
  final String? headline;
  final String? message;

  const TvSaysNoPreview({
    super.key,
    required this.style,
    this.backAt,
    this.headline,
    this.message,
  });

  static const _night = Color(0xFF15162E);
  static const _glow = Color(0xFF2D2F66);
  static const _cream = Color(0xFFFFF8F1);
  static const _gold = Color(0xFFFFD27A);

  @override
  Widget build(BuildContext context) {
    final bt = context.bt;
    final friendly = style == RuleStyle.explicit;
    return Semantics(
      label: friendly
          ? 'On the TV: Tubby says ${headline ?? 'that\'s all for tonight'}'
          : 'On the TV: the app closes and the home screen shows',
      excludeSemantics: true,
      // tokens:off — a drawn TV (bezel, stand); not layout.
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: bt.screen,
              borderRadius: BorderRadius.circular(Radii.controlR),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(Radii.controlR - 4),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: AnimatedSwitcher(
                  duration: Motion.of(context, Motion.sheet),
                  switchInCurve: Motion.enter,
                  child: friendly
                      ? _Friendly(
                          key: const ValueKey('friendly'),
                          backAt: backAt,
                          headline: headline,
                          message: message,
                        )
                      : const _Quiet(key: ValueKey('quiet')),
                ),
              ),
            ),
          ),
          // The stand.
          Container(
            width: 56,
            height: 6,
            decoration: BoxDecoration(
              color: bt.screen,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(4),
              ),
            ),
          ),
        ],
      ),
      // tokens:on
    );
  }
}

class _Friendly extends StatelessWidget {
  final String? backAt;
  final String? headline;
  final String? message;
  const _Friendly({super.key, this.backAt, this.headline, this.message});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    // tokens:off — the TV card drawn to scale ([k]); illustration only.
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final k = (w / 300).clamp(0.7, 1.3);
        return DecoratedBox(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(-0.4, -0.4),
              radius: 1.2,
              colors: [TvSaysNoPreview._glow, TvSaysNoPreview._night],
            ),
          ),
          child: Stack(
            children: [
              for (final (x, y, s, gold) in const [
                (0.08, 0.16, 4.0, true),
                (0.2, 0.08, 3.0, false),
                (0.86, 0.18, 3.5, false),
                (0.74, 0.84, 3.0, true),
              ])
                Positioned(
                  left: w * x,
                  top: c.maxHeight * y,
                  child: Container(
                    width: s,
                    height: s,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: (gold
                              ? TvSaysNoPreview._gold
                              : TvSaysNoPreview._cream)
                          .withValues(alpha: 0.75),
                    ),
                  ),
                ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 14 * k),
                child: Row(
                  children: [
                    Tubby(
                      mood: TubbyMood.asleep,
                      size: 76 * k,
                      body: const Color(0xFFFFB020),
                      screen: const Color(0xFF2A2B4D),
                      animate: false,
                    ),
                    SizedBox(width: 12 * k),
                    Expanded(
                      child: MediaQuery.withNoTextScaling(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'TUBBY SAYS',
                              style: text.labelSmall!.copyWith(
                                color: TvSaysNoPreview._gold,
                                fontSize: 9 * k,
                                letterSpacing: 1.2,
                              ),
                            ),
                            SizedBox(height: 3 * k),
                            Text(
                              headline ?? 'That\'s all for tonight.',
                              style: Fonts.bricolage(
                                19 * k,
                                height: 1.05,
                                letterSpacing: -0.3,
                                color: TvSaysNoPreview._cream,
                              ),
                            ),
                            SizedBox(height: 4 * k),
                            Text(
                              message ??
                                  (backAt == null
                                      ? 'The TV is resting. See you later.'
                                      : 'The TV is resting. See you at '
                                          '$backAt.'),
                              maxLines: 2,
                              style: text.bodySmall!.copyWith(
                                color: const Color(0xFFD8D9F2),
                                fontSize: 10.5 * k,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
    // tokens:on
  }
}

class _Quiet extends StatelessWidget {
  const _Quiet({super.key});

  @override
  Widget build(BuildContext context) {
    const tiles = [
      Color(0xFFFF3D2E),
      Color(0xFF141414),
      Color(0xFF1A98FF),
      Color(0xFF113CCF),
      Color(0xFF1DB954),
    ];
    // tokens:off — a drawn TV home screen, scaled by [k]; illustration only.
    return LayoutBuilder(
      builder: (context, c) {
        final k = (c.maxWidth / 300).clamp(0.7, 1.3);
        return ColoredBox(
          color: const Color(0xFF202233),
          child: Padding(
            padding: EdgeInsets.all(14 * k),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 52 * k,
                      height: 7 * k,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.home_rounded,
                      size: 14 * k,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ],
                ),
                const Spacer(),
                Row(
                  children: [
                    for (var i = 0; i < tiles.length; i++) ...[
                      if (i > 0) SizedBox(width: 7 * k),
                      Expanded(
                        child: AspectRatio(
                          aspectRatio: 1.5,
                          child: Container(
                            decoration: BoxDecoration(
                              color: tiles[i],
                              borderRadius: BorderRadius.circular(5 * k),
                              border: i == 0
                                  ? Border.all(color: Colors.white, width: 1.5)
                                  : null,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                SizedBox(height: 10 * k),
                Container(
                  width: 120 * k,
                  height: 6 * k,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    // tokens:on
  }
}
