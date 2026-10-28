import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../ops/journal.dart';
import '../../providers/tv_providers.dart';
import '../../ui/components.dart';
import '../../ui/tokens.dart';
import 'activity_section.dart';

const tvListPadding = EdgeInsets.fromLTRB(
  Gap.page,
  Gap.sm,
  Gap.page,
  Gap.xxl,
);

/// Shown in Health/Apps when the TV has no authorized ADB.
class AdbRequired extends StatelessWidget {
  final String what;
  const AdbRequired({super.key, required this.what});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: tvListPadding,
      children: [
        InfoCard(
          child: Column(
            children: [
              EmptyState(
                icon: Icons.lock_outline_rounded,
                tone: Tone.accent,
                title: 'Unlock Home mode',
                message: '$what needs Home mode on the TV. It\'s '
                    'a one-time setup and takes about two minutes.',
              ),
              FilledButton.icon(
                onPressed: () => context.push('/adb-guide'),
                icon: const Icon(Icons.lock_open_rounded),
                label: const Text('Show me how'),
              ),
              const SizedBox(height: Gap.sm),
            ],
          ),
        ),
      ],
    );
  }
}

/// Runs a TV write, then shows the journal entries it produced.
Future<void> runMaintenance(
  BuildContext context,
  WidgetRef ref, {
  required String title,
  required Future<void> Function() run,
}) async {
  final tvId = ref.read(activeTvIdProvider);
  final journal = ref.read(journalProvider);
  final before = tvId == null ? 0 : (await journal.entries(tvId)).length;
  Object? error;
  try {
    await run();
  } catch (e) {
    error = e;
  }
  final List<JournalEntry> fresh = tvId == null
      ? const []
      : (await journal.entries(tvId)).skip(before).toList();
  ref.invalidate(journalEntriesProvider);
  if (!context.mounted) return;
  if (error != null && fresh.isEmpty) {
    showStatusSnack(context, '$title failed: $error', ok: false);
    return;
  }
  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      icon: Icon(
        error == null && fresh.every((e) => e.ok)
            ? Icons.check_circle_rounded
            : Icons.error_outline_rounded,
        size: 32,
        color: error == null && fresh.every((e) => e.ok)
            ? StatusColors.of(context).ok
            : StatusColors.of(context).bad,
      ),
      title: Text(title, textAlign: TextAlign.center),
      contentPadding: const EdgeInsets.fromLTRB(0, Gap.lg, 0, 0),
      content: SizedBox(
        width: double.maxFinite,
        child: fresh.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(Gap.xl),
                child: Text('Nothing needed changing.'),
              )
            : ListView(
                shrinkWrap: true,
                children: [
                  for (final e in fresh) JournalRow(entry: e, expanded: true),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.all(Gap.lg),
                      child: Text('Stopped early: $error'),
                    ),
                ],
              ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Done'),
        ),
      ],
    ),
  );
}
