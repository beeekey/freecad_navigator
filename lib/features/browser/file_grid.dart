import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:transparent_image/transparent_image.dart';

import '../../models/file_record.dart';
import 'browser_controller.dart';
import 'browser_providers.dart';

class FileGrid extends ConsumerWidget {
  const FileGrid({
    required this.projectRoot,
    required this.folder,
    required this.includeSubfolders,
    required this.selection,
    required this.onOpenFile,
    required this.sort,
    super.key,
  });

  final String projectRoot;
  final String folder;
  final bool includeSubfolders;
  final Set<int> selection;
  final void Function(FileRecord) onOpenFile;
  final BrowserSort sort;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchQuery = ref.watch(browserControllerProvider).searchQuery;
    final filesAsync = ref.watch(
      filesInFolderProvider(
        (
          projectRoot: projectRoot,
          folder: folder,
          search: searchQuery,
          includeSubfolders: includeSubfolders,
          sort: sort,
        ),
      ),
    );

    return filesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Failed to load files: $error'),
        ),
      ),
      data: (files) {
        if (files.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                _emptyMessage(folder, includeSubfolders),
              ),
            ),
          );
        }

        return Column(
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final crossAxisCount = _computeCrossAxisCount(constraints.maxWidth);
                  return GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 1.1,
                    ),
                    itemCount: files.length,
                    itemBuilder: (context, index) {
                      final file = files[index];
                      final isSelected = selection.contains(file.id);
                      return _FileCard(
                        file: file,
                        isSelected: isSelected,
                        onTap: () => _handleTap(ref, file),
                        onDoubleTap: () => onOpenFile(file),
                      );
                    },
                  );
                },
              ),
            ),
            _GridFooter(
              total: files.length,
              selected: selection.length,
            ),
          ],
        );
      },
    );
  }

  int _computeCrossAxisCount(double maxWidth) {
    if (maxWidth <= 600) return 2;
    if (maxWidth <= 900) return 3;
    if (maxWidth <= 1200) return 4;
    return 5;
  }

  void _handleTap(WidgetRef ref, FileRecord record) {
    final pressed = HardwareKeyboard.instance.logicalKeysPressed;
    final multiSelect = pressed.contains(LogicalKeyboardKey.controlLeft) ||
        pressed.contains(LogicalKeyboardKey.controlRight) ||
        pressed.contains(LogicalKeyboardKey.metaLeft) ||
        pressed.contains(LogicalKeyboardKey.metaRight) ||
        pressed.contains(LogicalKeyboardKey.shiftLeft) ||
        pressed.contains(LogicalKeyboardKey.shiftRight);

    ref.read(browserControllerProvider.notifier).toggleSelection(
          record,
          multiSelect: multiSelect,
        );
  }
}

class _FileCard extends StatelessWidget {
  const _FileCard({
    required this.file,
    required this.isSelected,
    required this.onTap,
    required this.onDoubleTap,
  });

  final FileRecord file;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;

  @override
  Widget build(BuildContext context) {
    final borderColor = isSelected
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).dividerColor.withValues(alpha: 0.4);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onDoubleTap: onDoubleTap,
        child: Ink(
          decoration: BoxDecoration(
            border: Border.all(color: borderColor, width: isSelected ? 2 : 1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _Thumbnail(path: file.thumbPath),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      file.filename,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    if (_hasSecondaryLabel(file)) ...[
                      const SizedBox(height: 4),
                      Text(
                        file.displayTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      '${_formatModified(file.mtime)} · ${_formatSize(file.size)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

bool _hasSecondaryLabel(FileRecord file) {
  final secondary = file.displayTitle.trim();
  if (secondary.isEmpty) {
    return false;
  }
  return secondary.toLowerCase() != file.filename.toLowerCase();
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({this.path});

  final String? path;

  @override
  Widget build(BuildContext context) {
    if (path == null) {
      return Container(
        color: Colors.grey.shade200,
        child: const Center(
          child: Icon(Icons.image_not_supported_outlined, size: 48),
        ),
      );
    }

    final file = File(path!);
    if (!file.existsSync()) {
      return Container(
        color: Colors.grey.shade100,
        child: const Center(
          child: Icon(Icons.image_outlined, size: 48),
        ),
      );
    }

    return FadeInImage(
      image: FileImage(file),
      placeholder: MemoryImage(kTransparentImage),
      fit: BoxFit.cover,
    );
  }
}

class _GridFooter extends StatelessWidget {
  const _GridFooter({
    required this.total,
    required this.selected,
  });

  final int total;
  final int selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Text(
        selected > 0
            ? '$selected selected · $total total'
            : '$total item${total == 1 ? '' : 's'}',
      ),
    );
  }
}

String _formatModified(int mtime) {
  final dt = DateTime.fromMillisecondsSinceEpoch(mtime);
  String twoDigits(int value) => value.toString().padLeft(2, '0');
  return '${dt.year}-${twoDigits(dt.month)}-${twoDigits(dt.day)} '
      '${twoDigits(dt.hour)}:${twoDigits(dt.minute)}';
}

String _formatSize(int bytes) {
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  return '${value.toStringAsFixed(value < 10 ? 1 : 0)} ${units[unit]}';
}

String _emptyMessage(String folder, bool includeSubfolders) {
  if (folder.isEmpty) {
    return includeSubfolders
        ? 'No .FCStd files found in this project.'
        : 'No .FCStd files in the project root folder.';
  }
  return includeSubfolders
      ? 'No .FCStd files in "$folder" or its subfolders.'
      : 'No .FCStd files in "$folder".';
}
