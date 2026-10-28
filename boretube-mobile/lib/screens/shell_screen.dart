import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/agent_providers.dart';
import '../providers/break_provider.dart';
import '../providers/now_playing.dart';
import '../providers/tv_providers.dart';
import '../tv/tv.dart';
import '../ui/components.dart';
import '../ui/format.dart';
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
    // Snapshot the TV the first time ADB works (kept for Restore).
    ref.listen(baselineProvider, (_, __) {});
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

/// One glance at what protects the TV: TV Guard on / limited / paused /
/// down / safe mode, a break, the Classic lock, or nothing.
class GuardPill extends ConsumerWidget {
  const GuardPill({super.key});

  static (String, Tone) look(GuardState s) => switch (s) {
        GuardState.on => ('TV Guard on', Tone.ok),
        GuardState.limited => ('Limited', Tone.warn),
        GuardState.paused => ('Paused', Tone.warn),
        GuardState.down => ('TV Guard down', Tone.bad),
        GuardState.safe => ('🛟 Safe mode', Tone.info),
        GuardState.onBreak => ('☕ Break', Tone.warn),
        GuardState.classic => ('Classic lock', Tone.info),
        GuardState.notGuarded => ('Not guarded', Tone.idle),
        GuardState.checking => ('TV Guard…', Tone.idle),
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classic = ref.watch(classicLockActiveProvider).valueOrNull ?? false;
    final onBreak = ref.watch(breakProvider).active;
    final link = ref.watch(agentStatusProvider);
    final state = guardStateOf(
      link: link,
      onBreak: onBreak,
      classic: classic,
    );
    final (label, tone) = look(state);
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: StatusPill(
        key: ValueKey(label),
        label: label,
        tone: tone,
        onTap: () => _explain(context, state, link),
      ),
    );
  }

  static String _meaning(GuardState s, AgentLink link) => switch (s) {
        GuardState.on => 'Rules run on the TV itself, 24/7, even with this '
            'phone away or off.',
        GuardState.limited => 'TV Guard is running but the TV hasn\'t '
            'allowed its own debugging yet, so it can\'t close apps. Use '
            'Repair on the TV tab.',
        GuardState.paused => 'TV Guard is paused: nothing is enforced and '
            'the watchdog makes no changes. Resume on the TV tab.',
        GuardState.down => link.kind == AgentLinkKind.authFailed
            ? 'TV Guard answers but doesn\'t know this phone any more. '
                'Repair on the TV tab pairs it again.'
            : 'TV Guard isn\'t answering. The TV may be off, or TV Guard '
                'was turned off. Repair on the TV tab.',
        GuardState.safe => 'Safe mode: TV Guard only reports. It makes no '
            'changes until you turn safe mode off.',
        GuardState.onBreak => 'The TV stays closed and muted until the '
            'break ends.',
        GuardState.classic => 'This phone is checking the TV and enforcing '
            'the lock. It stops if the phone leaves home Wi-Fi.',
        GuardState.notGuarded => 'Nothing is limiting the TV right now. '
            'Start a Classic lock on the Now tab, or install TV Guard from '
            'the TV tab.',
        GuardState.checking => 'Checking TV Guard on the TV…',
      };

  void _explain(BuildContext context, GuardState state, AgentLink link) {
    final text = Theme.of(context).textTheme;
    final (label, tone) = look(state);
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
              _PillLegend(
                tone: tone,
                title: label,
                body: _meaning(state, link),
              ),
              if (!link.installed) ...[
                const SizedBox(height: Gap.md),
                const _PillLegend(
                  tone: Tone.ok,
                  title: 'TV Guard',
                  body: 'Rules that live on the TV and work 24/7, even '
                      'with the phone away. Install it from TV › Health.',
                ),
              ],
              if (link.lastOk != null && state == GuardState.down) ...[
                const SizedBox(height: Gap.md),
                Text(
                  'Last answered ${relativeTime(link.lastOk!)}',
                  style: text.bodySmall,
                ),
              ],
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
