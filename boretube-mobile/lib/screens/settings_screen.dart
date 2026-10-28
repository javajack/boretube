import 'package:flutter/material.dart';

import 'tv/settings_section.dart';

/// Settings, behind the avatar on Home.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Settings')),
        body: const SafeArea(top: false, child: SettingsSection()),
      );
}
