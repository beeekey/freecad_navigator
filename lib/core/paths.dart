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
