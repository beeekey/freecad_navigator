import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_cube/flutter_cube.dart';
import 'package:path/path.dart' as p;

import '../../core/db.dart';
import '../../core/mesh_generator.dart' show meshCachePath;
import '../../core/metadata_repository.dart';
import '../../core/platform.dart';
import '../../core/paths.dart';
import '../../models/file_record.dart';
import '../../models/settings_model.dart';
import '../settings/settings_controller.dart';
import 'browser_controller.dart';
import 'browser_providers.dart';

class DetailsPanel extends ConsumerStatefulWidget {
  const DetailsPanel({
    required this.projectRoot,
    required this.selectedFileIds,
    super.key,
  });

  final String projectRoot;
  final Set<int> selectedFileIds;

  @override
  ConsumerState<DetailsPanel> createState() => _DetailsPanelState();
}

class _DetailsPanelState extends ConsumerState<DetailsPanel> {
  final _titleController = TextEditingController();
  final _tagsController = TextEditingController();
  final _statusController = TextEditingController();
  final _notesController = TextEditingController();
  final _labelController = TextEditingController();
  final _companyController = TextEditingController();
  final _createdByController = TextEditingController();
  final _commentController = TextEditingController();

  final _batchTagsController = TextEditingController();
  final _batchStatusController = TextEditingController();

  bool _applyBatchTags = true;
  bool _applyBatchStatus = true;
  bool _dirty = false;
  bool _isSaving = false;
  bool _isBatchSaving = false;
  String? _lastHydratedSignature;

  @override
  void dispose() {
    _titleController.dispose();
    _tagsController.dispose();
    _statusController.dispose();
    _notesController.dispose();
    _labelController.dispose();
    _companyController.dispose();
    _createdByController.dispose();
    _commentController.dispose();
    _batchTagsController.dispose();
    _batchStatusController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.selectedFileIds.isEmpty) {
      return _EmptySelection(projectRoot: widget.projectRoot);
    }

    if (widget.selectedFileIds.length > 1) {
      return _buildBatchEditor(context);
    }

    final fileId = widget.selectedFileIds.first;
    final fileAsync = ref.watch(fileByIdProvider(fileId));

    return fileAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text('Failed to load file metadata: $error'),
        ),
      ),
      data: (record) {
        if (record == null) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('File metadata not found. The file may have been removed.'),
            ),
          );
        }

        _hydrateControllers(record);
        return _buildSingleEditor(context, record);
      },
    );
  }

  Widget _buildSingleEditor(BuildContext context, FileRecord record) {
    final settings = ref.watch(settingsControllerProvider).maybeWhen(
          data: (value) => value,
          orElse: () => SettingsState.empty(),
        );
    final appDirs = ref.watch(appDirectoriesProvider).maybeWhen(
          data: (value) => value,
          orElse: () => null,
        );
    final meshDir = appDirs?.meshCacheDir;
    final meshFilePath = meshDir != null ? meshCachePath(meshDir, record.path) : null;
    final meshExists = meshFilePath != null && File(meshFilePath).existsSync();
    final meshPathForViewer = meshExists ? meshFilePath : null;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            record.filename,
            style: Theme.of(context).textTheme.titleMedium,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            p.join(record.projectRoot, record.folder),
            style: Theme.of(context).textTheme.bodySmall,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Form(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _EditableField(
                      label: 'Title',
                      controller: _titleController,
                      onChanged: _markDirty,
                    ),
                    const SizedBox(height: 12),
                    _EditableField(
                      label: 'Label',
                      controller: _labelController,
                      onChanged: _markDirty,
                    ),
                    const SizedBox(height: 12),
                    _EditableField(
                      label: 'Tags',
                      controller: _tagsController,
                      hint: 'Comma separated',
                      onChanged: _markDirty,
                    ),
                    const SizedBox(height: 12),
                    _EditableField(
                      label: 'Status',
                      controller: _statusController,
                      onChanged: _markDirty,
                    ),
                    const SizedBox(height: 12),
                    _EditableField(
                      label: 'Company',
                      controller: _companyController,
                      onChanged: _markDirty,
                    ),
                    const SizedBox(height: 12),
                    _EditableField(
                      label: 'Created By',
                      controller: _createdByController,
                      onChanged: _markDirty,
                    ),
                    const SizedBox(height: 12),
                    _EditableField(
                      label: 'Notes',
                      controller: _notesController,
                      maxLines: 5,
                      onChanged: _markDirty,
                    ),
                    const SizedBox(height: 12),
                    _EditableField(
                      label: 'Comment',
                      controller: _commentController,
                      maxLines: 3,
                      onChanged: _markDirty,
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        // Preview/mesh generation actions temporarily disabled until FreeCAD CLI rendering is stable.
                        FilledButton.icon(
                          icon: _isSaving
                              ? const SizedBox(
                                  height: 16,
                                  width: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.save_outlined),
                          label: Text(_isSaving ? 'Saving…' : 'Save'),
                          onPressed: _isSaving || !_dirty
                              ? null
                              : () => _saveSingle(context, record),
                        ),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.undo),
                          label: const Text('Revert'),
                          onPressed: _dirty ? () => _hydrateControllers(record, force: true) : null,
                        ),
                      ],
                    ),
                    if (meshPathForViewer != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: SizedBox(
                          height: 260,
                          child: _MeshViewerSection(
                            meshPath: meshPathForViewer,
                            key: ValueKey('mesh-${record.id}-${record.mtime}'),
                          ),
                        ),
                      ),
                    const SizedBox(height: 24),
                    Text(
                      'Metadata',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    _MetadataList(record: record),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Open in FreeCAD'),
                  onPressed: settings.freecadExecutable == null
                      ? null
                      : () => _openInFreecad(context, record, settings.freecadExecutable!),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.folder_open),
                  label: const Text('Show in Explorer'),
                  onPressed: () => _revealInExplorer(context, record),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBatchEditor(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${widget.selectedFileIds.length} files selected',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          const Text(
            'Update Tags and Status across the selected files. Leave a field empty to clear it.',
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: _applyBatchTags,
                onChanged: (value) {
                  setState(() => _applyBatchTags = value ?? false);
                },
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Update Tags'),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _batchTagsController,
                      decoration: const InputDecoration(
                        labelText: 'Tags',
                        hintText: 'Comma separated',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: _applyBatchStatus,
                onChanged: (value) {
                  setState(() => _applyBatchStatus = value ?? false);
                },
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Update Status'),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _batchStatusController,
                      decoration: const InputDecoration(
                        labelText: 'Status',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Spacer(),
          FilledButton.icon(
            icon: _isBatchSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(
              _isBatchSaving
                  ? 'Applying…'
                  : 'Apply to ${widget.selectedFileIds.length} files',
            ),
            onPressed: _isBatchSaving || (!_applyBatchTags && !_applyBatchStatus)
                ? null
                : () => _applyBatch(context),
          ),
        ],
      ),
    );
  }

  void _markDirty() {
    if (!_dirty) {
      setState(() => _dirty = true);
    }
  }

  void _hydrateControllers(FileRecord record, {bool force = false}) {
    final signature = _buildHydrationSignature(record);
    if (!force && _lastHydratedSignature == signature) {
      return;
    }
    final title = record.sidecarMeta['Title']?.trim().isNotEmpty == true
        ? record.sidecarMeta['Title']!.trim()
        : record.builtinMeta['Title']?.trim() ?? record.displayTitle;
    final tags = record.sidecarMeta['Tags'] ?? '';
    final status = record.sidecarMeta['Status'] ?? '';
    final notes = record.sidecarMeta['Notes'] ?? '';
    final label = _firstNonEmpty([
      record.sidecarMeta['Label'],
      record.builtinMeta['Label'],
    ]);
    final company = _firstNonEmpty([
      record.sidecarMeta['Company'],
      record.builtinMeta['Company'],
    ]);
    final createdBy = _firstNonEmpty([
      record.sidecarMeta['CreatedBy'],
      record.builtinMeta['CreatedBy'],
    ]);
    final comment = record.sidecarMeta['Comment'] ?? record.builtinMeta['Comment'] ?? '';

    _titleController
      ..text = title
      ..selection = TextSelection.collapsed(offset: title.length);
    _tagsController
      ..text = tags
      ..selection = TextSelection.collapsed(offset: tags.length);
    _statusController
      ..text = status
      ..selection = TextSelection.collapsed(offset: status.length);
    _notesController
      ..text = notes
      ..selection = TextSelection.collapsed(offset: notes.length);
    _labelController
      ..text = label
      ..selection = TextSelection.collapsed(offset: label.length);
    _companyController
      ..text = company
      ..selection = TextSelection.collapsed(offset: company.length);
    _createdByController
      ..text = createdBy
      ..selection = TextSelection.collapsed(offset: createdBy.length);
    _commentController
      ..text = comment
      ..selection = TextSelection.collapsed(offset: comment.length);

    _lastHydratedSignature = signature;
    _dirty = false;
  }

  String _buildHydrationSignature(FileRecord record) {
    return '${record.id}-${record.mtime}-${record.lastIndexed}-${record.sidecarMeta}-${record.builtinMeta}';
  }

  String _firstNonEmpty(List<String?> values) {
    for (final value in values) {
      if (value != null && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return '';
  }

  Future<void> _saveSingle(BuildContext context, FileRecord record) async {
    setState(() {
      _isSaving = true;
    });

    try {
      final db = await ref.read(databaseProvider.future);
      final repo = MetadataRepository(db);
      await repo.saveSidecar(
        fileId: record.id,
        filePath: record.path,
        values: {
          'Title': _titleController.text,
          'Label': _labelController.text,
          'Tags': _tagsController.text,
          'Status': _statusController.text,
          'Notes': _notesController.text,
          'Company': _companyController.text,
          'CreatedBy': _createdByController.text,
          'Comment': _commentController.text,
        },
      );

      final browserState = ref.read(browserControllerProvider);
      final search = browserState.searchQuery;
      final activeFolder = browserState.activeFolder;
      final includeSubfolders = browserState.includeSubfolders;
      final sort = browserState.sort;
      ref.invalidate(fileByIdProvider(record.id));
      ref.invalidate(
        filesInFolderProvider(
          (
            projectRoot: record.projectRoot,
            folder: activeFolder,
            search: search,
            includeSubfolders: includeSubfolders,
            sort: sort,
          ),
        ),
      );

      if (!context.mounted) return;
      setState(() {
        _dirty = false;
        _isSaving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Metadata saved to sidecar.')),
      );
    } catch (error) {
      if (!context.mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save metadata: $error')),
      );
    }
  }

  Future<void> _applyBatch(BuildContext context) async {
    setState(() => _isBatchSaving = true);
    try {
      final db = await ref.read(databaseProvider.future);
      final repo = MetadataRepository(db);
      final futures = <Future<void>>[];

      for (final fileId in widget.selectedFileIds) {
        futures.add(
          _applyToFile(repo, fileId),
        );
      }
      await Future.wait(futures);

      final browserState = ref.read(browserControllerProvider);
      final search = browserState.searchQuery;
      final includeSubfolders = browserState.includeSubfolders;
      final sort = browserState.sort;
      final currentProject = ref
          .read(settingsControllerProvider)
          .maybeWhen(data: (value) => value.activeProjectPath, orElse: () => null);
      final folder = browserState.activeFolder;
      if (currentProject != null) {
        ref.invalidate(
          filesInFolderProvider((
            projectRoot: currentProject,
            folder: folder,
            search: search,
            includeSubfolders: includeSubfolders,
            sort: sort,
          )),
        );
      }

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Updated ${widget.selectedFileIds.length} files.')),
      );
      setState(() => _isBatchSaving = false);
    } catch (error) {
      if (!context.mounted) return;
      setState(() => _isBatchSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Batch update failed: $error')),
      );
    }
  }

  Future<void> _applyToFile(MetadataRepository repo, int fileId) async {
    final record = await ref.read(fileByIdProvider(fileId).future);
    if (record == null) return;

    final values = <String, String>{
      'Title': record.sidecarMeta['Title'] ?? record.title ?? '',
      'Label': record.sidecarMeta['Label'] ?? record.builtinMeta['Label'] ?? '',
      'Tags': record.sidecarMeta['Tags'] ?? '',
      'Status': record.sidecarMeta['Status'] ?? '',
      'Notes': record.sidecarMeta['Notes'] ?? '',
      'Company': record.sidecarMeta['Company'] ?? record.builtinMeta['Company'] ?? '',
      'CreatedBy': record.sidecarMeta['CreatedBy'] ?? record.builtinMeta['CreatedBy'] ?? '',
      'Comment': record.sidecarMeta['Comment'] ?? record.builtinMeta['Comment'] ?? '',
    };

    if (_applyBatchTags) {
      values['Tags'] = _batchTagsController.text;
    }
    if (_applyBatchStatus) {
      values['Status'] = _batchStatusController.text;
    }

    await repo.saveSidecar(
      fileId: record.id,
      filePath: record.path,
      values: values,
    );

    ref.invalidate(fileByIdProvider(record.id));
  }

  Future<void> _openInFreecad(
    BuildContext context,
    FileRecord record,
    String executable,
  ) async {
    try {
      await openInFreecad(
        executable: executable,
        files: [record.path],
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to launch FreeCAD: $error')),
      );
    }
  }

  Future<void> _revealInExplorer(BuildContext context, FileRecord record) async {
    try {
      await revealInFileExplorer(record.path);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to reveal file: $error')),
      );
    }
  }
}

class _EditableField extends StatelessWidget {
  const _EditableField({
    required this.label,
    required this.controller,
    required this.onChanged,
    this.hint,
    this.maxLines = 1,
  });

  final String label;
  final String? hint;
  final TextEditingController controller;
  final int maxLines;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      minLines: 1,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
      ),
      onChanged: (_) => onChanged(),
    );
  }
}

class _MetadataList extends StatelessWidget {
  const _MetadataList({required this.record});

  final FileRecord record;

  @override
  Widget build(BuildContext context) {
    final entries = <MapEntry<String, String>>[];
    entries.addAll(record.builtinMeta.entries);
    for (final entry in record.sidecarMeta.entries) {
      if (!entries.any((existing) => existing.key == entry.key)) {
        entries.add(entry);
      }
    }

    if (entries.isEmpty) {
      return const Text('No metadata available.');
    }

    return Column(
      children: entries.map((entry) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 120,
                child: Text(
                  entry.key,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              Expanded(
                child: Text(entry.value),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _MeshViewerSection extends StatefulWidget {
  const _MeshViewerSection({required this.meshPath, super.key});

  final String meshPath;

  @override
  State<_MeshViewerSection> createState() => _MeshViewerSectionState();
}

class _MeshViewerSectionState extends State<_MeshViewerSection> {
  bool _loaded = false;

  @override
  void didUpdateWidget(covariant _MeshViewerSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.meshPath != widget.meshPath) {
      _loaded = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final file = File(widget.meshPath);
    if (!file.existsSync()) {
      return Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: const Text('3D mesh not available.'),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Cube(
            onSceneCreated: (scene) {
              scene.world.add(
                Object(
                  fileName: widget.meshPath,
                  isAsset: false,
                  backfaceCulling: false,
                  lighting: true,
                ),
              );
              scene.camera.zoom = 1.2;
              scene.camera.position.setValues(0, 0, 3);
            },
            onObjectCreated: (_) {
              if (mounted) {
                setState(() {
                  _loaded = true;
                });
              }
            },
          ),
          if (!_loaded)
            Container(
              color: Colors.black12,
              alignment: Alignment.center,
              child: const CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }
}

class _EmptySelection extends StatelessWidget {
  const _EmptySelection({required this.projectRoot});

  final String projectRoot;

  @override
  Widget build(BuildContext context) {
    if (projectRoot.isEmpty) {
      return const Center(
        child: Text('Select a project from the sidebar to begin.'),
      );
    }
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.info_outline, size: 48, color: Colors.grey),
          const SizedBox(height: 12),
          const Text('Select a file to view metadata'),
        ],
      ),
    );
  }
}
