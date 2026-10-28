import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../adb/adb_session.dart';
import '../providers/tv_providers.dart';
import '../ui/components.dart';
import '../ui/format.dart';
import '../ui/tokens.dart';

class AdbGuideScreen extends StatelessWidget {
  const AdbGuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Unlock with ADB')),
      body: SafeArea(
        child: AdbGuide(onDone: () => Navigator.of(context).maybePop()),
      ),
    );
  }
}

/// Steps to enable debugging on the TV, then connects and walks the
/// parent through "Allow USB debugging?".
class AdbGuide extends ConsumerStatefulWidget {
  final VoidCallback onDone;
  final VoidCallback? onSkip;

  const AdbGuide({super.key, required this.onDone, this.onSkip});

  @override
  ConsumerState<AdbGuide> createState() => _AdbGuideState();
}

class _AdbGuideState extends ConsumerState<AdbGuide> {
  bool _started = false;
  bool _verified = false;
  String? _error;

  Future<void> _connect() async {
    setState(() {
      _started = true;
      _error = null;
    });
    try {
      await ref.read(adbKeyProvider.future);
      final session = ref.read(adbSessionProvider);
      if (session == null) throw StateError('No TV selected');
      await session.connect();
      await ref.read(capabilityProvider.notifier).probe();
      if (mounted) setState(() => _verified = true);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adbStateProvider).valueOrNull;
    final tv = ref.watch(activeTvProvider);
    final text = Theme.of(context).textTheme;

    final Widget body;
    if (_started && state is AdbAwaitingApproval) {
      body = const _LookAtTv(key: ValueKey('approve'));
    } else if (_started && (state is AdbConnected || _verified)) {
      body = _Result(
        key: const ValueKey('ok'),
        ok: true,
        title: 'ADB unlocked',
        message: '${tv?.name ?? 'The TV'} now trusts this phone. Health, '
            'Apps and strong stop are ready.',
        action: FilledButton(
          onPressed: widget.onDone,
          child: const Text('Continue'),
        ),
      );
    } else if (_started && _error != null) {
      final rejected = state is AdbFailed && state.authRejected;
      body = _Result(
        key: const ValueKey('fail'),
        ok: false,
        title: rejected ? 'The TV said no' : 'Couldn\'t connect',
        message: rejected
            ? 'Try again and choose "Always allow from this computer".'
            : 'Check that USB or network debugging is on, and that the '
                'TV is awake.',
        action: FilledButton.icon(
          onPressed: _connect,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Try again'),
        ),
      );
    } else if (_started) {
      body = const _Result(
        key: ValueKey('connecting'),
        ok: null,
        title: 'Connecting to the TV…',
        message: 'This takes a few seconds.',
      );
    } else {
      body = _Steps(
        key: const ValueKey('steps'),
        onConnect: _connect,
        onSkip: widget.onSkip,
      );
    }
    return Column(
      children: [
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: body,
          ),
        ),
        if (_started && state is! AdbConnected && !_verified)
          Padding(
            padding: const EdgeInsets.only(bottom: Gap.lg),
            child: Text(
              tv == null ? '' : 'TV: ${tv.name} · ${tv.ip}',
              style: text.bodySmall,
            ),
          ),
      ],
    );
  }
}

class _Steps extends StatelessWidget {
  final VoidCallback onConnect;
  final VoidCallback? onSkip;

  const _Steps({super.key, required this.onConnect, this.onSkip});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    const steps = [
      (
        Icons.info_outline_rounded,
        'Turn on developer mode',
        'On the TV: Settings › System › About. Select "Android TV OS '
            'build" 7 times until it says you\'re a developer.',
      ),
      (
        Icons.developer_mode_rounded,
        'Turn on debugging',
        'Settings › System › Developer options. Turn on "USB debugging" '
            '(and "Wireless debugging" if you see it).',
      ),
      (
        Icons.check_circle_outline_rounded,
        'Allow this phone',
        'Tap Connect below. The TV will ask to allow debugging — choose '
            '"Always allow from this computer".',
      ),
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        Gap.page,
        Gap.sm,
        Gap.page,
        Gap.xl,
      ),
      children: [
        Text(
          'ADB lets Boretube really stop apps, read the volume and keep '
          'the TV clean. Grab the TV remote.',
          style: text.bodyMedium,
        ),
        const SizedBox(height: Gap.lg),
        for (var i = 0; i < steps.length; i++) ...[
          InfoCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    IconBadge(
                      icon: steps[i].$1,
                      color: Theme.of(context).colorScheme.primary,
                      size: 44,
                    ),
                    Positioned(
                      right: -6,
                      top: -6,
                      child: CircleAvatar(
                        radius: 10,
                        backgroundColor:
                            Theme.of(context).colorScheme.primary,
                        child: Text(
                          '${i + 1}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: Gap.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(steps[i].$2, style: text.titleSmall),
                      const SizedBox(height: Gap.xs),
                      Text(steps[i].$3, style: text.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Gap.md),
        ],
        const SizedBox(height: Gap.sm),
        FilledButton.icon(
          key: const Key('adb-connect'),
          onPressed: onConnect,
          icon: const Icon(Icons.link_rounded),
          label: const Text('Connect'),
        ),
        if (onSkip != null) ...[
          const SizedBox(height: Gap.sm),
          TextButton(onPressed: onSkip, child: const Text('Skip for now')),
        ],
      ],
    );
  }
}

/// Big, calm "look at the TV" moment while the prompt is up.
class _LookAtTv extends ConsumerWidget {
  const _LookAtTv({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final key = ref.watch(adbKeyProvider).valueOrNull;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Gap.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const PulsingIcon(icon: Icons.tv_rounded, size: 96),
            const SizedBox(height: Gap.xl),
            Text(
              'Look at the TV',
              style: text.displaySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: Gap.md),
            Text(
              'Choose "Always allow from this computer", then OK.',
              style: text.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: Gap.lg),
            Text(
              'It\'s safe: this only lets Boretube on this phone talk to '
              'the TV. You can remove it any time in Developer options.',
              style: text.bodySmall,
              textAlign: TextAlign.center,
            ),
            if (key != null) ...[
              const SizedBox(height: Gap.lg),
              Text('Fingerprint on the TV', style: text.labelSmall),
              const SizedBox(height: Gap.xs),
              Text(
                adbFingerprint(key),
                textAlign: TextAlign.center,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Result extends StatelessWidget {
  final bool? ok;
  final String title;
  final String message;
  final Widget? action;

  const _Result({
    super.key,
    required this.ok,
    required this.title,
    required this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final s = StatusColors.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Gap.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (ok == null)
              const SizedBox(
                width: 72,
                height: 72,
                child: CircularProgressIndicator(strokeWidth: 3),
              )
            else
              IconBadge(
                icon: ok! ? Icons.check_rounded : Icons.close_rounded,
                color: ok! ? s.ok : s.bad,
                size: 88,
              ),
            const SizedBox(height: Gap.xl),
            Text(title, style: text.headlineSmall),
            const SizedBox(height: Gap.sm),
            Text(message, style: text.bodyMedium, textAlign: TextAlign.center),
            if (action != null) ...[
              const SizedBox(height: Gap.xl),
              SizedBox(width: double.infinity, child: action),
            ],
          ],
        ),
      ),
    );
  }
}
