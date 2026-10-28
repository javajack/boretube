import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/tv_providers.dart';
import '../providers/ui_providers.dart';
import '../ui/components.dart';
import '../ui/tokens.dart';
import '../ui/tubby.dart';
import 'always_on_watch.dart';

/// Called once after Always On was installed from this phone: turns the
/// Always On alerts on by default and asks for notification permission in
/// context.
Future<void> enableAlertsAfterInstall(
  BuildContext context,
  WidgetRef ref,
) async {
  final pref = ref.read(alertsPrefProvider);
  // The parent already chose; respect it (but keep the job alive).
  if (pref != null) {
    await ref.read(alertsPrefProvider.notifier).ensureScheduled();
    return;
  }
  final alerts = ref.read(alertsPrefProvider.notifier);
  await alerts.set(true);
  final allowed = await ref.read(alertNotifierProvider).enabled();
  if (allowed != false || !context.mounted) return;
  final yes = await showBtSheet<bool>(
    context,
    builder: (_) => const AlertsPermissionSheet(),
  );
  if (yes == true) {
    await ref.read(alertNotifierProvider).requestPermission();
  } else {
    await alerts.set(false);
  }
  ref.invalidate(notificationsAllowedProvider);
}

/// Opens Better TV › Always On for an alert's [payload] (a TV id).
void openAlwaysOnAlert(WidgetRef ref, String? payload) {
  final store = ref.read(tvStoreProvider);
  if (payload != null && store.tvs.any((t) => t.id == payload)) {
    store.setActive(payload);
  }
  ref.read(shellTabProvider.notifier).state = 2;
  ref.read(betterTvFocusProvider.notifier).state = 'alwaysOn';
}

/// "Want a heads-up if Always On stops?" before the system prompt.
class AlertsPermissionSheet extends StatelessWidget {
  const AlertsPermissionSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final bt = context.bt;
    final text = Theme.of(context).textTheme;
    return SheetScaffold(
      key: const Key('alerts-permission'),
      title: 'A heads-up if it stops',
      lead: const Text(
        'Always On now runs on the TV by itself. If it ever stops, this '
        'phone can tell you, and again when it\'s back.',
      ),
      children: [
        InfoCard(
          color: bt.mintTint,
          borderColor: bt.mintTint,
          child: Row(
            children: [
              const Tubby(mood: TubbyMood.guard, size: 52, animate: false),
              const SizedBox(width: Gap.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Always On stopped on Living Room TV',
                      style: text.titleSmall!.copyWith(color: bt.ink),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Bedtime and limits won\'t run until it\'s back.',
                      style: text.bodySmall!.copyWith(color: bt.inkSoft),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: Gap.md),
        Text(
          'Only when something changes. Checked about every 15 minutes, '
          'gently on the battery.',
          style: text.bodySmall,
        ),
        const SizedBox(height: Gap.lg),
        PrimaryButton(
          key: const Key('alerts-allow'),
          label: 'Allow notifications',
          icon: Icons.notifications_active_rounded,
          onPressed: () => Navigator.pop(context, true),
        ),
        const SizedBox(height: Gap.sm),
        TextButton(
          key: const Key('alerts-not-now'),
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Not now'),
        ),
      ],
    );
  }
}
