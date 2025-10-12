import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:xml/xml.dart';

class FileIndexResult {
  FileIndexResult({
    required this.path,
    required this.size,
    required this.mtimeMs,
    required this.thumbnailPath,
    required this.metadata,
  });

  final String path;
  final int size;
  final int mtimeMs;
  final String? thumbnailPath;
  final Map<String, String> metadata;

  bool get hasThumbnail => thumbnailPath != null;
}

Future<FileIndexResult> parseFcstdFile({
  required String filePath,
  required String thumbnailCacheDir,
}) async {
  final file = File(filePath);
  final stat = await file.stat();
  final bytes = await file.readAsBytes();
  final archive = ZipDecoder().decodeBytes(bytes, verify: false);

  final metadata = <String, String>{};
  final docEntry = archive.findFile('Document.xml');
  if (docEntry != null) {
    final xml = utf8.decode(docEntry.content as List<int>);
    metadata.addAll(_parseMetadata(xml));
  }

  String? thumbnailPath;
  final thumbEntry = archive.findFile('thumbnails/Thumbnail.png') ??
      archive.findFile('thumbnails/thumbnail.png');
  if (thumbEntry != null) {
    final hash = sha1.convert(utf8.encode(filePath)).toString();
    final thumbFile = File(p.join(thumbnailCacheDir, '$hash.png'));
    await thumbFile.writeAsBytes(thumbEntry.content as List<int>);
    thumbnailPath = thumbFile.path;
  }

  return FileIndexResult(
    path: filePath,
    size: stat.size,
    mtimeMs: stat.modified.millisecondsSinceEpoch,
    thumbnailPath: thumbnailPath,
    metadata: metadata,
  );
}

Map<String, String> _parseMetadata(String xmlString) {
  final doc = XmlDocument.parse(xmlString);
  final props = <String, String>{};

  final propertyNodes = doc.findAllElements('Property');
  for (final property in propertyNodes) {
    final name = property.getAttribute('name');
    if (name == null) continue;
    final normalized = _normalizeKey(name);
    if (normalized == null) continue;
    final value = _extractValue(property);
    if (value != null && value.trim().isNotEmpty) {
      props[normalized] = value.trim();
    }
  }

  return props;
}

String? _normalizeKey(String source) {
  switch (source) {
    case 'Label':
      return 'Label';
    case 'Title':
      return 'Title';
    case 'Comment':
      return 'Comment';
    case 'Company':
      return 'Company';
    case 'CreatedBy':
      return 'CreatedBy';
    case 'CreationDate':
      return 'CreationDate';
    case 'LastModifiedBy':
      return 'LastModifiedBy';
    case 'LastModifiedDate':
      return 'LastModifiedDate';
    case 'FreeCADVersion':
      return 'FreeCADVersion';
    default:
      return null;
  }
}

String? _extractValue(XmlElement property) {
  for (final child in property.children.whereType<XmlElement>()) {
    final valueAttr = child.getAttribute('value');
    if (valueAttr != null && valueAttr.isNotEmpty) {
      return valueAttr;
    }
    final inner = child.innerText;
    if (inner.isNotEmpty) {
      return inner;
    }
  }
  return null;
}
