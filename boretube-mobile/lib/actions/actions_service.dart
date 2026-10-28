import 'package:flutter/foundation.dart';

import '../agent/agent_client.dart';
import '../ops/tv_ops.dart';
import '../protocols/castv2_client.dart';
import '../protocols/dial_client.dart';
import '../tv/tv.dart';

enum ActionTransport { agent, sonyRest, adb, cast, dial, none }

class ActionResult {
  final bool ok;
  final ActionTransport via;
  final String detail;

  /// For [ActionsService.startBreak]: when the break ends.
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

/// The instant actions (Mute, Stop, Bore, Volume → N, Break, Restore).
/// Each tries the transports the TV supports, best first: TV Guard (when
/// healthy), then Sony REST, then ADB, then Cast. The first that succeeds
/// wins.
class ActionsService {
  final Tv tv;
  final TvOps? adb;

  /// A healthy TV Guard agent; null routes everything over ADB/Cast.
  final AgentClient? agent;
  final SonyAudio _sony;
  final CastV2Client Function() _cast;
  final DialClient _dial;

  ActionsService(
    this.tv, {
    this.adb,
    this.agent,
    CastV2Client Function()? cast,
    SonyAudio? sony,
    @visibleForTesting DialClient? dial,
  })  : _dial = dial ?? DialClient(host: tv.ip, port: tv.dialPort),
        _cast = cast ?? (() => CastV2Client(host: tv.ip, port: tv.castPort)),
        _sony = sony ??
            _DialSonyAudio(dial ?? DialClient(host: tv.ip, port: tv.dialPort));

  bool get _hasAgent => agent != null;
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

  Future<ActionResult> _agentDo(AgentAction a) async {
    final r = await agent!.action(a);
    return ActionResult(
      r.ok,
      ActionTransport.agent,
      detail: r.detail,
      until: r.endsAt,
    );
  }

  (ActionTransport, bool, Future<ActionResult> Function()) _viaAgent(
    AgentAction a,
  ) =>
      (ActionTransport.agent, _hasAgent, () => _agentDo(a));

  Future<ActionResult> _setMuted(bool muted) => _first([
        _viaAgent(
          AgentAction(muted ? AgentActionKind.mute : AgentActionKind.unmute),
        ),
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
        _viaAgent(const AgentAction(AgentActionKind.stop)),
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

  /// Stop + mute. When mute goes over Sony REST (not ADB), both run at
  /// once; otherwise one after the other.
  Future<ActionResult> bore() async {
    if (_hasAgent) {
      final r = await _first([
        _viaAgent(const AgentAction(AgentActionKind.bore)),
      ]);
      if (r.ok) return r;
    }
    final ActionResult stop;
    final ActionResult m;
    if (_hasSony && _hasAdb) {
      final both = await Future.wait([stopCurrentApp(), mute()]);
      stop = both[0];
      m = both[1];
    } else {
      stop = await stopCurrentApp();
      m = await mute();
    }
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
      _viaAgent(AgentAction.volume(t)),
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
    final e = await adb!.setVolumePercent(target);
    if (e == null) {
      return ActionResult(true, ActionTransport.adb, detail: 'at $target%');
    }
    return ActionResult(e.ok, ActionTransport.adb, detail: e.after);
  }

  /// Starts a break: stop + mute now, and returns when it ends. With TV
  /// Guard the TV enforces it ([ActionResult.via] is
  /// [ActionTransport.agent]); otherwise the caller keeps it going
  /// (re-mutes, closes apps) and restores at the end.
  Future<ActionResult> startBreak(int minutes, {DateTime? now}) =>
      _timed(AgentAction.startBreak(minutes), minutes, bore, now);

  /// Mutes for [minutes] without closing anything ("Silence only").
  Future<ActionResult> muteFor(int minutes, {DateTime? now}) =>
      _timed(AgentAction.muteFor(minutes), minutes, mute, now);

  Future<ActionResult> _timed(
    AgentAction a,
    int minutes,
    Future<ActionResult> Function() local,
    DateTime? now,
  ) async {
    final until = (now ?? DateTime.now()).add(Duration(minutes: minutes));
    if (_hasAgent) {
      try {
        final r = await _agentDo(a);
        if (r.ok) {
          return ActionResult(
            true,
            ActionTransport.agent,
            detail: r.detail,
            until: r.until ?? until,
          );
        }
      } catch (_) {
        // Fall back to the phone keeping it going.
      }
    }
    final r = await local();
    return ActionResult(r.ok, r.via, detail: r.detail, until: until);
  }

  /// Ends breaks and timed mutes on the TV, and unmutes.
  Future<ActionResult> restore() => _first([
        _viaAgent(const AgentAction(AgentActionKind.restore)),
        (ActionTransport.none, true, unmute),
      ]);
}
