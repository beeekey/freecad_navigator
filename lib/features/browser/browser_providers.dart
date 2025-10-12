import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common/sqlite_api.dart';

import '../../core/db.dart';
import '../../core/reload_signal.dart';
import '../../models/file_record.dart';
import '../settings/settings_controller.dart';
import 'browser_controller.dart';

typedef FolderQuery = ({String projectRoot, String folder, String search, bool includeSubfolders, BrowserSort sort});

final activeProjectPathProvider = Provider<String?>((ref) {
  final settings = ref.watch(settingsControllerProvider);
  return settings.when(
    data: (value) => value.activeProjectPath,
    loading: () => null,
    error: (_, __) => null,
  );
});

final filesInFolderProvider =
    FutureProvider.autoDispose.family<List<FileRecord>, FolderQuery>(
  (ref, args) async {
    if (args.projectRoot.isEmpty) {
      return const [];
    }

    // Re-run when invalidated by the indexing service.
    ref.watch(filesReloadSignalProvider);

    final db = await ref.watch(databaseProvider.future);
    final whereClauses = <String>['project_root = ?'];
    final whereArgs = <Object?>[args.projectRoot];

    if (args.includeSubfolders) {
      if (args.folder.isNotEmpty) {
        final escaped = args.folder.replaceAll('%', '\\%').replaceAll('_', '\\_');
        whereClauses.add('(folder = ? OR folder LIKE ? ESCAPE "\\")');
        whereArgs.addAll([
          args.folder,
          '$escaped/%',
        ]);
      }
    } else {
      whereClauses.add('folder = ?');
      whereArgs.add(args.folder);
    }

    final rows = await db.query(
      'files',
      where: whereClauses.join(' AND '),
      whereArgs: whereArgs,
      orderBy: _orderByClause(args.sort),
    );

    if (rows.isEmpty) {
      return const [];
    }

    final ids = rows.map((row) => row['id'] as int).toList();
    final meta = await _loadMetadata(db, 'file_meta', ids);
    final sidecar = await _loadMetadata(db, 'file_meta_sidecar', ids);

    final records = rows
        .map(
          (row) => FileRecord.fromRow(
            row,
            builtinMeta: meta[row['id']] ?? const {},
            sidecarMeta: sidecar[row['id']] ?? const {},
          ),
        )
        .toList();

    if (args.search.isNotEmpty) {
      final keyword = args.search.toLowerCase();
      final filtered = records.where((record) {
        final fields = <String?>[
          record.filename,
          record.filenameWithoutExtension,
          record.displayTitle,
          record.folder,
          record.sidecarMeta['Tags'],
          record.builtinMeta['Tags'],
          record.sidecarMeta['Label'],
          record.builtinMeta['Label'],
          record.sidecarMeta['Comment'],
          record.builtinMeta['Comment'],
          record.sidecarMeta['Company'],
          record.builtinMeta['Company'],
          record.sidecarMeta['CreatedBy'],
          record.builtinMeta['CreatedBy'],
        ];
        return fields
            .whereType<String>()
            .map((value) => value.toLowerCase())
            .any((value) => value.contains(keyword));
      }).toList();
      filtered.sort((a, b) => _compareRecords(a, b, args.sort));
      return filtered;
    }

    return records;
  },
);

Future<Map<int, Map<String, String>>> _loadMetadata(
  Database db,
  String table,
  List<int> ids,
) async {
  if (ids.isEmpty) {
    return {};
  }
  final placeholders = List.filled(ids.length, '?').join(',');
  final query = 'SELECT file_id, key, value FROM $table WHERE file_id IN ($placeholders)';
  final result = await db.rawQuery(query, ids);
  final map = <int, Map<String, String>>{};
  for (final row in result) {
    final fileId = row['file_id'] as int;
    final key = row['key'] as String;
    final value = row['value'] as String?;
    map.putIfAbsent(fileId, () => <String, String>{})[key] = value ?? '';
  }
  return map;
}

final fileByIdProvider =
    FutureProvider.autoDispose.family<FileRecord?, int>(
  (ref, fileId) async {
    ref.watch(filesReloadSignalProvider);
    final db = await ref.watch(databaseProvider.future);
    final rows = await db.query(
      'files',
      where: 'id = ?',
      whereArgs: [fileId],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    final builtin = await _loadMetadata(db, 'file_meta', [fileId]);
    final sidecar = await _loadMetadata(db, 'file_meta_sidecar', [fileId]);
    return FileRecord.fromRow(
      rows.first,
      builtinMeta: builtin[fileId] ?? const {},
      sidecarMeta: sidecar[fileId] ?? const {},
    );
  },
);

String _orderByClause(BrowserSort sort) {
  switch (sort) {
    case BrowserSort.nameAsc:
      return 'filename COLLATE NOCASE ASC';
    case BrowserSort.nameDesc:
      return 'filename COLLATE NOCASE DESC';
    case BrowserSort.dateAsc:
      return 'mtime ASC, filename COLLATE NOCASE ASC';
    case BrowserSort.dateDesc:
      return 'mtime DESC, filename COLLATE NOCASE ASC';
  }
}

int _compareRecords(FileRecord a, FileRecord b, BrowserSort sort) {
  switch (sort) {
    case BrowserSort.nameAsc:
      return a.filename.toLowerCase().compareTo(b.filename.toLowerCase());
    case BrowserSort.nameDesc:
      return b.filename.toLowerCase().compareTo(a.filename.toLowerCase());
    case BrowserSort.dateAsc:
      final cmp = a.mtime.compareTo(b.mtime);
      return cmp != 0 ? cmp : a.filename.toLowerCase().compareTo(b.filename.toLowerCase());
    case BrowserSort.dateDesc:
      final cmp = b.mtime.compareTo(a.mtime);
      return cmp != 0 ? cmp : a.filename.toLowerCase().compareTo(b.filename.toLowerCase());
  }
}
