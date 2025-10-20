import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common/sqlite_api.dart';

import 'paths.dart';

final databaseFactoryProvider = Provider<DatabaseFactory>((ref) {
  throw UnimplementedError(
    'databaseFactoryProvider must be overridden in main.dart before using the database.',
  );
});

final databaseProvider = FutureProvider<Database>((ref) async {
  final factory = ref.watch(databaseFactoryProvider);
  final dirs = await ref.watch(appDirectoriesProvider.future);
  final dbPath = p.join(dirs.dataDir.path, 'freecad_explorer.db');
  return openAppDatabase(factory, dbPath);
});

Future<Database> openAppDatabase(DatabaseFactory factory, String dbPath) {
  return factory.openDatabase(
    dbPath,
    options: OpenDatabaseOptions(
      version: 1,
      onConfigure: (database) async {
        await database.execute('PRAGMA foreign_keys = ON;');
      },
      onCreate: _createSchema,
      onUpgrade: _migrateSchema,
    ),
  );
}

Future<void> _createSchema(Database db, int version) async {
  await db.execute('''
    CREATE TABLE files (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      path TEXT UNIQUE NOT NULL,
      project_root TEXT NOT NULL,
      folder TEXT NOT NULL,
      filename TEXT NOT NULL,
      ext TEXT NOT NULL,
      mtime INTEGER NOT NULL,
      size INTEGER NOT NULL,
      has_thumbnail INTEGER NOT NULL DEFAULT 0,
      thumb_path TEXT,
      title TEXT,
      last_indexed INTEGER NOT NULL
    );
  ''');

  await db.execute('''
    CREATE TABLE file_meta (
      file_id INTEGER NOT NULL REFERENCES files(id) ON DELETE CASCADE,
      key TEXT NOT NULL,
      value TEXT,
      PRIMARY KEY (file_id, key)
    );
  ''');

  await db.execute('''
    CREATE TABLE file_meta_sidecar (
      file_id INTEGER NOT NULL REFERENCES files(id) ON DELETE CASCADE,
      key TEXT NOT NULL,
      value TEXT,
      PRIMARY KEY (file_id, key)
    );
  ''');

  await db.execute('''
    CREATE TABLE settings (
      key TEXT PRIMARY KEY,
      value TEXT
    );
  ''');
}

Future<void> _migrateSchema(Database db, int oldVersion, int newVersion) async {
  // No migrations yet. This placeholder allows future schema upgrades.
}

Future<T> runInTransaction<T>(
  Database db,
  Future<T> Function(Transaction txn) action,
) =>
    db.transaction<T>(action);
