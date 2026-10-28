import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/security_providers.dart';
import '../security/app_lock.dart';
import '../ui/components.dart';
import '../ui/tokens.dart';
import 'pin_entry.dart';

/// Brand mark used on full-screen gates.
class BrandMark extends StatelessWidget {
  final double size;
  const BrandMark({super.key, this.size = 56});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.3),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [scheme.primary, Palette.amberDeep],
        ),
      ),
      child: Icon(
        Icons.tv_rounded,
        color: scheme.onPrimary,
        size: size * 0.52,
      ),
    );
  }
}

/// Cold-start / return-from-background gate.
class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  bool _autoTried = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _maybeAutoBiometric(ref.read(appLockProvider));
    });
  }

  /// Offers the fingerprint once, as soon as the app is known locked.
  void _maybeAutoBiometric(AppLockState s) {
    if (_autoTried || s.phase != LockPhase.locked || !s.biometricEnabled) {
      return;
    }
    _autoTried = true;
    _biometric();
  }

  Future<void> _biometric() =>
      ref.read(appLockProvider.notifier).unlockWithBiometric();

  @override
  Widget build(BuildContext context) {
    ref.listen<AppLockState>(
      appLockProvider,
      (_, next) => _maybeAutoBiometric(next),
    );
    final lock = ref.watch(appLockProvider);
    final ctrl = ref.read(appLockProvider.notifier);
    return _GateScaffold(
      child: PinEntry(
        title: 'Enter parent PIN',
        subtitle: 'Boretube is locked to keep the remote with grown-ups.',
        onSubmit: (pin) async {
          if (ctrl.coolingDown) return 'Too many tries. Wait 30 seconds.';
          final ok = await ctrl.unlock(pin);
          if (ok) return null;
          if (ctrl.coolingDown) return 'Too many tries. Wait 30 seconds.';
          return 'Wrong PIN';
        },
        footer: lock.biometricEnabled
            ? TextButton.icon(
                onPressed: _biometric,
                icon: const Icon(Icons.fingerprint_rounded, size: 28),
                label: const Text('Use fingerprint'),
              )
            : null,
      ),
    );
  }
}

/// PIN creation for users who already have a TV (upgraded from v1).
class SetupPinScreen extends ConsumerWidget {
  const SetupPinScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _GateScaffold(
      child: PinSetup(
        onDone: (pin) => ref.read(appLockProvider.notifier).setPin(pin),
      ),
    );
  }
}

class _GateScaffold extends StatelessWidget {
  final Widget child;
  const _GateScaffold({required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: Gap.page,
              vertical: Gap.xl,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const BrandMark(),
                const SizedBox(height: Gap.xl),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Simple centred splash while secure storage loads.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: BrandMark(size: 72)),
    );
  }
}

/// Bottom sheet: current PIN, then a new one.
Future<void> showChangePinSheet(BuildContext context, WidgetRef ref) async {
  String? current;
  final changed = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            Gap.page,
            0,
            Gap.page,
            Gap.xl,
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: current == null
                ? PinEntry(
                    key: const ValueKey('current'),
                    title: 'Current PIN',
                    onSubmit: (pin) async {
                      final ok = await ref.read(pinStoreProvider).verify(pin);
                      if (!ok) return 'Wrong PIN';
                      setState(() => current = pin);
                      return null;
                    },
                  )
                : PinSetup(
                    key: const ValueKey('new'),
                    title: 'New PIN',
                    onDone: (pin) async {
                      await ref
                          .read(appLockProvider.notifier)
                          .changePin(current!, pin);
                      if (context.mounted) Navigator.pop(context, true);
                    },
                  ),
          ),
        ),
      ),
    ),
  );
  if (changed == true && context.mounted) {
    showStatusSnack(context, 'PIN changed');
  }
}
