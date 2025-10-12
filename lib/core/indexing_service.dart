import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common/sqlite_api.dart';
import 'package:watcher/watcher.dart';

import '../features/settings/settings_controller.dart';
import '../models/file_record.dart';
import '../models/settings_model.dart';
import 'db.dart';
import 'fcstd_reader.dart';
import 'metadata_repository.dart';
import 'paths.dart';
import 'preview_generator.dart';
import 'reload_signal.dart';

final indexingControllerProvider =
    AsyncNotifierProvider<IndexingController, IndexingState>(
  IndexingController.new,
);

class IndexingState {
  const IndexingState({
    Set<String>? rootsInProgress,
    this.lastIndexedAt,
  }) : rootsInProgress = rootsInProgress ?? const {};

  final Set<String> rootsInProgress;
  final DateTime? lastIndexedAt;

  bool isIndexing(String root) => rootsInProgress.contains(root);

  IndexingState copyWith({
    Set<String>? rootsInProgress,
    DateTime? lastIndexedAt,
  }) {
    return IndexingState(
      rootsInProgress: rootsInProgress ?? this.rootsInProgress,
      lastIndexedAt: lastIndexedAt ?? this.lastIndexedAt,
    );
  }
}

class IndexingController extends AsyncNotifier<IndexingState> {
  late Database _db;
  late AppDirectories _dirs;
  late MetadataRepository _metadataRepository;

  final Map<String, StreamSubscription<WatchEvent>> _watchers = {};
  final Map<String, Timer> _debounceTimers = {};
  final Map<String, Future<void>> _scansInFlight = {};

  @override
  Future<IndexingState> build() async {
    _db = await ref.watch(databaseProvider.future);
    _dirs = await ref.watch(appDirectoriesProvider.future);
    _metadataRepository = MetadataRepository(_db);

    ref.listen<AsyncValue<SettingsState>>(
      settingsControllerProvider,
      (previous, next) {
        _handleSettingsChange(
          previous?.valueOrNull,
          next.valueOrNull,
        );
      },
      fireImmediately: true,
    );

    ref.onDispose(() async {
      for (final entry in _watchers.entries) {
        await entry.value.cancel();
      }
      _watchers.clear();
      for (final timer in _debounceTimers.values) {
        timer.cancel();
      }
      _debounceTimers.clear();
    });

    return const IndexingState();
  }

  void _handleSettingsChange(
    SettingsState? previous,
    SettingsState? next,
  ) {
    final previousRoots = {
      if (previous != null) ...previous.projectRoots.map((r) => r.path),
    };
    final nextRoots = {
      if (next != null) ...next.projectRoots.map((r) => r.path),
    };

    final added = nextRoots.difference(previousRoots);
    final removed = previousRoots.difference(nextRoots);

    for (final root in removed) {
      _stopWatcher(root);
      unawaited(_purgeProject(root));
    }

    for (final root in added) {
      _startWatcher(root);
      unawaited(ensureIndexed(root));
    }

    // Ensure active project stays indexed even if not newly added.
    final active = next?.activeProjectPath;
    if (active != null && nextRoots.contains(active)) {
      unawaited(ensureIndexed(active));
    }
  }

  Future<void> ensureIndexed(String projectRoot) {
    if (projectRoot.isEmpty) return Future.value();
    if (_scansInFlight.containsKey(projectRoot)) {
      return _scansInFlight[projectRoot]!;
    }
    final future = _performScan(projectRoot);
    _scansInFlight[projectRoot] = future;
    future.whenComplete(() {
      _scansInFlight.remove(projectRoot);
    });
    return future;
  }

  Future<void> reindexFile(String projectRoot, String filePath) async {
    try {
      final result = await parseFcstdFile(
        filePath: filePath,
        thumbnailCacheDir: _dirs.thumbCacheDir.path,
      );
      final sidecar = await _metadataRepository.readSidecar(filePath);
      await _upsertFile(projectRoot, result, sidecar);
      await _persistSidecar(filePath, sidecar);
      _triggerReload();
    } catch (error, stack) {
      debugPrint('Failed to reindex $filePath: $error\n$stack');
    }
  }

  Future<void> _performScan(String projectRoot) async {
    final directory = Directory(projectRoot);
    if (!await directory.exists()) {
      await _purgeProject(projectRoot);
      return;
    }

    _setRootIndexing(projectRoot, true);

    try {
      final discovered = await _discoverFcstdFiles(directory);
      final discoveredSet = discovered.toSet();

      for (final path in discovered) {
        try {
          final result = await parseFcstdFile(
            filePath: path,
            thumbnailCacheDir: _dirs.thumbCacheDir.path,
          );
          final sidecar = await _metadataRepository.readSidecar(path);
          await _upsertFile(projectRoot, result, sidecar);
          await _persistSidecar(path, sidecar);
        } catch (error, stack) {
          debugPrint('Failed to parse $path: $error\n$stack');
        }
      }

      await _pruneRemovedFiles(projectRoot, discoveredSet);

      _triggerReload();
      _updateLastIndexed();
    } finally {
      _setRootIndexing(projectRoot, false);
    }
  }

  Future<List<String>> _discoverFcstdFiles(Directory root) async {
    final files = <String>[];
    await for (final entity in root.list(recursive: true, followLinks: false)) {
      if (entity is File && entity.path.toLowerCase().endsWith('.fcstd')) {
        files.add(p.normalize(entity.path));
      }
    }
    return files;
  }

  Future<void> _upsertFile(
    String projectRoot,
    FileIndexResult result,
    Map<String, String> sidecar,
  ) async {
    final folderPath = p.normalize(
      p.relative(
        p.dirname(result.path),
        from: projectRoot,
      ),
    );
    final normalizedFolder =
        folderPath == '.' ? '' : folderPath == '..' ? '' : folderPath;

    final filename = p.basename(result.path);
    final ext = p.extension(result.path).replaceFirst('.', '').toUpperCase();
    final now = DateTime.now().millisecondsSinceEpoch;

    await runInTransaction(_db, (txn) async {
      final existing = await txn.query(
        'files',
        columns: ['id'],
        where: 'path = ?',
        whereArgs: [result.path],
        limit: 1,
      );

      int fileId;
      final baseValues = {
        'path': result.path,
        'project_root': projectRoot,
        'folder': normalizedFolder,
        'filename': filename,
        'ext': ext,
        'mtime': result.mtimeMs,
        'size': result.size,
        'has_thumbnail': result.hasThumbnail ? 1 : 0,
        'thumb_path': result.thumbnailPath,
        'title': _deriveTitle(result.metadata, sidecar, filename),
        'last_indexed': now,
      };

      if (existing.isEmpty) {
        fileId = await txn.insert('files', baseValues);
      } else {
        fileId = existing.first['id'] as int;
        await txn.update(
          'files',
          baseValues,
          where: 'id = ?',
          whereArgs: [fileId],
        );
        await txn.delete('file_meta', where: 'file_id = ?', whereArgs: [fileId]);
      }

      for (final entry in result.metadata.entries) {
        await txn.insert('file_meta', {
          'file_id': fileId,
          'key': entry.key,
          'value': entry.value,
        });
      }

      // Sidecar data persisted separately.
    });
  }

  Future<void> _persistSidecar(
    String filePath,
    Map<String, String> sidecar,
  ) async {
    final existing = await _db.query(
      'files',
      columns: ['id'],
      where: 'path = ?',
      whereArgs: [filePath],
      limit: 1,
    );
    if (existing.isEmpty) return;
    final fileId = existing.first['id'] as int;

    await runInTransaction(_db, (txn) async {
      await txn.delete('file_meta_sidecar', where: 'file_id = ?', whereArgs: [fileId]);
      for (final entry in sidecar.entries) {
        await txn.insert('file_meta_sidecar', {
          'file_id': fileId,
          'key': entry.key,
          'value': entry.value,
        });
      }
      final title = sidecar['Title'];
      if (title != null && title.trim().isNotEmpty) {
        await txn.update(
          'files',
          {'title': title.trim()},
          where: 'id = ?',
          whereArgs: [fileId],
        );
      }
    });
  }

  Future<void> _pruneRemovedFiles(
    String projectRoot,
    Set<String> discovered,
  ) async {
    final rows = await _db.query(
      'files',
      columns: ['id', 'path'],
      where: 'project_root = ?',
      whereArgs: [projectRoot],
    );

    for (final row in rows) {
      final path = row['path'] as String;
      if (!discovered.contains(path) && !File(path).existsSync()) {
        await _db.delete('files', where: 'id = ?', whereArgs: [row['id']]);
      }
    }
  }

  void _startWatcher(String projectRoot) {
    if (_watchers.containsKey(projectRoot)) {
      return;
    }
    if (!Directory(projectRoot).existsSync()) {
      return;
    }
    final watcher = DirectoryWatcher(
      projectRoot,
      pollingDelay: const Duration(seconds: 2),
    );
    final subscription = watcher.events.listen(
      (event) => _onWatchEvent(projectRoot, event),
      onError: (error) => debugPrint('Watcher error [$projectRoot]: $error'),
    );
    _watchers[projectRoot] = subscription;
  }

  void _stopWatcher(String projectRoot) {
    final subscription = _watchers.remove(projectRoot);
    subscription?.cancel();
  }

  void _onWatchEvent(String projectRoot, WatchEvent event) {
    final resolved = _resolveEventPath(projectRoot, event.path);

    void schedule(void Function() callback) {
      final existing = _debounceTimers.remove(resolved);
      existing?.cancel();
      _debounceTimers[resolved] = Timer(
        const Duration(milliseconds: 400),
        () {
          _debounceTimers.remove(resolved);
          callback();
        },
      );
    }

    final lower = resolved.toLowerCase();

    if (lower.endsWith('.fcstd')) {
      if (event.type == ChangeType.REMOVE) {
        schedule(() => _removeFile(resolved));
      } else {
        schedule(() => reindexFile(projectRoot, resolved));
      }
    } else if (lower.endsWith('.fcmeta.json')) {
      final target = resolved.substring(0, resolved.length - '.fcmeta.json'.length);
      schedule(() async {
        if (await File(target).exists()) {
          await reindexFile(projectRoot, target);
        } else {
          await _removeFile(target);
        }
      });
    } else if (event.type == ChangeType.REMOVE) {
      // Folder deletions
      schedule(() => ensureIndexed(projectRoot));
    }
  }

  Future<void> _removeFile(String filePath) async {
    final rows = await _db.query(
      'files',
      columns: ['id'],
      where: 'path = ?',
      whereArgs: [filePath],
      limit: 1,
    );
    if (rows.isEmpty) return;

    await _db.delete('files', where: 'id = ?', whereArgs: [rows.first['id']]);
    _triggerReload();
  }

  Future<void> _purgeProject(String projectRoot) async {
    await _db.delete('files', where: 'project_root = ?', whereArgs: [projectRoot]);
    _triggerReload();
  }

  void _triggerReload() {
    ref.read(filesReloadSignalProvider.notifier).state++;
  }

  void _updateLastIndexed() {
    final current = state.value ?? const IndexingState();
    state = AsyncValue.data(
      current.copyWith(lastIndexedAt: DateTime.now()),
    );
  }

  void _setRootIndexing(String root, bool indexing) {
    final current = state.value ?? const IndexingState();
    final updated = <String>{...current.rootsInProgress};
    if (indexing) {
      updated.add(root);
    } else {
      updated.remove(root);
    }
    state = AsyncValue.data(
      current.copyWith(rootsInProgress: updated),
    );
  }

  Future<String> generatePreviewFor(
    FileRecord record,
    String freecadExecutable,
  ) async {
    final outputPath = await generatePreviewImage(
      freecadExecutable: freecadExecutable,
      filePath: record.path,
      cacheDir: _dirs.thumbCacheDir,
    );

    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.update(
      'files',
      {
        'has_thumbnail': 1,
        'thumb_path': outputPath,
        'last_indexed': now,
      },
      where: 'id = ?',
      whereArgs: [record.id],
    );

    _triggerReload();
    return outputPath;
  }

  String _deriveTitle(
    Map<String, String> builtins,
    Map<String, String> sidecar,
    String filename,
  ) {
    final sidecarTitle = sidecar['Title'];
    if (sidecarTitle != null && sidecarTitle.trim().isNotEmpty) {
      return sidecarTitle.trim();
    }
    final builtinTitle = builtins['Title'] ?? builtins['Label'];
    if (builtinTitle != null && builtinTitle.trim().isNotEmpty) {
      return builtinTitle.trim();
    }
    return filename.replaceAll(RegExp(r'\.FCStd$', caseSensitive: false), '');
  }

  String _resolveEventPath(String projectRoot, String eventPath) {
    if (p.isAbsolute(eventPath)) {
      return p.normalize(eventPath);
    }
    return p.normalize(p.join(projectRoot, eventPath));
  }
}
