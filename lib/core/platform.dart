import 'dart:io';

import 'package:path/path.dart' as p;

Future<void> openInFreecad({
  required String executable,
  required List<String> files,
}) async {
  if (executable.isEmpty) {
    throw ArgumentError('FreeCAD executable path is empty.');
  }

  await Process.start(
    executable,
    files,
    mode: ProcessStartMode.detached,
  );
}

Future<void> revealInFileExplorer(String filePath) async {
  if (Platform.isWindows) {
    final args = ['/select,', filePath];
    await Process.start('explorer.exe', args, mode: ProcessStartMode.detached);
  } else if (Platform.isMacOS) {
    await Process.start('open', ['-R', filePath], mode: ProcessStartMode.detached);
  } else {
    // Linux and other Unix variants
    final directory = p.dirname(filePath);
    await Process.start('xdg-open', [directory], mode: ProcessStartMode.detached);
  }
}

Future<String?> detectFreecadExecutable() async {
  const candidates = [
    'FreeCAD',
    'freecad',
    r'C:\Program Files\FreeCAD 0.21\bin\FreeCAD.exe',
    r'C:\Program Files\FreeCAD 0.20\bin\FreeCAD.exe',
    '/Applications/FreeCAD.app/Contents/MacOS/FreeCAD',
  ];

  for (final candidate in candidates) {
    final expanded = candidate.replaceAllMapped(
      RegExp(r'^~'),
      (match) => Platform.environment['HOME'] ?? '',
    );

    final file = File(expanded);
    if (await file.exists()) {
      return file.path;
    }

    if (!candidate.contains(Platform.pathSeparator)) {
      // Try to resolve via PATH
      final resolved = await _which(candidate);
      if (resolved != null) {
        return resolved;
      }
    }
  }

  return null;
}

Future<String?> _which(String command) async {
  final envPaths = Platform.environment['PATH']?.split(Platform.isWindows ? ';' : ':') ?? const [];
  for (final path in envPaths) {
    final fullPath = p.join(path, command);
    final file = File(fullPath);
    if (await file.exists()) {
      return file.path;
    }
    if (Platform.isWindows) {
      final exePath = '$fullPath.exe';
      final exeFile = File(exePath);
      if (await exeFile.exists()) {
        return exeFile.path;
      }
    }
  }
  return null;
}
