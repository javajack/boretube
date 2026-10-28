import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/agent_providers.dart';
import '../providers/now_playing.dart';
import '../providers/tv_providers.dart';
import '../providers/ui_providers.dart';
import '../tv/tv.dart';
import '../ui/components.dart';
import '../ui/tokens.dart';
import 'better_tv_tab.dart';
import 'home/home_tab.dart';
import 'routines_tab.dart';

/// Main app: Home · Routines · Better TV. Settings sits behind the avatar.
class ShellScreen extends ConsumerStatefulWidget {
  const ShellScreen({super.key});

  @override
  ConsumerState<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends ConsumerState<ShellScreen> {
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
    final tab = ref.watch(shellTabProvider);
    return PopScope(
      canPop: tab == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) ref.read(shellTabProvider.notifier).state = 0;
      },
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: IndexedStack(
            index: tab,
            children: const [HomeTab(), RoutinesTab(), BetterTvTab()],
          ),
        ),
        bottomNavigationBar: BtNavBar(
          index: tab,
          onSelect: (i) => ref.read(shellTabProvider.notifier).state = i,
        ),
      ),
    );
  }
}

/// The bottom bar: three tabs, the active one in a coral-tinted pill.
class BtNavBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onSelect;

  const BtNavBar({super.key, required this.index, required this.onSelect});

  static const _items = [
    (Icons.home_outlined, Icons.home_rounded, 'Home'),
    (Icons.calendar_month_outlined, Icons.calendar_month_rounded, 'Routines'),
    (Icons.auto_awesome_outlined, Icons.auto_awesome_rounded, 'Better TV'),
  ];

  @override
  Widget build(BuildContext context) {
    final bt = context.bt;
    final text = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: bt.surface,
        border: Border(top: BorderSide(color: bt.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Gap.md, Gap.sm, Gap.md, Gap.sm),
          child: Row(
            children: [
              for (var i = 0; i < _items.length; i++)
                Expanded(
                  child: Semantics(
                    button: true,
                    selected: i == index,
                    label: _items[i].$3,
                    excludeSemantics: true,
                    child: InkWell(
                      key: Key('tab-${_items[i].$3}'),
                      borderRadius: Radii.tile,
                      onTap: () {
                        if (i != index) HapticFeedback.selectionClick();
                        onSelect(i);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AnimatedContainer(
                              duration: Motion.of(context, Motion.medium),
                              curve: Motion.spring,
                              width: i == index ? 56 : 40,
                              height: 32,
                              decoration: BoxDecoration(
                                color: i == index
                                    ? bt.coralTint
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(Radii.pill),
                              ),
                              child: Icon(
                                i == index ? _items[i].$2 : _items[i].$1,
                                size: 22,
                                color: i == index ? bt.coralInk : bt.muted,
                              ),
                            ),
                            const SizedBox(height: Gap.xs),
                            Text(
                              _items[i].$3,
                              maxLines: 1,
                              style: text.labelMedium!.copyWith(
                                color: i == index ? bt.coralInk : bt.muted,
                                fontWeight: i == index
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Active TV name with a menu of saved TVs and "Add a TV".
class TvSwitcher extends ConsumerWidget {
  const TvSwitcher({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tvs = ref.watch(savedTvsProvider);
    final active = ref.watch(activeTvProvider);
    final now = ref.watch(nowPlayingProvider);
    final bt = context.bt;
    final text = Theme.of(context).textTheme;
    return PopupMenuButton<String>(
      key: const Key('tv-switcher'),
      tooltip: 'Switch TV',
      position: PopupMenuPosition.under,
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
            height: 56,
            child: Row(
              children: [
                Icon(
                  t.id == active?.id
                      ? Icons.check_circle_rounded
                      : Icons.tv_rounded,
                  size: 22,
                  color: t.id == active?.id ? bt.mint : bt.muted,
                ),
                const SizedBox(width: Gap.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(t.name, style: text.titleSmall),
                      Text(
                        [
                          if (t.manufacturer.isNotEmpty) t.manufacturer,
                          if (t.id == active?.id)
                            now.online ? 'on' : 'not answering',
                        ].join(' · '),
                        style: text.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: '+',
          height: 52,
          child: Row(
            children: [
              Icon(Icons.add_rounded, size: 22, color: bt.skyInk),
              const SizedBox(width: Gap.md),
              Text(
                'Add a TV',
                style: text.titleSmall!.copyWith(color: bt.skyInk),
              ),
            ],
          ),
        ),
      ],
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                active?.name ?? 'Add a TV',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Fonts.bricolage(22, color: bt.ink),
              ),
            ),
            const SizedBox(width: Gap.xs),
            Icon(Icons.expand_more_rounded, size: 22, color: bt.ink),
          ],
        ),
      ),
    );
  }
}

/// Words and tone for each Always On state (used by the Always On card).
(String, Tone) guardLook(GuardState s) => switch (s) {
      GuardState.on => ('Always On', Tone.ok),
      GuardState.limited => ('Limited', Tone.warn),
      GuardState.paused => ('Paused', Tone.warn),
      GuardState.down => ('Not answering', Tone.bad),
      GuardState.safe => ('Hands off', Tone.info),
      GuardState.onBreak => ('On a break', Tone.warn),
      GuardState.classic => ('Lock running', Tone.info),
      GuardState.notGuarded => ('Not set up', Tone.idle),
      GuardState.checking => ('Checking…', Tone.idle),
    };

/// Plain-language meaning of each capability (Settings › Advanced).
String capabilityMeaning(TvCapability c) => switch (c) {
      TvCapability.cast => 'See what\'s playing, stop Cast apps, mute',
      TvCapability.dial => 'Close YouTube and Netflix',
      TvCapability.sonyRest => 'Accurate volume and mute (Sony)',
      TvCapability.adb => 'Home mode: strong stop, apps, health, clean-up',
      TvCapability.agent => 'Always On: rules that run on the TV 24/7',
    };

String capabilityTitle(TvCapability c) => switch (c) {
      TvCapability.cast => 'Google Cast',
      TvCapability.dial => 'DIAL',
      TvCapability.sonyRest => 'Sony IP control',
      TvCapability.adb => 'ADB (developer access)',
      TvCapability.agent => 'TV Guard (Always On)',
    };
