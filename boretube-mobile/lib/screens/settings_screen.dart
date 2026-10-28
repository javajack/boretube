import 'package:flutter/material.dart';

import 'tv/settings_section.dart';

/// Settings, behind the avatar on Home: a detail page with its own back
/// arrow, in the same voice as the tabs.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) => const SettingsSection();
}
