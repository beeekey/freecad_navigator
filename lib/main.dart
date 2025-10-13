import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'core/db.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  // Initialize window manager for desktop platforms
  await windowManager.ensureInitialized();

  WindowOptions windowOptions = const WindowOptions(
    size: Size(1280, 720),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.normal,
    windowButtonVisibility: true,
  );

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
    // Set the window icon from assets
    await windowManager.setIcon('assets/images/FreeCadExplorer_Logo.png');
  });

  runApp(
    ProviderScope(
      overrides: [
        databaseFactoryProvider.overrideWithValue(databaseFactoryFfi),
      ],
      child: const FreecadExplorerApp(),
    ),
  );
}
