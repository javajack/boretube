import 'package:flutter/material.dart';

import '../../agent/agent_models.dart';
import '../../providers/now_playing.dart';
import '../../ui/components.dart';
import '../../ui/format.dart';
import '../../ui/tokens.dart';
import '../../ui/tubby.dart';
import 'home_logic.dart';

/// A little TV with the current app's tile on its screen. It fills the
/// width it is given (the 38.2 % column of the hero) at a 1.618:1 screen.
class TvIllustration extends StatelessWidget {
  final NowPlaying now;
  final bool off;

  const TvIllustration({super.key, required this.now, this.off = false});

  @override
  Widget build(BuildContext context) {
    final bt = context.bt;
    final look = appTileLook(now);
    return ExcludeSemantics(
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth;
          final h = w / Phi.ratio;
          final tile = h * Phi.minor * Phi.ratio;
          return SizedBox(
            width: w,
            height: h + Gap.f8,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedContainer(
                  duration: Motion.of(context, Motion.slow),
                  curve: Motion.enter,
                  width: w,
                  height: h,
                  decoration: BoxDecoration(
                    color: off ? bt.screenInner : bt.screen,
                    borderRadius: Radii.control,
                  ),
                  alignment: Alignment.center,
                  child: AnimatedSwitcher(
                    duration: Motion.of(context, Motion.sheet),
                    switchInCurve: Motion.enter,
                    switchOutCurve: Motion.exit,
                    child: off
                        ? Icon(
                            Icons.power_settings_new_rounded,
                            key: const ValueKey('off'),
                            color: bt.faint,
                            size: tile * Phi.major,
                          )
                        : Container(
                            key: ValueKey(now.id ?? 'home'),
                            width: tile,
                            height: tile,
                            decoration: BoxDecoration(
                              color: look.color,
                              borderRadius: Radii.chip,
                            ),
                            alignment: Alignment.center,
                            child: look.icon != null
                                ? Icon(
                                    look.icon,
                                    color: Colors.white,
                                    size: tile * Phi.major,
                                  )
                                : Text(
                                    look.glyph,
                                    style: Fonts.bricolage(
                                      tile / 2,
                                      color:
                                          look.color.computeLuminance() < 0.05
                                              ? const Color(0xFFE50914)
                                              : Colors.white,
                                      height: TypeSize.tightLeading,
                                    ),
                                  ),
                          ),
                  ),
                ),
                // The stand: a 34 × 4 foot, centred.
                Positioned(
                  bottom: Gap.f4 / 2,
                  left: (w - Gap.f34) / 2,
                  child: Container(
                    width: Gap.f34,
                    height: Sizes.bar,
                    decoration: BoxDecoration(
                      color: bt.screen,
                      borderRadius: Radii.chip,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// "Pause after this one" is armed: what it follows and the latest the
/// break starts.
typedef EndAfterArmed = ({String? title, DateTime? capAt});

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

  /// What Always On sees playing (title, channel, progress), if anything.
  final AgentMedia? media;

  /// Set while the TV waits for this video to end before pausing.
  final EndAfterArmed? armed;
  final VoidCallback? onCancelArmed;
  final bool cancelling;

  const HomeHero({
    super.key,
    required this.tvName,
    required this.now,
    required this.sentence,
    required this.sentenceTone,
    required this.protection,
    required this.onBadge,
    this.onRetry,
    this.media,
    this.armed,
    this.onCancelArmed,
    this.cancelling = false,
  });

  @override
  Widget build(BuildContext context) {
    final bt = context.bt;
    final text = Theme.of(context).textTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final off = !now.online && !now.loading;
    final muted = now.muted == true;
    final m = off || now.loading ? null : media;
    final app = now.appName.isEmpty ? null : now.appName;
    final String caption;
    final String title;
    final String detail;
    if (m != null) {
      caption = m.state == MediaState.paused
          ? (app == null ? 'Paused' : 'Paused on $app')
          : (app == null ? 'Watching now' : 'Watching on $app');
      title = m.title ?? app ?? 'Something on';
      detail = muted
          ? 'Muted'
          : now.volume == null
              ? 'Volume unknown'
              : 'Volume ${now.volume}';
    } else if (now.loading) {
      caption = 'Checking the TV…';
      title = tvName;
      detail = 'One moment';
    } else if (off) {
      caption = 'Not answering';
      title = '$tvName is off';
      detail = now.lastSeen == null
          ? 'Is it on, and on this Wi-Fi?'
          : 'Last seen ${_seen(context, now.lastSeen!)}';
    } else {
      caption = now.isHome ? 'Nothing playing' : 'Watching now';
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
    final heroText = Semantics(
      container: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(caption, style: text.labelMedium),
          const SizedBox(height: Gap.f4),
          AnimatedSwitcher(
            duration: Motion.of(context, Motion.sheet),
            switchInCurve: Motion.enter,
            switchOutCurve: Motion.exit,
            child: Text(
              title,
              key: ValueKey(title),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Fonts.bricolage(
                m == null && !off ? TypeSize.title : TypeSize.headline,
                height: TypeSize.tightLeading,
                color: bt.ink,
              ),
            ),
          ),
          if (m?.artist != null)
            Text(
              m!.artist!,
              key: const Key('hero-artist'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.bodySmall,
            ),
          const SizedBox(height: Gap.f8),
          Row(
            children: [
              if (!off && !now.loading) ...[
                Icon(
                  muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                  size: Sizes.iconSmall,
                  color: muted ? bt.berryFill : bt.muted,
                ),
                const SizedBox(width: Gap.f4),
              ],
              Flexible(
                child: Text(
                  detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodySmall!.copyWith(
                    color: bt.inkSoft,
                    fontFeatures: Fonts.tabular,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    return LayoutBuilder(
      builder: (context, c) => AnimatedContainer(
        key: const Key('home-hero'),
        duration: Motion.of(context, Motion.slow),
        curve: Motion.enter,
        // The hero is a golden rectangle at least: width ÷ 1.618 tall.
        constraints: BoxConstraints(minHeight: c.maxWidth / Phi.ratio),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            stops: const [0, Phi.major],
            colors: [off ? bt.wash : bt.skyTint, bt.surface],
          ),
          borderRadius: Radii.hero,
          border: Border.all(
            color: off || dark ? bt.border : bt.skyTint,
            width: Sizes.hairline,
          ),
        ),
        padding: const EdgeInsets.all(Gap.related),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      flex: Phi.minorFlex,
                      child: TvIllustration(now: now, off: off || now.loading),
                    ),
                    const SizedBox(width: Gap.related),
                    Expanded(flex: Phi.majorFlex, child: heroText),
                  ],
                ),
                if (m != null && m.timed) ...[
                  const SizedBox(height: Gap.f13),
                  _MediaProgress(media: m),
                ],
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: Gap.f13),
                Divider(
                  height: Sizes.hairline,
                  color: dark ? bt.hairline : bt.skyTint,
                ),
                const SizedBox(height: Gap.f13),
                AnimatedSwitcher(
                  duration: Motion.of(context, Motion.sheet),
                  switchInCurve: Motion.enter,
                  switchOutCurve: Motion.exit,
                  child: armed != null && !off
                      ? _ArmedBand(
                          key: const Key('end-after-armed'),
                          armed: armed!,
                          cancelling: cancelling,
                          onCancel: onCancelArmed,
                        )
                      : _sentenceRow(context, off),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _sentenceRow(BuildContext context, bool off) {
    final text = Theme.of(context).textTheme;
    return ConstrainedBox(
      key: const ValueKey('sentence'),
      constraints: const BoxConstraints(minHeight: Sizes.chip),
      child: Row(
        // The dot belongs to the sentence's first line, not the middle of
        // the block when the badge drops below.
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedContainer(
            margin: const EdgeInsets.only(top: Gap.f8),
            duration: Motion.of(context, Motion.flip),
            width: Sizes.dot,
            height: Sizes.dot,
            decoration: BoxDecoration(
              color: sentenceTone.hue(context),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: Gap.f8),
          // The sentence takes the line it needs; the badge sits beside it
          // when both fit and drops to its own line otherwise, so the
          // sentence never breaks mid-thought next to the badge.
          Expanded(
            child: Wrap(
              spacing: Gap.f8,
              runSpacing: Gap.f8,
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.spaceBetween,
              children: [
                Text(
                  sentence,
                  key: const Key('home-sentence'),
                  style: text.labelMedium!.copyWith(
                    color: context.bt.ink,
                    fontWeight: FontWeight.w600,
                    height: TypeSize.displayLeading,
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

/// A thin bar of progress through the video, and what's left.
class _MediaProgress extends StatelessWidget {
  final AgentMedia media;
  const _MediaProgress({required this.media});

  @override
  Widget build(BuildContext context) {
    final bt = context.bt;
    final text = Theme.of(context).textTheme;
    final p = media.progress ?? 0;
    final left = media.left;
    return Semantics(
      label: left == null
          ? null
          : '${(p * 100).round()}% through, ${aboutMinutes(left)} left',
      excludeSemantics: true,
      child: Row(
        key: const Key('hero-progress'),
        children: [
          Expanded(
            flex: Phi.majorFlex,
            child: ThinProgress(value: p, color: bt.coral),
          ),
          if (left != null) ...[
            const SizedBox(width: Gap.f13),
            Flexible(
              flex: Phi.minorFlex,
              child: Text(
                '${(left.inSeconds / 60).ceil().clamp(1, 1440)} min left',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: text.labelMedium!.copyWith(
                  fontFeatures: Fonts.tabular,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// "Pausing after this one · <title>", with Cancel.
class _ArmedBand extends StatelessWidget {
  final EndAfterArmed armed;
  final bool cancelling;
  final VoidCallback? onCancel;

  const _ArmedBand({
    super.key,
    required this.armed,
    required this.cancelling,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final bt = context.bt;
    final text = Theme.of(context).textTheme;
    final cap = armed.capAt;
    return Semantics(
      container: true,
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(Gap.f13, Gap.f8, Gap.f4, Gap.f8),
        decoration: BoxDecoration(
          color: bt.sunTint,
          borderRadius: Radii.control,
        ),
        child: Row(
          children: [
            Icon(
              Icons.hourglass_bottom_rounded,
              size: Sizes.icon,
              color: bt.sunInk,
            ),
            const SizedBox(width: Gap.f8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        const TextSpan(text: 'Pausing after this one'),
                        if (armed.title != null)
                          TextSpan(
                            text: ' · ${armed.title}',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                      ],
                    ),
                    key: const Key('end-after-line'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: text.labelMedium!.copyWith(color: bt.ink),
                  ),
                  if (cap != null)
                    Text(
                      'At the latest by ${friendlyTime(context, cap)}',
                      style: text.bodySmall!.copyWith(color: bt.sunInk),
                    ),
                ],
              ),
            ),
            TextButton(
              key: const Key('end-after-cancel'),
              style: TextButton.styleFrom(foregroundColor: bt.ink),
              onPressed: cancelling ? null : onCancel,
              child: Text(cancelling ? 'Cancelling…' : 'Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}

/// The amber hero while the TV takes a break: sleeping Tubby, a big
/// tabular countdown and who keeps the break. Same golden proportions as
/// the calm hero, so the swap reads as one surface changing state.
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
        padding: const EdgeInsets.all(Gap.related),
        decoration: BoxDecoration(
          borderRadius: Radii.hero,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: dark
                ? const [Color(0xFFE6BD6E), Color(0xFFE09C22)]
                : const [Color(0xFFFFD27A), Color(0xFFFFB020)],
          ),
        ),
        child: Column(
          children: [
            // Tubby settles in over 520 ms (the one slow motion).
            TweenAnimationBuilder<double>(
              tween: Tween(begin: Motion.reduced(context) ? 1 : 0, end: 1),
              duration: Motion.of(context, Motion.slow),
              curve: Motion.enter,
              builder: (context, v, child) => Opacity(
                opacity: v,
                child: Transform.translate(
                  offset: Offset(0, Gap.f8 * (1 - v)),
                  child: child,
                ),
              ),
              child: const Tubby(
                mood: TubbyMood.asleep,
                size: Sizes.tubbyLarge,
                body: Color(0xFFFFF8F1),
              ),
            ),
            const SizedBox(height: Gap.f13),
            Text(
              silenceOnly ? 'The TV is on quiet' : 'The TV is taking a break',
              textAlign: TextAlign.center,
              style: text.titleSmall!.copyWith(
                color: _brown,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              countdown(left),
              key: const Key('break-countdown'),
              style: text.displayMedium!.copyWith(
                color: const Color(0xFF1C1D3A),
              ),
            ),
            Text(
              'left · sound returns by itself at '
              '${friendlyTime(context, until)}',
              textAlign: TextAlign.center,
              style: text.bodySmall!.copyWith(color: _brown),
            ),
            const SizedBox(height: Gap.f13),
            Container(
              key: Key(byTv ? 'break-by-tv' : 'break-by-phone'),
              constraints: const BoxConstraints(minHeight: Sizes.chip),
              padding: const EdgeInsets.symmetric(horizontal: Gap.f13),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.55),
                borderRadius: Radii.chip,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    byTv ? Icons.shield_rounded : Icons.phone_android_rounded,
                    size: Sizes.iconSmall,
                    color: _deep,
                  ),
                  const SizedBox(width: Gap.f8),
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
