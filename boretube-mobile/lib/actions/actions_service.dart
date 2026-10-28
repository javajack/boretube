import 'package:flutter/foundation.dart';

import '../ops/tv_ops.dart';
import '../protocols/castv2_client.dart';
import '../protocols/dial_client.dart';
import '../tv/tv.dart';

enum ActionTransport { sonyRest, adb, cast, dial, none }

class ActionResult {
  final bool ok;
  final ActionTransport via;
  final String detail;

  /// For [ActionsService.pauseTv]: when the pause ends.
  final DateTime? until;

  const ActionResult(
    this.ok,
    this.via, {
    this.detail = '',
    this.until,
  });

  @override
  String toString() => '${ok ? 'ok' : 'failed'} via ${via.name} $detail';
}

/// Volume / mute calls on Sony's REST API. [DialClient] implements these;
/// tests fake them.
abstract interface class SonyAudio {
  Future<({int volume, bool muted})?> getHardwareVolume();
  Future<bool> setHardwareVolume(int volume);
  Future<bool> setHardwareMute(bool muted);
}

class _DialSonyAudio implements SonyAudio {
  final DialClient dial;
  const _DialSonyAudio(this.dial);
  @override
  Future<({int volume, bool muted})?> getHardwareVolume() =>
      dial.getHardwareVolume();
  @override
  Future<bool> setHardwareVolume(int volume) => dial.setHardwareVolume(volume);
  @override
  Future<bool> setHardwareMute(bool muted) => dial.setHardwareMute(muted);
}

/// The instant actions (Mute, Stop, Bore, Volume → N, Pause, Restore).
/// Each tries the transports the TV supports, best first: Sony REST, then
/// ADB, then Cast. The first that succeeds wins.
class ActionsService {
  final Tv tv;
  final TvOps? adb;
  final SonyAudio _sony;
  final CastV2Client Function() _cast;
  final DialClient _dial;

  ActionsService(
    this.tv, {
    this.adb,
    CastV2Client Function()? cast,
    SonyAudio? sony,
    @visibleForTesting DialClient? dial,
  })  : _dial = dial ?? DialClient(host: tv.ip, port: tv.dialPort),
        _cast = cast ?? (() => CastV2Client(host: tv.ip, port: tv.castPort)),
        _sony = sony ??
            _DialSonyAudio(dial ?? DialClient(host: tv.ip, port: tv.dialPort));

  bool get _hasSony => tv.can(TvCapability.sonyRest);
  bool get _hasAdb => adb != null && tv.can(TvCapability.adb);
  bool get _hasCast => tv.can(TvCapability.cast);
  bool get _hasDial => tv.can(TvCapability.dial);

  Future<ActionResult> _first(
    List<(ActionTransport, bool, Future<ActionResult> Function())> options,
  ) async {
    final errors = <String>[];
    for (final (via, available, run) in options) {
      if (!available) continue;
      try {
        final r = await run();
        if (r.ok) return r;
        errors.add('${via.name}: ${r.detail}');
      } catch (e) {
        errors.add('${via.name}: $e');
      }
    }
    return ActionResult(
      false,
      ActionTransport.none,
      detail: errors.isEmpty ? 'No transport available' : errors.join('; '),
    );
  }

  Future<ActionResult> _castDo(
    Future<bool> Function(CastV2Client c) f,
  ) async {
    final c = _cast();
    try {
      return ActionResult(await f(c), ActionTransport.cast);
    } finally {
      await c.disconnect();
    }
  }

  Future<ActionResult> _setMuted(bool muted) => _first([
        (
          ActionTransport.sonyRest,
          _hasSony,
          () async => ActionResult(
                await _sony.setHardwareMute(muted),
                ActionTransport.sonyRest,
              ),
        ),
        (
          ActionTransport.adb,
          _hasAdb,
          () async {
            final e = await adb!.setMuted(muted);
            return ActionResult(
              e?.ok ?? true,
              ActionTransport.adb,
              detail: e == null ? 'already ${muted ? 'muted' : 'unmuted'}' : '',
            );
          },
        ),
        (
          ActionTransport.cast,
          _hasCast,
          () => _castDo((c) => muted ? c.mute() : c.unmute()),
        ),
      ]);

  Future<ActionResult> mute() => _setMuted(true);

  Future<ActionResult> unmute() => _setMuted(false);

  /// Stops the foreground app. ADB force-stops it (protected apps only get
  /// Home); Cast stops the receiver app and DIAL kills YouTube/Netflix.
  Future<ActionResult> stopCurrentApp() => _first([
        (
          ActionTransport.adb,
          _hasAdb,
          () async {
            final s = await adb!.stopForegroundApp();
            return ActionResult(
              s.pkg == null || s.forceStopped || s.sentHome,
              ActionTransport.adb,
              detail: [s.pkg ?? '', s.detail].join(' ').trim(),
            );
          },
        ),
        (ActionTransport.cast, _hasCast, () => _castDo((c) => c.stop())),
        (
          ActionTransport.dial,
          _hasDial,
          () async {
            await _dial.killApps();
            return const ActionResult(true, ActionTransport.dial);
          },
        ),
      ]);

  /// Stop + mute.
  Future<ActionResult> bore() async {
    final stop = await stopCurrentApp();
    final m = await mute();
    return ActionResult(
      stop.ok && m.ok,
      stop.ok ? m.via : stop.via,
      detail: 'stop: $stop; mute: $m',
    );
  }

  /// Sets the volume to [target] percent. Sony REST sets it directly; ADB
  /// steps with volume keys from the current reading (absolute set is
  /// ignored on the VU3); Cast as a last resort.
  Future<ActionResult> setVolume(int target) {
    final t = target.clamp(0, 100);
    return _first([
      (
        ActionTransport.sonyRest,
        _hasSony,
        () async => ActionResult(
              await _sony.setHardwareVolume(t),
              ActionTransport.sonyRest,
            ),
      ),
      (ActionTransport.adb, _hasAdb, () => _adbVolume(t)),
      (ActionTransport.cast, _hasCast, () => _castDo((c) => c.setVolume(t))),
    ]);
  }

  Future<ActionResult> _adbVolume(int target) async {
    final ops = adb!;
    final v = await ops.readVolume();
    if (v == null) {
      return const ActionResult(
        false,
        ActionTransport.adb,
        detail: 'Could not read volume',
      );
    }
    final goal = v.min + ((v.max - v.min) * target / 100).round();
    final diff = goal - v.level;
    if (diff == 0) {
      return ActionResult(true, ActionTransport.adb, detail: 'at $v');
    }
    final e = await ops.volumeStep(up: diff > 0, n: diff.abs().clamp(1, 100));
    return ActionResult(e.ok, ActionTransport.adb, detail: e.after);
  }

  /// P1: stop + mute and return when the pause ends. Nothing persists;
  /// the caller restores (or P2's agent enforces).
  Future<ActionResult> pauseTv(int minutes) async {
    final r = await bore();
    return ActionResult(
      r.ok,
      r.via,
      detail: r.detail,
      until: DateTime.now().add(Duration(minutes: minutes)),
    );
  }

  Future<ActionResult> restore() => unmute();
}
