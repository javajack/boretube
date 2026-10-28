import 'package:flutter/material.dart';

import 'tv/activity_section.dart';

/// History: every change to the TV, from this phone and from Always On.
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('History')),
        body: const SafeArea(top: false, child: ActivitySection()),
      );
}
