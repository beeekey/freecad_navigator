import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'features/browser/browser_page.dart';
import 'features/settings/settings_page.dart';
import 'features/settings/settings_controller.dart';
import 'models/settings_model.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    routes: [
      GoRoute(
        path: '/',
        name: 'browser',
        builder: (context, state) => const BrowserPage(),
        routes: [
          GoRoute(
            path: 'settings',
            name: 'settings',
            builder: (context, state) => const SettingsPage(),
          ),
        ],
      ),
    ],
  );
});

class FreecadExplorerApp extends ConsumerWidget {
  const FreecadExplorerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final settings = ref.watch(settingsControllerProvider);
    final themeMode = settings.maybeWhen(
      data: (value) => value.themePreference.toThemeMode(),
      orElse: () => ThemeMode.system,
    );

    return MaterialApp.router(
      title: 'FreeCAD Explorer',
      theme: _lightTheme,
      darkTheme: _darkTheme,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}

final _lightTheme = ThemeData(
  colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF005585)),
  useMaterial3: true,
  scaffoldBackgroundColor: Colors.grey.shade100,
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.transparent,
    elevation: 0,
    scrolledUnderElevation: 2,
    centerTitle: false,
  ),
);

final _darkTheme = ThemeData(
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFF005585),
    brightness: Brightness.dark,
  ),
  useMaterial3: true,
  scaffoldBackgroundColor: const Color(0xFF121212),
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.transparent,
    elevation: 0,
    scrolledUnderElevation: 2,
    centerTitle: false,
  ),
);
