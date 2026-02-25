import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'providers/providers.dart';
import 'screens/home_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/whitelist_screen.dart';

final _router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) =>
          const HomeScreen(),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) =>
          const SettingsScreen(),
    ),
    GoRoute(
      path: '/whitelist',
      builder: (context, state) =>
          const WhitelistScreen(),
    ),
  ],
);

class BoretubeApp extends ConsumerWidget {
  const BoretubeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Redirect to settings if not configured
    final configNotifier =
        ref.read(tvConfigProvider.notifier);
    final initialRoute =
        configNotifier.isConfigured ? '/' : '/settings';

    final router = GoRouter(
      initialLocation: initialRoute,
      routes: _router.configuration.routes,
    );

    return MaterialApp.router(
      title: 'Boretube',
      debugShowCheckedModeBanner: false,
      theme: _darkTheme,
      routerConfig: router,
    );
  }
}

final _darkTheme = ThemeData(
  brightness: Brightness.dark,
  colorScheme: ColorScheme.dark(
    primary: Colors.red.shade700,
    secondary: Colors.green.shade600,
    surface: const Color(0xFF1E1E1E),
  ),
  scaffoldBackgroundColor: const Color(0xFF121212),
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFF1E1E1E),
    elevation: 0,
  ),
  cardTheme: const CardThemeData(
    color: Color(0xFF1E1E1E),
    elevation: 2,
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      padding: const EdgeInsets.symmetric(
        horizontal: 24,
        vertical: 14,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
  ),
  useMaterial3: true,
);
