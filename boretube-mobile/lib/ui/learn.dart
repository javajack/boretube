import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'components.dart';
import 'tokens.dart';

/// The few words a parent may not know. Each has one sentence (the ⓘ
/// sheet) and a longer "Learn more".
enum LearnTerm { alwaysOn, homeMode, cleanTv, noShorts, shorts, makeItBoring }

typedef LearnCopy = ({
  String title,
  IconData icon,
  Tone tone,
  String sentence,
  List<String> more,
});

extension LearnTermCopy on LearnTerm {
  LearnCopy get copy => switch (this) {
        LearnTerm.alwaysOn => (
            title: 'Always On',
            icon: Icons.shield_rounded,
            tone: Tone.ok,
            sentence: 'A tiny helper on the TV that keeps your routines '
                'running, even when your phone is away or switched off.',
            more: [
              'Bedtime, daily TV time and allowed apps live on the TV '
                  'itself, so they still work when you\'re out.',
              'It tidies the TV up again after software updates, and this '
                  'phone checks on it every so often and tells you if it '
                  'stops.',
              'Remove it any time from Better TV. The TV keeps working '
                  'normally without it.',
            ],
          ),
        LearnTerm.homeMode => (
            title: 'Home mode',
            icon: Icons.home_rounded,
            tone: Tone.info,
            sentence: 'Your phone talks to the TV directly while you\'re '
                'both on the same Wi-Fi, so it can do much more than a '
                'remote.',
            more: [
              'It\'s a TV setting meant for app makers. You switch it on '
                  'once, with the remote, in about three minutes.',
              'With it, boretube can hide Shorts, tidy away promo apps and '
                  'close apps properly. Nothing is installed.',
              'Everything it changes is logged, and "Put the TV back the '
                  'way it was" undoes it.',
            ],
          ),
        LearnTerm.cleanTv => (
            title: 'Clean TV',
            icon: Icons.auto_awesome_rounded,
            tone: Tone.accent,
            sentence: 'Switches off the promo, ad and leftover apps the TV '
                'came with, so the home screen is calmer.',
            more: [
              'Nothing is deleted. Apps are switched off and come back with '
                  'one tap on Undo.',
              'Things the TV needs, like Wi-Fi setup, the Google TV home '
                  'screen and the voice remote, are never touched.',
            ],
          ),
        LearnTerm.noShorts => (
            title: 'YouTube without Shorts',
            icon: Icons.smart_display_rounded,
            tone: Tone.accent,
            sentence: 'Kids keep YouTube, minus the endless Shorts: the '
                'TV\'s own YouTube app steps aside for SmartTube.',
            more: [
              'SmartTube is a free YouTube app for TVs with the Shorts shelf '
                  'turned off. boretube never installs it for you; the '
                  'guide shows where to get it safely.',
              'Removing the TV\'s own YouTube is undone with one tap, or by '
                  '"Put the TV back the way it was".',
            ],
          ),
        LearnTerm.shorts => (
            title: 'Video hopping',
            icon: Icons.swipe_vertical_rounded,
            tone: Tone.accent,
            sentence: 'The TV spots hopping by its rhythm: three or more '
                'quick videos in a row. Then it can nudge, rest the video '
                'apps for a while, or just tell you.',
            more: [
              'It works in SmartTube and the YouTube apps. One short video '
                  'on its own isn\'t Shorts, and a long video never counts.',
              'A gentle nudge closes the app and the TV goes Home; with '
                  '"Friendly message" on, Tubby says why. Cool-down also '
                  'keeps the video apps closed for a few minutes.',
              'Nothing is stopped while Always On is paused or hands off. '
                  'Presets never change this setting.',
            ],
          ),
        LearnTerm.makeItBoring => (
            title: 'Make it boring',
            icon: Icons.bedtime_rounded,
            tone: Tone.info,
            sentence: 'Closes what\'s on and mutes, so the TV just sits on '
                'its home screen. No lecture, nothing to argue with.',
            more: [
              'It\'s a gentle trick for when you\'d rather the TV look a '
                  'bit dull than say no.',
              '"Sound back on" undoes it. For a real stop, use Pause TV.',
            ],
          ),
      };
}

/// The ⓘ next to a term: a 48 dp target around a small, quiet glyph.
class InfoDot extends StatelessWidget {
  final LearnTerm term;
  final Color? color;

  const InfoDot(this.term, {super.key, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.bt.muted;
    return Semantics(
      button: true,
      label: 'What is ${term.copy.title}?',
      excludeSemantics: true,
      child: InkResponse(
        key: Key('info-${term.name}'),
        radius: Sizes.touch / 2,
        onTap: () {
          HapticFeedback.selectionClick();
          showLearnSheet(context, term);
        },
        child: SizedBox(
          width: Sizes.control,
          height: Sizes.control,
          child: Icon(Icons.info_outline_rounded, size: Sizes.icon, color: c),
        ),
      ),
    );
  }
}

/// A term followed by its ⓘ, for card titles.
class TermTitle extends StatelessWidget {
  final String text;
  final LearnTerm term;
  final TextStyle? style;
  final Color? dotColor;

  const TermTitle(
    this.text,
    this.term, {
    super.key,
    this.style,
    this.dotColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            text,
            style: style ?? Theme.of(context).textTheme.titleMedium,
          ),
        ),
        Transform.translate(
          offset: const Offset(-Gap.f8, 0),
          child: InfoDot(term, color: dotColor),
        ),
      ],
    );
  }
}

Future<void> showLearnSheet(BuildContext context, LearnTerm term) =>
    showBtSheet<void>(context, builder: (_) => LearnSheet(term: term));

/// One sentence first; "Learn more" opens the rest in place.
class LearnSheet extends StatefulWidget {
  final LearnTerm term;
  final bool expanded;

  const LearnSheet({super.key, required this.term, this.expanded = false});

  @override
  State<LearnSheet> createState() => _LearnSheetState();
}

class _LearnSheetState extends State<LearnSheet> {
  late bool _more = widget.expanded;

  @override
  Widget build(BuildContext context) {
    final c = widget.term.copy;
    final bt = context.bt;
    final text = Theme.of(context).textTheme;
    return SheetScaffold(
      key: Key('learn-${widget.term.name}'),
      title: c.title,
      lead: Text(c.sentence, style: text.bodyLarge!.copyWith(color: bt.ink)),
      children: [
        AnimatedSize(
          duration: Motion.of(context, Motion.sheet),
          curve: Motion.enter,
          alignment: Alignment.topCenter,
          child: !_more
              ? Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    key: const Key('learn-more'),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: Gap.f8),
                    ),
                    onPressed: () => setState(() => _more = true),
                    icon:
                        const Icon(Icons.expand_more_rounded, size: Sizes.icon),
                    label: const Text('Learn more'),
                  ),
                )
              : Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(Gap.f13),
                  decoration: BoxDecoration(
                    color: bt.surface,
                    borderRadius: Radii.control,
                    border: Border.all(color: bt.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < c.more.length; i++) ...[
                        if (i > 0) const SizedBox(height: Gap.f13),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(
                                  top: Gap.f8 + Gap.f4 / 2),
                              child: Container(
                                width: Gap.f4,
                                height: Gap.f4,
                                decoration: BoxDecoration(
                                  color: c.tone.hue(context),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                            const SizedBox(width: Gap.f13),
                            Expanded(
                              child: Text(c.more[i], style: text.bodyMedium),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
        ),
        const SizedBox(height: Gap.f13),
        PrimaryButton(
          key: const Key('learn-done'),
          label: 'Got it',
          kind: ButtonKind.ink,
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }
}
