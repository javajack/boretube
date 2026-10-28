import 'package:flutter/material.dart';

import '../ui/tokens.dart';

/// The big title at the top of Routines and Better TV.
class TabHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? trailing;

  const TabHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.gutter, Gap.f13, Gap.f13, Gap.f8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(title, style: text.headlineLarge),
                ),
                const SizedBox(height: Gap.f4),
                Text(subtitle, style: text.bodyMedium),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
