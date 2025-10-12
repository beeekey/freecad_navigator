import 'package:collection/collection.dart';

class FileRecord {
  FileRecord({
    required this.id,
    required this.path,
    required this.projectRoot,
    required this.folder,
    required this.filename,
    required this.ext,
    required this.mtime,
    required this.size,
    required this.hasThumbnail,
    required this.thumbPath,
    required this.title,
    required this.lastIndexed,
    this.builtinMeta = const {},
    this.sidecarMeta = const {},
  });

  final int id;
  final String path;
  final String projectRoot;
  final String folder;
  final String filename;
  final String ext;
  final int mtime;
  final int size;
  final bool hasThumbnail;
  final String? thumbPath;
  final String? title;
  final int lastIndexed;
  final Map<String, String> builtinMeta;
  final Map<String, String> sidecarMeta;

  String get displayTitle {
    final sidecarTitle = sidecarMeta['Title'];
    if (sidecarTitle != null && sidecarTitle.trim().isNotEmpty) {
      return sidecarTitle;
    }
    if (title != null && title!.trim().isNotEmpty) {
      return title!;
    }
    return filenameWithoutExtension;
  }

  String get filenameWithoutExtension =>
      filename.replaceFirst(RegExp(r'\.FCStd$', caseSensitive: false), '');

  FileRecord copyWith({
    int? id,
    String? path,
    String? projectRoot,
    String? folder,
    String? filename,
    String? ext,
    int? mtime,
    int? size,
    bool? hasThumbnail,
    String? thumbPath,
    String? title,
    int? lastIndexed,
    Map<String, String>? builtinMeta,
    Map<String, String>? sidecarMeta,
  }) {
    return FileRecord(
      id: id ?? this.id,
      path: path ?? this.path,
      projectRoot: projectRoot ?? this.projectRoot,
      folder: folder ?? this.folder,
      filename: filename ?? this.filename,
      ext: ext ?? this.ext,
      mtime: mtime ?? this.mtime,
      size: size ?? this.size,
      hasThumbnail: hasThumbnail ?? this.hasThumbnail,
      thumbPath: thumbPath ?? this.thumbPath,
      title: title ?? this.title,
      lastIndexed: lastIndexed ?? this.lastIndexed,
      builtinMeta: builtinMeta ?? this.builtinMeta,
      sidecarMeta: sidecarMeta ?? this.sidecarMeta,
    );
  }

  static FileRecord fromRow(
    Map<String, Object?> row, {
    Map<String, String> builtinMeta = const {},
    Map<String, String> sidecarMeta = const {},
  }) {
    return FileRecord(
      id: row['id'] as int,
      path: row['path'] as String,
      projectRoot: row['project_root'] as String,
      folder: row['folder'] as String,
      filename: row['filename'] as String,
      ext: row['ext'] as String,
      mtime: row['mtime'] as int,
      size: row['size'] as int,
      hasThumbnail: (row['has_thumbnail'] as int? ?? 0) == 1,
      thumbPath: row['thumb_path'] as String?,
      title: row['title'] as String?,
      lastIndexed: row['last_indexed'] as int,
      builtinMeta: builtinMeta,
      sidecarMeta: sidecarMeta,
    );
  }

  @override
  String toString() {
    return 'FileRecord(id: $id, path: $path)';
  }

  @override
  int get hashCode => Object.hashAll([id, path, mtime, size]);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FileRecord &&
          other.id == id &&
          other.path == path &&
          const MapEquality<String, String>().equals(other.builtinMeta, builtinMeta) &&
          const MapEquality<String, String>().equals(other.sidecarMeta, sidecarMeta);
}
