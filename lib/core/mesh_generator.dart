import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import 'freecad_runner.dart';

class MeshGenerationException implements Exception {
  MeshGenerationException(this.message, [this.stderr]);

  final String message;
  final String? stderr;

  @override
  String toString() => 'MeshGenerationException($message${stderr == null ? '' : ': $stderr'})';
}

String meshCachePath(Directory cacheDir, String filePath) {
  final hash = sha1.convert(utf8.encode(filePath)).toString();
  return p.join(cacheDir.path, '$hash.obj');
}

Future<String> generateMesh({
  required String freecadExecutable,
  required String filePath,
  required Directory cacheDir,
  Duration timeout = const Duration(minutes: 5),
}) async {
  final outputPath = meshCachePath(cacheDir, filePath);
  final scriptHash = sha1.convert(utf8.encode('$filePath-mesh-script')).toString();
  final scriptPath = p.join(cacheDir.path, '$scriptHash-mesh.py');

  final escapedFilePath = _escapeForPython(filePath);
  final escapedOutputPath = _escapeForPython(outputPath);

  final script = '''
import FreeCAD
import FreeCADGui as Gui
import Mesh
import os
import sys
import time

INPUT_PATH = r"""$escapedFilePath"""
OUTPUT_PATH = r"""$escapedOutputPath"""

def log(message):
    sys.stdout.write(message + "\\n")
    sys.stdout.flush()

export_objects = []

def collect_objects(container):
    for obj in container:
        if hasattr(obj, "Shape") and obj.Shape.Volume > 0:
            export_objects.append(obj)
        if hasattr(obj, "Group"):
            collect_objects(obj.Group)

try:
    os.makedirs(os.path.dirname(OUTPUT_PATH), exist_ok=True)
    log(f"Opening document: {INPUT_PATH}")
    doc = FreeCAD.open(INPUT_PATH)
    Gui.showMainWindow()
    Gui.activateWorkbench("PartWorkbench")
    Gui.updateGui()
    time.sleep(0.2)

    collect_objects(doc.Objects)
    if not export_objects:
        sys.stderr.write("No solid objects with volume found to export.\\n")
        sys.exit(6)

    log(f"Exporting {len(export_objects)} object(s) to {OUTPUT_PATH}")
    Mesh.export(export_objects, OUTPUT_PATH)
    time.sleep(0.2)

    if not os.path.exists(OUTPUT_PATH):
        sys.stderr.write("Mesh export completed but output file not found.\\n")
        sys.exit(7)
    log("Mesh export completed successfully")
finally:
    try:
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
      final message = 'FreeCAD reported success but did not create a mesh. Command: ${result.command}';
      throw MeshGenerationException(
        message,
        result.stderr.isNotEmpty ? result.stderr : result.stdout,
      );
    }
  } on FreecadRunnerException catch (error) {
    throw MeshGenerationException(
      error.message,
      error.stderr ?? error.stdout,
    );
  }

  return outputPath;
}

String _escapeForPython(String value) {
  return value.replaceAll('\\', r'\\');
}
