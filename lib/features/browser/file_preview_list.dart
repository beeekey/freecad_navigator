import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/file_record.dart';
import 'browser_controller.dart';
import 'browser_providers.dart';

class FilePreviewList extends ConsumerWidget {
  const FilePreviewList({
    required this.projectRoot,
    required this.folder,
    required this.includeSubfolders,
    required this.sort,
    required this.selection,
    required this.onTap,
    required this.onOpen,
    super.key,
  });

  final String projectRoot;
  final String folder;
  final bool includeSubfolders;
  final BrowserSort sort;
  final Set<int> selection;
  final void Function(FileRecord) onTap;
  final void Function(FileRecord) onOpen;

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
          padding: const EdgeInsets.all(12),
          child: Text('Failed to load list: $error'),
        ),
      ),
      data: (files) {
        if (files.isEmpty) {
          return const Center(child: Text('No files'));
        }
        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 12),
          itemCount: files.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final file = files[index];
            final isSelected = selection.contains(file.id);
            return ListTile(
              dense: true,
              selected: isSelected,
              selectedTileColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
              leading: _ThumbnailAvatar(path: file.thumbPath),
              title: Text(
                file.filename,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                _formatModified(file.mtime),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () => onTap(file),
              onLongPress: () => onOpen(file),
            );
          },
        );
      },
    );
  }
}

class _ThumbnailAvatar extends StatelessWidget {
  const _ThumbnailAvatar({this.path});

  final String? path;

  @override
  Widget build(BuildContext context) {
    if (path == null) {
      return const CircleAvatar(
        radius: 18,
        child: Icon(Icons.insert_drive_file, size: 18),
      );
    }
    final file = File(path!);
    if (!file.existsSync()) {
      return const CircleAvatar(
        radius: 18,
        child: Icon(Icons.insert_drive_file, size: 18),
      );
    }
    return CircleAvatar(
      radius: 18,
      backgroundImage: FileImage(file),
    );
  }
}

String _formatModified(int mtime) {
  final dt = DateTime.fromMillisecondsSinceEpoch(mtime);
  String twoDigits(int value) => value.toString().padLeft(2, '0');
  return '${dt.year}-${twoDigits(dt.month)}-${twoDigits(dt.day)} ${twoDigits(dt.hour)}:${twoDigits(dt.minute)}';
}
