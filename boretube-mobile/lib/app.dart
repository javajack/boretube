import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'providers/security_providers.dart';
import 'providers/tv_providers.dart';
import 'screens/adb_guide_screen.dart';
import 'screens/lock_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/shell_screen.dart';
import 'screens/whitelist_screen.dart';
import 'security/app_lock.dart';
import 'ui/theme.dart';

/// Where the app should be, given lock state and saved TVs. Pure, so the
/// routing rules are easy to test.
String? appRedirect({
  required LockPhase phase,
  required bool hasTvs,
  required String location,
}) {
  const gates = {'/lock', '/setup-pin', '/splash'};
  switch (phase) {
    case LockPhase.loading:
      return location == '/splash' ? null : '/splash';
    case LockPhase.locked:
      return location == '/lock' ? null : '/lock';
    case LockPhase.setup:
      if (location == '/onboarding') return null;
      if (!hasTvs) return '/onboarding';
      return location == '/setup-pin' ? null : '/setup-pin';
    case LockPhase.unlocked:
      if (location == '/onboarding') return null;
      if (!hasTvs) return '/onboarding';
      return gates.contains(location) ? '/' : null;
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(appLockProvider.select((s) => s.phase), (_, __) {
    refresh.value++;
  });
  ref.listen(savedTvsProvider.select((l) => l.isNotEmpty), (_, __) {
    refresh.value++;
  });
  final router = GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) => appRedirect(
      phase: ref.read(appLockProvider).phase,
      hasTvs: ref.read(savedTvsProvider).isNotEmpty,
      location: state.matchedLocation,
    ),
    routes: [
      GoRoute(path: '/', builder: (_, __) => const ShellScreen()),
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/lock', builder: (_, __) => const LockScreen()),
      GoRoute(
        path: '/setup-pin',
        builder: (_, __) => const SetupPinScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (_, state) => OnboardingScreen(
          addMode: state.uri.queryParameters['add'] == '1',
        ),
      ),
      GoRoute(
        path: '/adb-guide',
        builder: (_, __) => const AdbGuideScreen(),
      ),
      GoRoute(
        path: '/whitelist',
        builder: (_, __) => const WhitelistScreen(),
      ),
    ],
  );
  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});

class BoretubeApp extends ConsumerStatefulWidget {
  const BoretubeApp({super.key});

  @override
  ConsumerState<BoretubeApp> createState() => _BoretubeAppState();
}

class _BoretubeAppState extends ConsumerState<BoretubeApp> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onHide: () {
        ref.read(appForegroundProvider.notifier).state = false;
        ref.read(appLockProvider.notifier).onBackground();
      },
      onShow: () {
        ref.read(appForegroundProvider.notifier).state = true;
        ref.read(appLockProvider.notifier).onForeground();
      },
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Boretube',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.dark,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
