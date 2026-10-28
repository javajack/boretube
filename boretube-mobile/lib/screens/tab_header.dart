import 'package:flutter/material.dart';

import '../ui/tokens.dart';

/// The page title at the top of a tab: Bricolage display 34, with at most
/// one line under it. Sits on the 21 gutter.
class TabHeader extends StatelessWidget {
  final String title;
  final String? subtitle;

  /// A line under the title that is a widget (e.g. a saved/not-saved
  /// status with an icon). Wins over [subtitle].
  final Widget? status;
  final Widget? trailing;

  const TabHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.status,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final line = status ??
        (subtitle == null
            ? null
            : Text(
                subtitle!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.bodyMedium,
              ));
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Gap.gutter,
        Gap.f13,
        Gap.gutter,
        0,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(title, style: text.displaySmall),
                ),
                if (line != null) ...[
                  const SizedBox(height: Gap.f4),
                  line,
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
