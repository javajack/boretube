import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/break_provider.dart';
import '../providers/now_playing.dart';
import '../providers/tv_providers.dart';
import '../tv/tv.dart';
import '../ui/components.dart';
import '../ui/tokens.dart';
import 'now/now_tab.dart';
import 'rules_tab.dart';
import 'tv/tv_tab.dart';

/// Main app: TV switcher + status pill on top, Now / Rules / TV tabs.
class ShellScreen extends ConsumerStatefulWidget {
  const ShellScreen({super.key});

  @override
  ConsumerState<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends ConsumerState<ShellScreen> {
  int _tab = 0;
  StreamSubscription<String>? _messages;

  @override
  void initState() {
    super.initState();
    _messages = ref.read(appMessagesProvider).stream.listen((m) {
      if (mounted) showStatusSnack(context, m);
    });
    // Probe the active TV once per launch.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(capabilityProvider.notifier).probe();
    });
  }

  @override
  void dispose() {
    _messages?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Re-probe when the active TV changes.
    ref.listen<String?>(activeTvIdProvider, (prev, next) {
      if (next != null && prev != next) {
        ref.read(capabilityProvider.notifier).probe();
      }
    });
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 64,
        titleSpacing: Gap.sm,
        title: const TvSwitcher(),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: Gap.page),
            child: GuardPill(),
          ),
        ],
      ),
      body: IndexedStack(
        index: _tab,
        children: const [NowTab(), RulesTab(), TvTab()],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.play_circle_outline_rounded),
            selectedIcon: Icon(Icons.play_circle_rounded),
            label: 'Now',
          ),
          NavigationDestination(
            icon: Icon(Icons.rule_rounded),
            selectedIcon: Icon(Icons.rule_folder_rounded),
            label: 'Rules',
          ),
          NavigationDestination(
            icon: Icon(Icons.tv_outlined),
            selectedIcon: Icon(Icons.tv_rounded),
            label: 'TV',
          ),
        ],
      ),
    );
  }
}

/// Active TV name with a menu of saved TVs and "Add TV".
class TvSwitcher extends ConsumerWidget {
  const TvSwitcher({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tvs = ref.watch(savedTvsProvider);
    final active = ref.watch(activeTvProvider);
    final now = ref.watch(nowPlayingProvider);
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final status = now.loading
        ? 'Connecting…'
        : now.online
            ? 'Online'
            : 'Offline';
    return PopupMenuButton<String>(
      tooltip: 'Switch TV',
      position: PopupMenuPosition.under,
      shape: const RoundedRectangleBorder(borderRadius: Radii.tile),
      onSelected: (id) {
        if (id == '+') {
          context.push('/onboarding?add=1');
        } else {
          ref.read(tvStoreProvider).setActive(id);
        }
      },
      itemBuilder: (context) => [
        for (final t in tvs)
          PopupMenuItem(
            value: t.id,
            child: Row(
              children: [
                Icon(
                  t.id == active?.id
                      ? Icons.check_circle_rounded
                      : Icons.tv_rounded,
                  size: 20,
                  color: t.id == active?.id ? scheme.primary : null,
                ),
                const SizedBox(width: Gap.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.name, style: text.titleSmall),
                      Text(t.ip, style: text.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
          ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: '+',
          child: Row(
            children: [
              Icon(Icons.add_rounded, size: 20),
              SizedBox(width: Gap.md),
              Text('Add TV'),
            ],
          ),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Gap.sm,
          vertical: Gap.xs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    active?.name ?? 'No TV',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.titleMedium,
                  ),
                  Text(
                    active == null ? 'Add a TV' : '$status · ${active.ip}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: Gap.xs),
            const Icon(Icons.expand_more_rounded, size: 22),
          ],
        ),
      ),
    );
  }
}

/// ☕ Break / 🔵 Classic lock running / ⚪ Not guarded. TV Guard states
/// arrive in P2.
class GuardPill extends ConsumerWidget {
  const GuardPill({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classic = ref.watch(classicLockActiveProvider).valueOrNull ?? false;
    final onBreak = ref.watch(breakProvider).active;
    final (label, tone) = onBreak
        ? ('☕ Break', Tone.warn)
        : classic
            ? ('Classic lock', Tone.info)
            : ('Not guarded', Tone.idle);
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: StatusPill(
        key: ValueKey(label),
        label: label,
        tone: tone,
        onTap: () => _explain(context, classic, onBreak),
      ),
    );
  }

  void _explain(BuildContext context, bool classic, bool onBreak) {
    final text = Theme.of(context).textTheme;
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            Gap.xl,
            0,
            Gap.xl,
            Gap.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Protection', style: text.titleLarge),
              const SizedBox(height: Gap.lg),
              if (onBreak) ...[
                const _PillLegend(
                  tone: Tone.warn,
                  title: 'On a break',
                  body: 'The TV stays closed and muted until the break '
                      'ends, while Boretube is open.',
                ),
                const SizedBox(height: Gap.md),
              ],
              _PillLegend(
                tone: classic ? Tone.info : Tone.idle,
                title: classic ? 'Classic lock running' : 'Not guarded',
                body: classic
                    ? 'This phone is checking the TV and enforcing the '
                        'lock. It stops if the phone leaves home Wi-Fi.'
                    : 'Nothing is limiting the TV right now. Start a '
                        'Classic lock from the Now tab.',
              ),
              const SizedBox(height: Gap.md),
              const _PillLegend(
                tone: Tone.ok,
                title: 'TV Guard: coming soon',
                body: 'Rules that live on the TV and work 24/7, even '
                    'with the phone away.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PillLegend extends StatelessWidget {
  final Tone tone;
  final String title;
  final String body;

  const _PillLegend({
    required this.tone,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: tone.color(context),
              shape: BoxShape.circle,
            ),
          ),
        ),
        const SizedBox(width: Gap.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: text.titleSmall),
              const SizedBox(height: 2),
              Text(body, style: text.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}

/// Plain-language meaning of each capability.
String capabilityMeaning(TvCapability c) => switch (c) {
      TvCapability.cast => 'See what\'s playing, stop Cast apps, mute',
      TvCapability.dial => 'Close YouTube and Netflix',
      TvCapability.sonyRest => 'Accurate volume and mute (Sony)',
      TvCapability.adb => 'Strong stop, apps, health and clean-up',
      TvCapability.agent => 'TV Guard rules that run 24/7',
    };

String capabilityTitle(TvCapability c) => switch (c) {
      TvCapability.cast => 'Google Cast',
      TvCapability.dial => 'DIAL',
      TvCapability.sonyRest => 'Sony IP control',
      TvCapability.adb => 'ADB (developer access)',
      TvCapability.agent => 'TV Guard',
    };
