import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'core/db.dart';
import 'core/paths.dart';
import 'core/window_size_prefs.dart';
import 'models/settings_model.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  // Initialize window manager for desktop platforms
  await windowManager.ensureInitialized();

  final windowPreference = await _loadStoredWindowSizePreference();
  final initialSize = windowSizeForPreference(windowPreference) ??
      const Size(1280, 720);

  final windowOptions = WindowOptions(
    size: initialSize,
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.normal,
    windowButtonVisibility: true,
  );

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await applyWindowSizePreference(windowPreference);
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

Future<WindowSizePreference> _loadStoredWindowSizePreference() async {
  try {
    final directories = await loadAppDirectories();
    final dbPath = p.join(directories.dataDir.path, 'freecad_explorer.db');
    final db = await openAppDatabase(databaseFactoryFfi, dbPath);
    try {
      final rows = await db.query(
        'settings',
        columns: ['value'],
        where: 'key = ?',
        whereArgs: ['window_size_preference'],
        limit: 1,
      );
      if (rows.isEmpty) {
        return WindowSizePreference.standard;
      }
      final raw = rows.first['value'] as String?;
      return WindowSizePreferenceX.fromStorage(raw);
    } finally {
      await db.close();
    }
  } catch (_) {
    return WindowSizePreference.standard;
  }
}
