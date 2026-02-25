import '../models/tv_status.dart';
import '../models/whitelist_entry.dart';

/// Action the lock loop should take after evaluating
/// current TV state against lock config.
enum LockAction {
  /// Timer expired — stop the service.
  expired,

  /// TV is off or unreachable — skip this cycle.
  tvOffline,

  /// Non-whitelisted app detected — bore (stop + mute).
  bore,

  /// Volume exceeds cap — reduce to max.
  capVolume,

  /// Everything OK — just log status.
  ok,
}

/// Result of evaluating lock rules against TV state.
class LockDecision {
  final LockAction action;
  final String message;

  const LockDecision(this.action, this.message);

  /// Pure decision function — no side effects.
  ///
  /// Given current TV status and lock configuration,
  /// returns what action the lock loop should take.
  static LockDecision evaluate({
    required int remainingSeconds,
    required TvStatus? status,
    required bool lockApps,
    required bool lockVolume,
    required int maxVolume,
    required List<WhitelistEntry> whitelist,
  }) {
    if (remainingSeconds <= 0) {
      return const LockDecision(
        LockAction.expired,
        'Lock ended (timer expired)',
      );
    }

    if (status == null) {
      return const LockDecision(
        LockAction.tvOffline,
        'TV off/standby',
      );
    }

    // Whitelist enforcement
    if (lockApps && !status.isIdle) {
      final appId = status.appId;
      final allowed =
          whitelist.any((e) => e.appId == appId);
      if (!allowed) {
        return LockDecision(
          LockAction.bore,
          'STOPPED: ${status.appName}'
          ' (${status.appId})',
        );
      }
    }

    // Volume cap enforcement
    if (lockVolume &&
        !status.muted &&
        status.volume > maxVolume) {
      final label = status.appName.isEmpty
          ? 'idle'
          : status.appName;
      return LockDecision(
        LockAction.capVolume,
        '$label vol=${status.volume}%',
      );
    }

    // All OK — build status message
    final label = status.appName.isEmpty
        ? 'idle'
        : status.appName;
    final vol = '${status.volume}%'
        '${status.muted ? ' MUTED' : ''}';

    if (status.isIdle) {
      return LockDecision(
        LockAction.ok,
        'Home screen (idle) $vol',
      );
    }

    final wl = whitelist.any(
      (e) => e.appId == status.appId,
    );
    final tag = wl ? ' (whitelisted)' : '';
    return LockDecision(
      LockAction.ok,
      '$label$tag $vol',
    );
  }
}
