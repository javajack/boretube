import 'package:flutter/material.dart';

import '../../agent/agent_client.dart';
import '../../ui/components.dart';
import '../../ui/controls.dart';
import '../../ui/tokens.dart';

/// "KG", "Class 3".
String gradeLabel(int g) => g == 0 ? 'KG' : 'Class $g';

/// The Brain breaks row value: "Off", or the class.
String brainBreaksLabel(LearningRule r) =>
    r.enabled ? gradeLabel(r.grade) : 'Off';

/// The first agent that knows `rules.learning`.
const brainBreaksAgent = '1.4.0';

/// The Brain breaks sheet: on/off, the child's class and language, the
/// break itself, when it shows, this week, and "Try a break on the TV now".
class BrainBreaksEditor extends StatelessWidget {
  final LearningRule rule;
  final ValueChanged<LearningRule> onChanged;

  /// From `status.learning`; null on an older or unreachable agent.
  final AgentLearning? status;

  /// The TV's TV Guard knows brain breaks.
  final bool supported;

  /// Null while the try isn't possible (unsaved changes, or off on the TV).
  final VoidCallback? onTry;

  /// Why [onTry] is null, in one line.
  final String? tryNote;

  const BrainBreaksEditor({
    super.key,
    required this.rule,
    required this.onChanged,
    required this.supported,
    this.status,
    this.onTry,
    this.tryNote,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    if (!supported) {
      return Text(
        'This TV has an older TV Guard. Update it in Better TV, then '
        'brain breaks are here.',
        key: const Key('rules-learning-update'),
        style: text.bodyMedium,
      );
    }
    final r = rule;
    final st = status;
    Widget reveal(bool on, Widget child) => AnimatedSize(
          duration: Motion.of(context, Motion.sheet),
          curve: Motion.enter,
          alignment: Alignment.topCenter,
          child: on ? child : const SizedBox(width: double.infinity),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RowList(
          edges: true,
          children: [
            SwitchLine(
              key: const Key('rules-learning-on'),
              title: 'On for this TV',
              value: r.enabled,
              onChanged: (on) => onChanged(r.copyWith(enabled: on)),
            ),
          ],
        ),
        reveal(
          r.enabled,
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const GroupHeading('Your child'),
              // Two even rows of four: KG–3, 4–7.
              for (final row in const [
                [0, 1, 2, 3],
                [4, 5, 6, 7],
              ]) ...[
                if (row.first > 0) const SizedBox(height: Gap.f8),
                ChipRow(
                  children: [
                    for (final g in row)
                      BtChip(
                        key: Key('rules-learning-grade-$g'),
                        label: gradeLabel(g),
                        selected: r.grade == g,
                        onTap: () => onChanged(r.copyWith(grade: g)),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: Gap.related),
              RadioList<LearnLang>(
                keyPrefix: 'rules-learning-lang',
                options: const [
                  RadioOption(LearnLang.en, 'English'),
                  RadioOption(LearnLang.hi, 'Hindi'),
                  RadioOption(
                    LearnLang.enHi,
                    'English, with a Hindi voice',
                  ),
                ],
                value: r.lang,
                onChanged: (l) => onChanged(r.copyWith(lang: l)),
              ),
              const GroupHeading('The break'),
              RowList(
                edges: true,
                children: [
                  ListRow(
                    title: 'Questions each time',
                    trailing: CountStepper(
                      key: const Key('rules-learning-count'),
                      keyPrefix: 'rules-learning-count',
                      value: r.perBreak,
                      min: LearningRule.minPerBreak,
                      max: LearningRule.maxPerBreak,
                      unit: '',
                      onChanged: (n) => onChanged(r.copyWith(perBreak: n)),
                    ),
                  ),
                  SwitchLine(
                    key: const Key('rules-learning-voice'),
                    title: 'Read questions aloud',
                    subtitle: st?.voice == 'noHindi' && r.lang != LearnLang.en
                        ? 'No Hindi voice on this TV: read in English'
                        : null,
                    value: r.voice,
                    onChanged: (on) => onChanged(r.copyWith(voice: on)),
                  ),
                ],
              ),
              const GroupHeading('When it shows'),
              RadioList<LearnTrigger>(
                keyPrefix: 'rules-learning-trigger',
                options: [
                  const RadioOption(
                    LearnTrigger.manual,
                    'When you start one',
                    detail: 'From this phone, with the button below.',
                  ),
                  const RadioOption(
                    LearnTrigger.hopping,
                    'After video hopping',
                    detail: 'Instead of the Video hopping rule.',
                  ),
                  RadioOption(
                    LearnTrigger.every,
                    'Every so often',
                    detail: 'After ${r.everyMin} min of video.',
                  ),
                ],
                value: r.trigger,
                onChanged: (t) => onChanged(r.copyWith(trigger: t)),
              ),
              reveal(
                r.trigger == LearnTrigger.every,
                RowList(
                  edges: true,
                  children: [
                    ListRow(
                      title: 'Video before a break',
                      trailing: CountStepper(
                        key: const Key('rules-learning-every'),
                        keyPrefix: 'rules-learning-every',
                        value: r.everyMin,
                        min: LearningRule.minEveryMin,
                        max: LearningRule.maxEveryMin,
                        step: 5,
                        unit: 'min',
                        onChanged: (n) => onChanged(r.copyWith(everyMin: n)),
                      ),
                    ),
                  ],
                ),
              ),
              if (st != null && st.weekBreaks > 0) ...[
                const GroupHeading('This week'),
                Text(
                  '${_n(st.weekBreaks, 'break')} · ${st.weekRight} right · '
                  '${st.weekLearned} learned',
                  key: const Key('rules-learning-week'),
                  style: text.bodyLarge,
                ),
                if (st.stronger != null)
                  Text(
                    'Getting stronger: ${st.stronger}',
                    style: text.bodyMedium,
                  ),
              ],
              const SizedBox(height: Gap.section),
              PrimaryButton(
                key: const Key('rules-learning-try'),
                label: st?.showing == true
                    ? 'A brain break is on the TV'
                    : 'Try a break on the TV now',
                icon: Icons.school_rounded,
                onPressed: st?.showing == true ? null : onTry,
              ),
              if (tryNote != null) ...[
                const SizedBox(height: Gap.f8),
                Text(
                  tryNote!,
                  key: const Key('rules-learning-try-note'),
                  textAlign: TextAlign.center,
                  style: text.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  static String _n(int n, String word) => '$n $word${n == 1 ? '' : 's'}';
}
