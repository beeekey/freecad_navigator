import 'dart:ui';

import 'package:window_manager/window_manager.dart';

import '../models/settings_model.dart';

Size? windowSizeForPreference(WindowSizePreference preference) {
  switch (preference) {
    case WindowSizePreference.compact:
      return const Size(1024, 640);
    case WindowSizePreference.standard:
      return const Size(1280, 720);
    case WindowSizePreference.spacious:
      return const Size(1440, 900);
    case WindowSizePreference.hd:
      return const Size(1920, 1080);
    case WindowSizePreference.qhd:
      return const Size(2560, 1440);
    case WindowSizePreference.uhd:
      return const Size(3840, 2160);
    case WindowSizePreference.maximized:
      return null;
  }
}

Future<void> applyWindowSizePreference(WindowSizePreference preference) async {
  final size = windowSizeForPreference(preference);
  if (size == null) {
    await windowManager.maximize();
    return;
  }

  final isMaximized = await windowManager.isMaximized();
  if (isMaximized) {
    await windowManager.unmaximize();
  }
  await windowManager.setSize(size);
  await windowManager.center();
}
