import '../../ops/health.dart';

/// A health check in parent words. The ops layer keeps its technical ids,
/// titles and details (shown only under "Technical details"); this is
/// what the screen says.
typedef HealthLook = ({String title, String detail});

final _pending = RegExp(r'^(\d+)/(\d+) disabled');

/// Plain title and detail for [c]. "ADB" never appears here.
HealthLook healthLook(HealthCheck c) {
  final ok = c.status == HealthStatus.ok;
  final unknown = c.status == HealthStatus.unknown;
  switch (c.id) {
    case 'adb':
      return (
        title: 'Home mode connection',
        detail: ok
            ? 'This phone can reach the TV directly'
            : 'This phone can\'t reach the TV directly right now',
      );
    case 'cleanup':
      final m = _pending.firstMatch(c.detail);
      final done = int.tryParse(m?.group(1) ?? '');
      final all = int.tryParse(m?.group(2) ?? '');
      final left = done == null || all == null ? null : all - done;
      return (
        title: 'Clean TV',
        detail: ok
            ? 'Promo and ad apps are tidied away'
            : left == null
                ? 'Some promo apps are back'
                : left == 1
                    ? '1 promo or ad app is back'
                    : '$left promo and ad apps are back',
      );
    case 'stockYouTube':
      return (
        title: 'YouTube without Shorts',
        detail: c.detail.startsWith('Installed (allowed)')
            ? 'The TV\'s own YouTube stays, as you chose'
            : ok
                ? 'The TV\'s own YouTube is hidden'
                : 'The TV\'s own YouTube is back, with Shorts',
      );
    case 'speech':
      return (
        title: 'Voice search',
        detail: ok
            ? 'Works'
            : c.status == HealthStatus.fail
                ? 'A TV update broke it. Fix puts back the version that works'
                : 'Works, but not on the version we know is good',
      );
    case 'launcher':
      return (
        title: 'Home button',
        detail: ok
            ? 'Opens your calm home screen'
            : 'Goes to the busy home screen again',
      );
    case 'agent':
      return (title: 'Always On', detail: _agentDetail(c));
  }
  if (c.id == 'agent.mediaAccess') {
    return (
      title: agentCheckTitle('mediaAccess'),
      detail: ok
          ? 'Knows the video that\'s on, so it can pause after it'
          : unknown
              ? 'Not checked yet'
              : 'Sees less than it could. Repair gives it the permission',
    );
  }
  if (c.id.startsWith('agent.')) {
    return (
      title: agentCheckTitle(c.id.substring(6)),
      detail: ok
          ? 'Fine'
          : unknown
              ? 'Not checked yet'
              : c.detail.isEmpty
                  ? 'Needs a look'
                  : _soften(c.detail),
    );
  }
  return (
    title: c.title,
    detail: unknown ? 'Couldn\'t check this one' : _soften(c.detail),
  );
}

String _agentDetail(HealthCheck c) => switch (c.status) {
      HealthStatus.ok => 'Running and keeping your routines',
      HealthStatus.warn => c.detail.contains('Safe')
          ? 'Hands off: watching only, changing nothing'
          : 'Paused by you',
      HealthStatus.fail => 'Not answering. Repair usually fixes it',
      HealthStatus.unknown => c.detail.isEmpty ? 'Checking…' : c.detail,
    };

/// Technical words that may leak from detail strings.
String _soften(String s) => s
    .replaceAll(RegExp(r'\bADB\b'), 'Home mode')
    .replaceAll(RegExp(r'\bagent\b', caseSensitive: false), 'Always On');

/// Parent words for Always On's own checks.
String agentCheckTitle(String id) => switch (id) {
      'youtube' || 'stockYouTube' => 'Keeps Shorts away',
      'speech' || 'tts' => 'Keeps voice search working',
      'cleanup' => 'Keeps the TV tidy',
      'launcher' || 'home' => 'Keeps the Home button calm',
      'selfAdb' => 'Can close apps on the TV',
      'usage' || 'usageStats' || 'usageAccess' => 'Can see what\'s on',
      'overlay' => 'Can show the friendly message',
      'notifications' => 'Can show it\'s running',
      'profile' => 'Knows this TV model',
      'build' => 'TV software',
      'watchdog' => 'Tidy-up after TV updates',
      'sound' => 'Can control the sound',
      'clock' => 'TV clock',
      'mode' => 'Always On mode',
      'mediaAccess' => 'Can see what\'s playing',
      _ => id.isEmpty
          ? 'Always On check'
          : '${id[0].toUpperCase()}${id.substring(1)}',
    };
