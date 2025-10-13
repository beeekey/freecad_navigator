import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class AppDirectories {
  AppDirectories({
    required this.dataDir,
    required this.cacheDir,
    required this.thumbCacheDir,
    required this.meshCacheDir,
  });

  final Directory dataDir;
  final Directory cacheDir;
  final Directory thumbCacheDir;
  final Directory meshCacheDir;
}

final appDirectoriesProvider = FutureProvider<AppDirectories>((ref) async {
  final dataDir = await getApplicationSupportDirectory();
  final cacheDir = await getApplicationCacheDirectory();
  final thumbCacheDir = Directory(p.join(cacheDir.path, 'thumbnails'));
  final meshCacheDir = Directory(p.join(cacheDir.path, 'meshes'));

  await _migrateLegacyPaths(
    newDataDir: dataDir,
    newCacheDir: cacheDir,
    newThumbDir: thumbCacheDir,
    newMeshDir: meshCacheDir,
  );

  if (!await dataDir.exists()) {
    await dataDir.create(recursive: true);
  }
  if (!await cacheDir.exists()) {
    await cacheDir.create(recursive: true);
  }
  if (!await thumbCacheDir.exists()) {
    await thumbCacheDir.create(recursive: true);
  }
  if (!await meshCacheDir.exists()) {
    await meshCacheDir.create(recursive: true);
  }

  return AppDirectories(
    dataDir: dataDir,
    cacheDir: cacheDir,
    thumbCacheDir: thumbCacheDir,
    meshCacheDir: meshCacheDir,
  );
});

Future<void> _migrateLegacyPaths({
  required Directory newDataDir,
  required Directory newCacheDir,
  required Directory newThumbDir,
  required Directory newMeshDir,
}) async {
  final migrations = _legacyDirectories();

  final newDbFile = File(p.join(newDataDir.path, 'freecad_explorer.db'));
  if (!await newDbFile.exists()) {
    for (final migration in migrations) {
      final legacyDb = File(p.join(migration.dataDir.path, 'freecad_explorer.db'));
      if (await legacyDb.exists()) {
        await newDataDir.create(recursive: true);
        await legacyDb.copy(newDbFile.path);
        break;
      }
    }
  }

  if (!await newThumbDir.exists()) {
    for (final migration in migrations) {
      final legacyThumbs = Directory(p.join(migration.cacheDir.path, 'thumbnails'));
      if (await legacyThumbs.exists()) {
        await _copyDirectory(legacyThumbs, newThumbDir);
        break;
      }
    }
  }

  if (!await newMeshDir.exists()) {
    for (final migration in migrations) {
      final legacyMeshes = Directory(p.join(migration.cacheDir.path, 'meshes'));
      if (await legacyMeshes.exists()) {
        await _copyDirectory(legacyMeshes, newMeshDir);
        break;
      }
    }
  }
}

class _LegacyDirectory {
  _LegacyDirectory({required this.dataDir, required this.cacheDir});

  final Directory dataDir;
  final Directory cacheDir;
}

List<_LegacyDirectory> _legacyDirectories() {
  final dirs = <_LegacyDirectory>[];
  final home = Platform.environment['HOME'];
  if (Platform.isLinux && home != null) {
    dirs.addAll([
      _LegacyDirectory(
        dataDir: Directory(p.join(home, '.local', 'share', 'com.example.freecad_navigator')),
        cacheDir: Directory(p.join(home, '.cache', 'com.example.freecad_navigator')),
      ),
      _LegacyDirectory(
        dataDir: Directory(p.join(home, '.local', 'share', 'com.example.freecadNavigator')),
        cacheDir: Directory(p.join(home, '.cache', 'com.example.freecadNavigator')),
      ),
      _LegacyDirectory(
        dataDir: Directory(p.join(home, '.local', 'share', 'freecad_navigator')),
        cacheDir: Directory(p.join(home, '.cache', 'freecad_navigator')),
      ),
    ]);
  } else if (Platform.isMacOS && home != null) {
    dirs.addAll([
      _LegacyDirectory(
        dataDir: Directory(p.join(home, 'Library', 'Application Support', 'com.example.freecadNavigator')),
        cacheDir: Directory(p.join(home, 'Library', 'Caches', 'com.example.freecadNavigator')),
      ),
      _LegacyDirectory(
        dataDir: Directory(p.join(home, 'Library', 'Application Support', 'com.example.freecad_navigator')),
        cacheDir: Directory(p.join(home, 'Library', 'Caches', 'com.example.freecad_navigator')),
      ),
      _LegacyDirectory(
        dataDir: Directory(p.join(home, 'Library', 'Application Support', 'freecad_navigator')),
        cacheDir: Directory(p.join(home, 'Library', 'Caches', 'freecad_navigator')),
      ),
    ]);
  } else if (Platform.isWindows) {
    final appData = Platform.environment['APPDATA'];
    final localAppData = Platform.environment['LOCALAPPDATA'];
    if (appData != null && localAppData != null) {
      dirs.addAll([
        _LegacyDirectory(
          dataDir: Directory(p.join(appData, 'com.example.freecad_navigator')),
          cacheDir: Directory(p.join(localAppData, 'com.example.freecad_navigator')),
        ),
        _LegacyDirectory(
          dataDir: Directory(p.join(appData, 'com.example.freecadNavigator')),
          cacheDir: Directory(p.join(localAppData, 'com.example.freecadNavigator')),
        ),
        _LegacyDirectory(
          dataDir: Directory(p.join(appData, 'freecad_navigator')),
          cacheDir: Directory(p.join(localAppData, 'freecad_navigator')),
        ),
      ]);
    }
  }
  return dirs;
}

Future<void> _copyDirectory(Directory source, Directory destination) async {
  if (!await source.exists()) {
    return;
  }
  await destination.create(recursive: true);
  await for (final entity in source.list(recursive: false)) {
    if (entity is File) {
      final newFile = File(p.join(destination.path, p.basename(entity.path)));
      await newFile.parent.create(recursive: true);
      await entity.copy(newFile.path);
    } else if (entity is Directory) {
      final newSubdir = Directory(p.join(destination.path, p.basename(entity.path)));
      await _copyDirectory(entity, newSubdir);
    }
  }
}
