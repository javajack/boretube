import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'biometric.dart';
import 'pin_store.dart';

enum LockPhase {
  /// Reading secure storage.
  loading,

  /// No PIN yet: first run must set one.
  setup,
  locked,
  unlocked,
}

class AppLockState {
  final LockPhase phase;
  final bool biometricEnabled;
  final int failedAttempts;

  /// Set after too many wrong PINs; no attempts until then.
  final DateTime? coolDownUntil;

  const AppLockState({
    required this.phase,
    this.biometricEnabled = false,
    this.failedAttempts = 0,
    this.coolDownUntil,
  });

  AppLockState copyWith({
    LockPhase? phase,
    bool? biometricEnabled,
    int? failedAttempts,
    DateTime? coolDownUntil,
    bool clearCoolDown = false,
  }) =>
      AppLockState(
        phase: phase ?? this.phase,
        biometricEnabled: biometricEnabled ?? this.biometricEnabled,
        failedAttempts: failedAttempts ?? this.failedAttempts,
        coolDownUntil:
            clearCoolDown ? null : coolDownUntil ?? this.coolDownUntil,
      );
}

/// Parent PIN / biometric gate. Locked on cold start and after
/// [relockAfter] in the background.
class AppLockController extends StateNotifier<AppLockState> {
  static const biometricKey = 'biometric_enabled';
  static const maxAttempts = 5;
  static const coolDown = Duration(seconds: 30);

  final PinStore pins;
  final SharedPreferences prefs;
  final BiometricAuth biometric;
  final Duration relockAfter;
  final DateTime Function() _now;
  DateTime? _backgroundedAt;

  AppLockController({
    required this.pins,
    required this.prefs,
    required this.biometric,
    this.relockAfter = const Duration(minutes: 5),
    DateTime Function()? clock,
  })  : _now = clock ?? DateTime.now,
        super(const AppLockState(phase: LockPhase.loading)) {
    _init();
  }

  Future<void> _init() async {
    bool has;
    try {
      has = await pins.hasPin();
    } catch (_) {
      has = false;
    }
    if (!mounted) return;
    state = AppLockState(
      phase: has ? LockPhase.locked : LockPhase.setup,
      biometricEnabled: has && (prefs.getBool(biometricKey) ?? false),
    );
  }

  bool get coolingDown {
    final until = state.coolDownUntil;
    return until != null && _now().isBefore(until);
  }

  /// Unlocks when [pin] matches. Returns false on a wrong PIN or while
  /// cooling down after [maxAttempts] failures.
  Future<bool> unlock(String pin) async {
    if (coolingDown) return false;
    if (await pins.verify(pin)) {
      state = state.copyWith(
        phase: LockPhase.unlocked,
        failedAttempts: 0,
        clearCoolDown: true,
      );
      return true;
    }
    final fails = state.failedAttempts + 1;
    state = fails >= maxAttempts
        ? state.copyWith(
            failedAttempts: 0,
            coolDownUntil: _now().add(coolDown),
          )
        : state.copyWith(failedAttempts: fails);
    return false;
  }

  Future<bool> unlockWithBiometric() async {
    if (!state.biometricEnabled || state.phase != LockPhase.locked) {
      return false;
    }
    final ok = await biometric.authenticate('Unlock Boretube');
    if (ok && mounted) {
      state = state.copyWith(phase: LockPhase.unlocked, failedAttempts: 0);
    }
    return ok;
  }

  /// First-run PIN; unlocks the app.
  Future<void> setPin(String pin) async {
    await pins.setPin(pin);
    state = state.copyWith(phase: LockPhase.unlocked, failedAttempts: 0);
  }

  /// Changes the PIN after checking [current].
  Future<bool> changePin(String current, String next) async {
    if (!await pins.verify(current)) return false;
    await pins.setPin(next);
    return true;
  }

  Future<void> setBiometricEnabled(bool on) async {
    await prefs.setBool(biometricKey, on);
    state = state.copyWith(biometricEnabled: on);
  }

  void lockNow() {
    if (state.phase == LockPhase.unlocked) {
      state = state.copyWith(phase: LockPhase.locked);
    }
  }

  void onBackground() => _backgroundedAt = _now();

  void onForeground() {
    final at = _backgroundedAt;
    _backgroundedAt = null;
    if (at != null && _now().difference(at) >= relockAfter) lockNow();
  }
}
