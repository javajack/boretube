import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../security/app_lock.dart';
import '../security/biometric.dart';
import '../security/pin_store.dart';
import 'providers.dart';
import 'tv_providers.dart';

final pinStoreProvider = Provider<PinStore>(
  (ref) => PinStore(store: ref.watch(secretStoreProvider)),
);

final biometricAuthProvider =
    Provider<BiometricAuth>((ref) => LocalBiometricAuth());

final biometricAvailableProvider = FutureProvider<bool>(
  (ref) => ref.watch(biometricAuthProvider).isAvailable(),
);

final appLockProvider =
    StateNotifierProvider<AppLockController, AppLockState>(
  (ref) => AppLockController(
    pins: ref.watch(pinStoreProvider),
    prefs: ref.watch(sharedPrefsProvider),
    biometric: ref.watch(biometricAuthProvider),
  ),
);
