import 'package:flutter/material.dart';

import 'tv/settings_section.dart';

/// Settings, behind the avatar on Home. The section draws its own header
/// (with the back arrow), in the same voice as the tabs.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) => const Scaffold(
        body: SafeArea(bottom: false, child: SettingsSection()),
      );
}
