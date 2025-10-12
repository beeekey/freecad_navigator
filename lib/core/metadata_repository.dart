import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite_common/sqlite_api.dart';

import 'db.dart';

class MetadataRepository {
  MetadataRepository(this.db);

  final Database db;

  static const editableKeys = ['Title', 'Tags', 'Status', 'Notes'];

  Future<void> saveSidecar({
    required int fileId,
    required String filePath,
    required Map<String, String> values,
  }) async {
    final sanitized = <String, String>{};
    for (final entry in values.entries) {
      final trimmed = entry.value.trim();
      if (trimmed.isNotEmpty) {
        sanitized[entry.key] = trimmed;
      }
    }

    final sidecarFile = _sidecarFileFor(filePath);
    await _writeJsonAtomic(sidecarFile, sanitized);

    await runInTransaction(db, (txn) async {
      await txn.delete('file_meta_sidecar', where: 'file_id = ?', whereArgs: [fileId]);
      for (final entry in sanitized.entries) {
        await txn.insert('file_meta_sidecar', {
          'file_id': fileId,
          'key': entry.key,
          'value': entry.value,
        });
      }
      final title = sanitized['Title'];
      if (title != null && title.isNotEmpty) {
        await txn.update(
          'files',
          {'title': title},
          where: 'id = ?',
          whereArgs: [fileId],
        );
      }
    });
  }

  Future<Map<String, String>> readSidecar(String filePath) async {
    final sidecarFile = _sidecarFileFor(filePath);
    if (!await sidecarFile.exists()) {
      return {};
    }

    try {
      final raw = await sidecarFile.readAsString();
      final jsonMap = jsonDecode(raw) as Map<String, dynamic>;
      return jsonMap.map((key, value) => MapEntry(key, value?.toString() ?? ''));
    } catch (_) {
      return {};
    }
  }

  Future<void> deleteSidecar(String filePath) async {
    final sidecarFile = _sidecarFileFor(filePath);
    if (await sidecarFile.exists()) {
      await sidecarFile.delete();
    }
  }

  File _sidecarFileFor(String filePath) {
    return File('$filePath.fcmeta.json');
  }

  Future<void> _writeJsonAtomic(File file, Map<String, String> data) async {
    final directory = file.parent;
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    final tmpFile = File(p.join(directory.path, '.${p.basename(file.path)}.tmp'));
    final encoder = const JsonEncoder.withIndent('  ');
    await tmpFile.writeAsString('${encoder.convert(data)}\n');
    await tmpFile.rename(file.path);
  }
}
