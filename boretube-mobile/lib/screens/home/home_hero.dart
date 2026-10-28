import 'package:flutter/material.dart';

import '../../providers/now_playing.dart';
import '../../ui/components.dart';
import '../../ui/format.dart';
import '../../ui/tokens.dart';
import '../../ui/tubby.dart';
import 'home_logic.dart';

/// A little TV with the current app's tile on its screen.
class TvIllustration extends StatelessWidget {
  final NowPlaying now;
  final bool off;
  final double width;

  const TvIllustration({
    super.key,
    required this.now,
    this.off = false,
    this.width = 116,
  });

  @override
  Widget build(BuildContext context) {
    final bt = context.bt;
    final look = appTileLook(now);
    final h = width * 76 / 116;
    final tile = width * 40 / 116;
    return ExcludeSemantics(
      child: SizedBox(
        width: width,
        height: h + 8,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: width,
              height: h,
              decoration: BoxDecoration(
                color: off ? bt.screenInner : bt.screen,
                borderRadius: Radii.tile,
              ),
              alignment: Alignment.center,
              child: AnimatedSwitcher(
                duration: Motion.of(context, Motion.medium),
                switchInCurve: Motion.spring,
                transitionBuilder: (c, a) => ScaleTransition(
                  scale: Tween(begin: 0.6, end: 1.0).animate(a),
                  child: FadeTransition(opacity: a, child: c),
                ),
                child: off
                    ? Icon(
                        Icons.power_settings_new_rounded,
                        key: const ValueKey('off'),
                        color: bt.faint,
                        size: tile * 0.8,
                      )
                    : Container(
                        key: ValueKey(now.id ?? 'home'),
                        width: tile,
                        height: tile,
                        decoration: BoxDecoration(
                          color: look.color,
                          borderRadius: Radii.icon,
                        ),
                        alignment: Alignment.center,
                        child: look.icon != null
                            ? Icon(
                                look.icon,
                                color: Colors.white,
                                size: tile * 0.62,
                              )
                            : Text(
                                look.glyph,
                                style: Fonts.bricolage(
                                  tile * 0.5,
                                  color: look.color.computeLuminance() < 0.05
                                      ? const Color(0xFFE50914)
                                      : Colors.white,
                                  height: 1,
                                ),
                              ),
                      ),
              ),
            ),
            Positioned(
              bottom: 0,
              left: (width - 36) / 2,
              child: Container(
                width: 36,
                height: 6,
                decoration: BoxDecoration(
                  color: bt.screen,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The calm (or offline) hero: what's on, volume, a status sentence and
/// the protection badge.
class HomeHero extends StatelessWidget {
  final String tvName;
  final NowPlaying now;
  final String sentence;
  final Tone sentenceTone;
  final Protection protection;
  final VoidCallback onBadge;
  final VoidCallback? onRetry;

  const HomeHero({
    super.key,
    required this.tvName,
    required this.now,
    required this.sentence,
    required this.sentenceTone,
    required this.protection,
    required this.onBadge,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final bt = context.bt;
    final text = Theme.of(context).textTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final off = !now.online && !now.loading;
    final muted = now.muted == true;
    final String eyebrow;
    final String title;
    final String detail;
    if (now.loading) {
      eyebrow = 'Checking the TV…';
      title = tvName;
      detail = 'One moment';
    } else if (off) {
      eyebrow = 'Not answering';
      title = '$tvName is off';
      detail = now.lastSeen == null
          ? 'Is it on, and on this Wi-Fi?'
          : 'Last seen ${_seen(context, now.lastSeen!)}';
    } else {
      eyebrow = now.isHome ? 'Nothing playing' : 'Watching now';
      title = now.isHome
          ? 'Home screen'
          : now.appName.isEmpty
              ? 'Something on'
              : now.appName;
      detail = muted
          ? 'Muted'
          : now.volume == null
              ? 'Volume unknown'
              : 'Volume ${now.volume}';
    }
    return Container(
      key: const Key('home-hero'),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: const Alignment(-0.6, -1),
          end: const Alignment(0.6, 1),
          stops: const [0, 0.7],
          colors: [
            off ? bt.hairline : bt.skyTint,
            bt.surface,
          ],
        ),
        borderRadius: Radii.hero,
        border: Border.all(
          color: off
              ? bt.border
              : dark
                  ? bt.border
                  : const Color(0xFFE3ECFB),
        ),
      ),
      padding: const EdgeInsets.all(Gap.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              TvIllustration(now: now, off: off || now.loading),
              const SizedBox(width: Gap.md + 2),
              Expanded(
                child: Semantics(
                  container: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        eyebrow,
                        style: text.labelMedium!.copyWith(fontSize: 13),
                      ),
                      const SizedBox(height: 2),
                      AnimatedSwitcher(
                        duration: Motion.of(context, Motion.medium),
                        child: Text(
                          title,
                          key: ValueKey(title),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: text.headlineMedium!.copyWith(height: 1.1),
                        ),
                      ),
                      const SizedBox(height: Gap.xs),
                      Row(
                        children: [
                          if (!off && !now.loading) ...[
                            Icon(
                              muted
                                  ? Icons.volume_off_rounded
                                  : Icons.volume_up_rounded,
                              size: 16,
                              color: muted ? bt.berryFill : bt.inkSoft,
                            ),
                            const SizedBox(width: 6),
                          ],
                          Flexible(
                            child: Text(
                              detail,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: text.bodyMedium!.copyWith(fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Gap.md),
          Divider(color: dark ? bt.hairline : const Color(0xFFDCE6F7)),
          const SizedBox(height: Gap.sm),
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: sentenceTone.hue(context),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: Gap.sm),
              Expanded(
                child: Text(
                  sentence,
                  key: const Key('home-sentence'),
                  style: text.titleSmall!.copyWith(fontSize: 14),
                ),
              ),
              if (off && onRetry != null)
                TextButton(
                  key: const Key('home-retry'),
                  onPressed: onRetry,
                  child: const Text('Try again'),
                )
              else
                BtBadge(
                  protection.label,
                  key: const Key('mode-badge'),
                  tone: protection.tone,
                  icon: protection.icon,
                  onTap: onBadge,
                ),
            ],
          ),
        ],
      ),
    );
  }

  static String _seen(BuildContext context, DateTime t) {
    final now = DateTime.now();
    final sameDay =
        t.year == now.year && t.month == now.month && t.day == now.day;
    if (now.difference(t).inMinutes < 60) return relativeTime(t);
    return sameDay
        ? friendlyTime(context, t)
        : '${relativeTime(t)}, ${friendlyTime(context, t)}';
  }
}

/// The amber hero while the TV takes a break: sleeping Tubby, a big
/// tabular countdown and who keeps the break.
class PausedHero extends StatelessWidget {
  final Duration left;
  final DateTime until;
  final bool byTv;
  final bool silenceOnly;

  const PausedHero({
    super.key,
    required this.left,
    required this.until,
    required this.byTv,
    this.silenceOnly = false,
  });

  static const _brown = Color(0xFF5C3B00);
  static const _deep = Color(0xFF4A3200);

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Semantics(
      container: true,
      label: '${silenceOnly ? 'Quiet' : 'Break'}: ${countdown(left)} left',
      child: Container(
        key: const Key('break-banner'),
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(
          Gap.page,
          Gap.xl,
          Gap.page,
          Gap.page,
        ),
        decoration: BoxDecoration(
          borderRadius: Radii.hero,
          gradient: LinearGradient(
            begin: const Alignment(-0.3, -1),
            end: const Alignment(0.3, 1),
            colors: dark
                ? const [Color(0xFFE6BD6E), Color(0xFFE09C22)]
                : const [Color(0xFFFFD27A), Color(0xFFFFB020)],
          ),
        ),
        child: Column(
          children: [
            Tubby(
              mood: TubbyMood.asleep,
              size: 132,
              body: const Color(0xFFFFF8F1),
            ),
            const SizedBox(height: Gap.sm),
            Text(
              silenceOnly ? 'The TV is on quiet' : 'The TV is taking a break',
              textAlign: TextAlign.center,
              style: text.titleSmall!.copyWith(
                color: _brown,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: Gap.xs),
            Text(
              countdown(left),
              key: const Key('break-countdown'),
              style: text.displayMedium!.copyWith(
                color: const Color(0xFF1C1D3A),
              ),
            ),
            const SizedBox(height: Gap.sm),
            Text(
              'left · sound returns by itself at '
              '${friendlyTime(context, until)}',
              textAlign: TextAlign.center,
              style: text.bodyMedium!.copyWith(color: _brown),
            ),
            const SizedBox(height: Gap.md),
            Container(
              key: Key(byTv ? 'break-by-tv' : 'break-by-phone'),
              padding: const EdgeInsets.symmetric(
                horizontal: Gap.md + 2,
                vertical: Gap.sm,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(Radii.pill),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    byTv ? Icons.shield_rounded : Icons.phone_android_rounded,
                    size: 15,
                    color: _deep,
                  ),
                  const SizedBox(width: Gap.sm),
                  Flexible(
                    child: Text(
                      byTv
                          ? 'Kept by the TV, even if you close this app'
                          : 'Keep this app open',
                      style: text.labelMedium!.copyWith(color: _deep),
                    ),
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
