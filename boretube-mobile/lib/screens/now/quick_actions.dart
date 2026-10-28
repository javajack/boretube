import '../../tv/tv.dart';

/// The instant actions on the Now tab.
enum QuickAction { mute, stop, bore, volume, takeBreak, restore }

/// Sony panels report a wrong Cast volume, so Cast alone can't drive the
/// volume slider there.
bool isSonyTv(Tv tv) {
  final m = '${tv.manufacturer} ${tv.model}'.toLowerCase();
  return m.contains('sony') || m.contains('bravia');
}

/// Actions the TV's probed capabilities can actually perform.
Set<QuickAction> supportedActions(Tv tv) {
  final cast = tv.can(TvCapability.cast);
  final adb = tv.can(TvCapability.adb);
  final sony = tv.can(TvCapability.sonyRest);
  final dial = tv.can(TvCapability.dial);
  final mute = sony || adb || cast;
  final stop = adb || cast || dial;
  return {
    if (mute) QuickAction.mute,
    if (stop) QuickAction.stop,
    if (stop && mute) QuickAction.bore,
    if (sony || adb || (cast && !isSonyTv(tv))) QuickAction.volume,
    if (stop && mute) QuickAction.takeBreak,
    if (mute) QuickAction.restore,
  };
}
