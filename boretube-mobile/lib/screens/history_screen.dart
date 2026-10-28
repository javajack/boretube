import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ui/controls.dart';
import 'tv/activity_section.dart';

/// History: every change to the TV, from this phone and from Always On.
class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => DetailPage(
        title: 'History',
        subtitle: 'Every change to the TV, and who made it.',
        onRefresh: () => ActivitySection.refresh(ref),
        children: const [ActivitySection()],
      );
}
