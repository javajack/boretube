import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../agent/agent_models.dart';
import '../ops/clean_wizard.dart';
import '../tv/tv.dart';
import 'agent_providers.dart';
import 'providers.dart';
import 'tv_providers.dart';

final wizardProgressStoreProvider = Provider<WizardProgressStore>(
  (ref) => WizardProgressStore(ref.watch(sharedPrefsProvider)),
);

final wizardTimingProvider = Provider<WizardTiming>(
  (ref) => const WizardTiming(),
);

final wizardClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

/// Read-only: `1` once Android has finished booting.
const bootCompletedCommand = 'getprop sys.boot_completed';

/// The real probes: the ADB session reconnects and the TV says it has
/// finished booting, then a capability probe refreshes what it can do.
/// TV Guard is healthy when `/v1/status` answers and it isn't in safe
/// mode; null when it isn't installed.
final wizardProbesProvider = Provider<WizardProbes>(
  (ref) => WizardProbes(
    tvBack: () async {
      final session = ref.read(adbSessionProvider);
      if (session == null) return false;
      try {
        await session.connect().timeout(const Duration(seconds: 10));
        final r = await session
            .shell(bootCompletedCommand)
            .timeout(const Duration(seconds: 10));
        if (r.stdout.trim() != '1') return false;
      } catch (_) {
        return false;
      }
      final report = await ref.read(capabilityProvider.notifier).probe();
      return report == null || report.tv.can(TvCapability.adb);
    },
    guardHealthy: () async {
      if (!ref.read(agentStatusProvider).installed) return null;
      final client = ref.read(agentClientProvider);
      if (client == null) return false;
      // TV Guard starts a little after the TV; give it about 30 s.
      for (var i = 0; i < 6; i++) {
        try {
          final s = await client.status();
          return s.mode != AgentMode.safe;
        } catch (_) {
          await Future<void>.delayed(const Duration(seconds: 5));
        }
      }
      return false;
    },
  ),
);
