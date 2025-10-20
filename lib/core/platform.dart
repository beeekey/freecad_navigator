import 'dart:io';

import 'package:path/path.dart' as p;

Future<void> openInFreecad({
  required String executable,
  required List<String> files,
}) async {
  if (executable.isEmpty) {
    throw ArgumentError('FreeCAD executable path is empty.');
  }

  final args = <String>[
    if (_supportsSingleInstance(executable)) '--single-instance',
    ...files,
  ];

  await Process.start(executable, args, mode: ProcessStartMode.detached);

  await _focusFreecadWindow(executable);
}

bool _supportsSingleInstance(String executable) {
  final name = p.basenameWithoutExtension(executable).toLowerCase();
  // FreeCADCmd (CLI) does not support the GUI single-instance handoff.
  return name != 'freecadcmd';
}

Future<void> _focusFreecadWindow(String executable) async {
  if (!_supportsSingleInstance(executable)) {
    return;
  }

  try {
    if (Platform.isMacOS) {
      final appName = _macAppName(executable);
      await Process.run('osascript', [
        '-e',
        'tell application "$appName" to activate',
      ]);
    } else if (Platform.isWindows) {
      final processName = p.basenameWithoutExtension(executable);
      final script =
          '''
\$ErrorActionPreference = 'SilentlyContinue'
\$proc = Get-Process -Name '$processName' -ErrorAction SilentlyContinue
if (-not \$proc) { return }
\$shell = New-Object -ComObject WScript.Shell
foreach (\$p in \$proc) {
  if (\$shell.AppActivate(\$p.Id)) { break }
}
''';
      await Process.run('powershell', [
        '-NoLogo',
        '-NoProfile',
        '-NonInteractive',
        '-Command',
        script,
      ]);
    } else if (Platform.isLinux) {
      final targets = <String>{
        'FreeCAD',
        p.basenameWithoutExtension(executable),
      };
      for (final target in targets) {
        if (await _tryRunCommand(['wmctrl', '-xa', target])) return;
        if (await _tryRunCommand(['wmctrl', '-a', target])) return;
        if (await _tryRunCommand([
          'xdotool',
          'search',
          '--class',
          target,
          'windowactivate',
        ])) {
          return;
        }
      }
    }
  } catch (_) {
    // Best-effort only; ignore focus errors.
  }
}

String _macAppName(String executable) {
  final segments = p.split(executable);
  for (var i = segments.length - 1; i >= 0; i--) {
    final segment = segments[i];
    if (segment.endsWith('.app')) {
      return segment.substring(0, segment.length - 4);
    }
  }
  return 'FreeCAD';
}

Future<bool> _tryRunCommand(List<String> command) async {
  try {
    final result = await Process.run(
      command.first,
      command.length > 1 ? command.sublist(1) : const [],
    );
    return result.exitCode == 0;
  } on ProcessException {
    return false;
  }
}

Future<void> revealInFileExplorer(String filePath) async {
  if (Platform.isWindows) {
    final args = ['/select,', filePath];
    await Process.start('explorer.exe', args, mode: ProcessStartMode.detached);
  } else if (Platform.isMacOS) {
    await Process.start('open', [
      '-R',
      filePath,
    ], mode: ProcessStartMode.detached);
  } else {
    // Linux and other Unix variants
    final directory = p.dirname(filePath);
    await Process.start('xdg-open', [
      directory,
    ], mode: ProcessStartMode.detached);
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
  final envPaths =
      Platform.environment['PATH']?.split(Platform.isWindows ? ';' : ':') ??
      const [];
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
