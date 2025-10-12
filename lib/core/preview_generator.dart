import 'dart:async';
import 'dart:io';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import 'freecad_runner.dart';

class PreviewGenerationException implements Exception {
  PreviewGenerationException(this.message, [this.stderr]);

  final String message;
  final String? stderr;

  @override
  String toString() => 'PreviewGenerationException($message${stderr == null ? '' : ': $stderr'})';
}

Future<String> generatePreviewImage({
  required String freecadExecutable,
  required String filePath,
  required Directory cacheDir,
  int imageSize = 600,
  Duration timeout = const Duration(minutes: 2),
}) async {
  final hash = sha1.convert(utf8.encode(filePath)).toString();
  final outputPath = p.join(cacheDir.path, '$hash.png');
  final scriptPath = p.join(cacheDir.path, '$hash-preview.py');

  final escapedFilePath = _escapeForPython(filePath);
  final escapedOutputPath = _escapeForPython(outputPath);

  final script = '''
import FreeCAD
import os
import sys
import time

try:
    import FreeCADGui as Gui
except Exception as exc:
    sys.stderr.write(f"FreeCADGui import failed: {exc}\\n")
    sys.exit(2)

INPUT_PATH = r"""$escapedFilePath"""
OUTPUT_PATH = r"""$escapedOutputPath"""

def log(message):
    sys.stdout.write(message + "\\n")
    sys.stdout.flush()

os.makedirs(os.path.dirname(OUTPUT_PATH), exist_ok=True)

doc = None

try:
    log(f"Opening document: {INPUT_PATH}")
    doc = FreeCAD.open(INPUT_PATH)
    Gui.showMainWindow()
    Gui.activateWorkbench("PartWorkbench")
    Gui.updateGui()
    time.sleep(0.1)

    gui_doc = Gui.activeDocument()
    if gui_doc is None:
        sys.stderr.write("No active GUI document after opening file.\\n")
        sys.exit(3)

    view = gui_doc.activeView()
    if view is None:
        sys.stderr.write("No active view available for document.\\n")
        sys.exit(4)

    log("Configuring view")
    try:
        view.viewAxonometric()
    except Exception as exc:
        sys.stderr.write(f"viewAxonometric failed: {exc}\\n")
    try:
        view.fitAll()
    except Exception as exc:
        sys.stderr.write(f"fitAll failed: {exc}\\n")
    Gui.updateGui()
    time.sleep(0.1)

    log(f"Saving preview to {OUTPUT_PATH}")
    view.saveImage(OUTPUT_PATH, $imageSize, $imageSize, 'Transparent')
    Gui.updateGui()
    time.sleep(0.1)

    if not os.path.exists(OUTPUT_PATH):
        sys.stderr.write("saveImage completed but file was not found on disk.\\n")
        sys.exit(5)
    log("Preview saved successfully")
finally:
    try:
        if doc is not None:
            FreeCAD.closeDocument(doc.Name)
    except Exception:
        pass
''';

  await cacheDir.create(recursive: true);
  final outputFile = File(outputPath);
  if (await outputFile.exists()) {
    await outputFile.delete();
  }
  await File(scriptPath).writeAsString(script);
  try {
    final result = await runFreecadScript(
      freecadExecutable: freecadExecutable,
      scriptPath: scriptPath,
      timeout: timeout,
      requireGui: true,
    );

    if (!await outputFile.exists()) {
      final message = 'FreeCAD reported success but no preview image was created. Command: ${result.command}';
      throw PreviewGenerationException(
        message,
        result.stderr.isNotEmpty ? result.stderr : result.stdout,
      );
    }
  } on FreecadRunnerException catch (error) {
    throw PreviewGenerationException(error.message, error.stderr ?? error.stdout);
  }

  return outputPath;
}

String _escapeForPython(String value) {
  return value
      .replaceAll('\\', r'\\')
      .replaceAll('"""', r'\"\"\"');
}
