import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../learn/learn_installer.dart';
import 'tv_providers.dart';

/// Loads the bundled Tubby's Town app (overridden in tests).
final learnBundleLoaderProvider =
    Provider<Future<LearnBundle> Function()>((ref) => LearnBundle.load);

/// Installs and opens Tubby's Town on the active TV; null without ADB.
final learnInstallerProvider = Provider<LearnInstaller?>((ref) {
  final session = ref.watch(adbSessionProvider);
  final addr = ref.watch(activeTvAddressProvider);
  if (session == null || addr == null) return null;
  return LearnInstaller(
    adb: session,
    tvId: addr.id,
    loadBundle: ref.watch(learnBundleLoaderProvider),
    journal: ref.watch(journalProvider),
  );
});

/// Whether Tubby's Town is on the TV, and current; null without ADB or when
/// the TV can't be read.
final learnDiagnosisProvider =
    FutureProvider.autoDispose<LearnDiagnosis?>((ref) async {
  final i = ref.watch(learnInstallerProvider);
  if (i == null) return null;
  try {
    return await i.diagnose();
  } catch (_) {
    return null;
  }
});
