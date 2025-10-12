import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:developer' as developer;

import 'package:path/path.dart' as p;

class FreecadRunResult {
  FreecadRunResult({
    required this.command,
    required this.stdout,
    required this.stderr,
    required this.exitCode,
  });

  final String command;
  final String stdout;
  final String stderr;
  final int exitCode;
}

class FreecadRunnerException implements Exception {
  FreecadRunnerException(
    this.message, {
    this.command,
    this.stdout,
    this.stderr,
    this.exitCode,
  });

  final String message;
  final String? command;
  final String? stdout;
  final String? stderr;
  final int? exitCode;

  @override
  String toString() => 'FreecadRunnerException($message)';
}

Future<FreecadRunResult> runFreecadScript({
  required String freecadExecutable,
  required String scriptPath,
  Duration timeout = const Duration(minutes: 2),
  bool requireGui = true,
}) async {
  var executableToRun = freecadExecutable;
  final exeLowerInitial = executableToRun.toLowerCase();
  if (requireGui && exeLowerInitial.contains('freecadcmd')) {
    final guiExecutable = await _findSiblingExecutable(executableToRun, 'FreeCAD');
    if (guiExecutable != null) {
      developer.log('Switching FreeCADCmd to GUI executable at $guiExecutable', name: 'freecad');
      executableToRun = guiExecutable;
    } else {
      throw FreecadRunnerException(
        'Preview generation requires the FreeCAD GUI executable. Configure FreeCAD (not FreeCADCmd) in Settings.',
      );
    }
  }

  final baseArgs = <String>[
    '--console',
    if (Platform.isWindows) '--python',
    scriptPath,
  ];

  var processExecutable = executableToRun;
  var processArgs = List<String>.from(baseArgs);

  final displayVar = Platform.environment['DISPLAY'];
  if (Platform.isLinux && (displayVar == null || displayVar.isEmpty)) {
    final xvfbRun = await _findInPath('xvfb-run');
    if (xvfbRun == null) {
      throw FreecadRunnerException(
        'Cannot generate preview: DISPLAY is not set. Install xvfb-run or launch FreeCAD in a desktop session.',
      );
    }
    processExecutable = xvfbRun;
    processArgs = [
      '--auto-servernum',
      '--server-args=-screen 0 1024x768x24',
      '--',
      executableToRun,
      ...baseArgs,
    ];
    developer.log('Wrapping FreeCAD invocation with xvfb-run.', name: 'freecad');
  }

  final commandDescription = '$processExecutable ${processArgs.join(' ')}';
  developer.log('Running: $commandDescription', name: 'freecad');

  ProcessResult result;
  try {
    result = await Process.run(
      processExecutable,
      processArgs,
      stdoutEncoding: utf8,
      stderrEncoding: utf8,
    ).timeout(timeout);
  } on TimeoutException {
    final message = 'FreeCAD execution timed out. Command: $commandDescription';
    developer.log('Timeout: $message', name: 'freecad', level: 900);
    throw FreecadRunnerException(message, command: commandDescription);
  }

  final stdoutText = (result.stdout as String?)?.trim() ?? '';
  final stderrText = (result.stderr as String?)?.trim() ?? '';

  if (result.exitCode != 0) {
    final buffer = StringBuffer()
      ..writeln('FreeCAD exited with code ${result.exitCode}.')
      ..writeln('Command: $commandDescription');
    if (stderrText.isNotEmpty) {
      buffer
        ..writeln('STDERR:')
        ..writeln(stderrText);
    }
    if (stdoutText.isNotEmpty) {
      buffer
        ..writeln('STDOUT:')
        ..writeln(stdoutText);
    }

    final message = buffer.toString().trim();
    developer.log('Failure:\n$message', name: 'freecad', level: 1000);
    throw FreecadRunnerException(
      message,
      command: commandDescription,
      stdout: stdoutText,
      stderr: stderrText,
      exitCode: result.exitCode,
    );
  }

  return FreecadRunResult(
    command: commandDescription,
    stdout: stdoutText,
    stderr: stderrText,
    exitCode: result.exitCode,
  );
}

Future<String?> _findInPath(String command) async {
  final separator = Platform.isWindows ? ';' : ':';
  final paths = Platform.environment['PATH']?.split(separator) ?? const [];
  for (final pathEntry in paths) {
    final trimmed = pathEntry.trim();
    if (trimmed.isEmpty) continue;
    final candidate = File(p.join(trimmed, command));
    if (await candidate.exists()) {
      return candidate.path;
    }
    if (Platform.isWindows) {
      final exeCandidate = File(p.join(trimmed, '$command.exe'));
      if (await exeCandidate.exists()) {
        return exeCandidate.path;
      }
    }
  }
  return null;
}

Future<String?> _findSiblingExecutable(String executablePath, String siblingBaseName) async {
  final file = File(executablePath);
  final directory = file.parent;
  final candidates = Platform.isWindows
      ? [
          '$siblingBaseName.exe',
          '$siblingBaseName.exe'.toLowerCase(),
        ]
      : [siblingBaseName, siblingBaseName.toLowerCase()];

  for (final candidate in candidates) {
    final path = p.join(directory.path, candidate);
    if (await File(path).exists()) {
      return path;
    }
  }
  return null;
}
