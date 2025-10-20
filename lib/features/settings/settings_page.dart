import 'dart:io';

import 'package:collection/collection.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/platform.dart';
import '../../core/window_size_prefs.dart';
import '../../models/settings_model.dart';
import 'settings_controller.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final _freecadController = TextEditingController();
  bool _isDetecting = false;

  @override
  void dispose() {
    _freecadController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(settingsControllerProvider);

    final freecadPath = settingsAsync.maybeWhen(
      data: (settings) => settings.freecadExecutable ?? '',
      orElse: () => '',
    );

    if (_freecadController.text != freecadPath) {
      _freecadController.text = freecadPath;
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/FreeCadExplorer_Logo.png',
              height: 32,
            ),
            const SizedBox(width: 8),
            const Text('Settings'),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Failed to load settings: $error'),
          ),
        ),
        data: (settings) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: ListView(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Project roots',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    'Browse to add one or more directories containing FreeCAD projects (.FCStd files).',
                  ),
                  trailing: FilledButton.icon(
                    icon: const Icon(Icons.add),
                label: const Text('Add'),
                    onPressed: () => _addProjectRoot(context),
                  ),
                ),
                const SizedBox(height: 12),
                if (settings.projectRoots.isEmpty)
                  const ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('No project roots added yet.'),
                  )
                else
                  ...settings.projectRoots.map(
                    (root) => _ProjectRootTile(root: root),
                  ),
                const SizedBox(height: 24),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Default libraries',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    'Register library folders that you want quick access to from the browser sidebar.',
                  ),
                  trailing: FilledButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Add'),
                    onPressed: () => _addDefaultLibrary(context),
                  ),
                ),
                const SizedBox(height: 12),
                if (settings.defaultLibraries.isEmpty)
                  const ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('No default libraries yet.'),
                  )
                else
                  ...settings.defaultLibraries.map(
                    (root) => _LibraryTile(root: root),
                  ),
                const SizedBox(height: 24),
                const Text(
                  'Theme',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                SegmentedButton<ThemePreference>(
                  segments: ThemePreference.values
                      .map(
                        (pref) => ButtonSegment<ThemePreference>(
                          value: pref,
                          label: Text(pref.label),
                        ),
                      )
                      .toList(),
                  selected: {settings.themePreference},
                  onSelectionChanged: (selection) {
                    if (selection.isNotEmpty) {
                      ref
                          .read(settingsControllerProvider.notifier)
                          .updateThemePreference(selection.first);
                    }
                  },
                ),
                const SizedBox(height: 24),
                const Text(
                  'Startup window size',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                InputDecorator(
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Window size',
                  ),
                  child: DropdownButton<WindowSizePreference>(
                    value: settings.windowSizePreference,
                    isExpanded: true,
                    underline: const SizedBox.shrink(),
                    items: WindowSizePreference.values
                        .map(
                          (pref) => DropdownMenuItem(
                            value: pref,
                            child: Text(pref.label),
                          ),
                        )
                        .toList(),
                    onChanged: (value) async {
                      if (value == null) return;
                      await ref
                          .read(settingsControllerProvider.notifier)
                          .updateWindowSizePreference(value);
                      await applyWindowSizePreference(value);
                    },
                  ),
                ),
                const SizedBox(height: 24),
                const Divider(height: 32),
                const Text(
                  'FreeCAD executable',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _freecadController,
                  decoration: InputDecoration(
                    labelText: 'Executable path',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.folder_open),
                      onPressed: () => _pickFreecadExecutable(context),
                    ),
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    ref
                        .read(settingsControllerProvider.notifier)
                        .updateFreecadExecutable(value.trim().isEmpty ? null : value.trim());
                  },
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  icon: _isDetecting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.search),
                  label: Text(_isDetecting ? 'Detecting…' : 'Auto-detect FreeCAD'),
                  onPressed: _isDetecting ? null : () => _detectFreecad(context),
                ),
                const SizedBox(height: 12),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Force headless previews'),
                  subtitle: const Text(
                    'Always wrap FreeCAD in a virtual display (xvfb-run) even when a desktop session is available.',
                  ),
                  value: settings.forceHeadlessPreviews,
                  onChanged: (value) => ref
                      .read(settingsControllerProvider.notifier)
                      .updateForceHeadlessPreviews(value),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _addProjectRoot(BuildContext context) async {
    final path = await FilePicker.platform.getDirectoryPath(dialogTitle: 'Select project root');
    if (path == null) return;

    final dir = Directory(path);
    if (!await dir.exists()) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Directory not found: $path')),
      );
      return;
    }

    await ref.read(settingsControllerProvider.notifier).addProjectRoot(dir.path);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Added project root: ${dir.path}')),
    );
  }

  Future<void> _addDefaultLibrary(BuildContext context) async {
    final path =
        await FilePicker.platform.getDirectoryPath(dialogTitle: 'Select default library');
    if (path == null) return;

    final dir = Directory(path);
    if (!await dir.exists()) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Directory not found: $path')),
      );
      return;
    }

    await ref.read(settingsControllerProvider.notifier).addDefaultLibrary(dir.path);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Added default library: ${dir.path}')),
    );
  }

  Future<void> _pickFreecadExecutable(BuildContext context) async {
    final isWindows = Platform.isWindows;
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Select FreeCAD executable',
      type: isWindows ? FileType.custom : FileType.any,
      allowedExtensions: isWindows ? const ['exe'] : null,
      allowMultiple: false,
      withData: false,
    );
    final path = result?.files.singleOrNull?.path;
    if (path == null) return;

    _freecadController.text = path;
    await ref.read(settingsControllerProvider.notifier).updateFreecadExecutable(path);
  }

  Future<void> _detectFreecad(BuildContext context) async {
    setState(() => _isDetecting = true);
    try {
      final detected = await detectFreecadExecutable();
      if (detected == null) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not find FreeCAD. Please set the path manually.')),
        );
        return;
      }
      _freecadController.text = detected;
      await ref.read(settingsControllerProvider.notifier).updateFreecadExecutable(detected);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Detected FreeCAD at $detected')),
      );
    } finally {
      if (mounted) {
        setState(() => _isDetecting = false);
      }
    }
  }
}

class _ProjectRootTile extends ConsumerWidget {
  const _ProjectRootTile({required this.root});

  final ProjectRoot root;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(settingsControllerProvider.notifier);
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        title: Text(root.label?.isNotEmpty == true ? root.label! : root.path),
        subtitle: root.label?.isNotEmpty == true ? Text(root.path) : null,
        trailing: Wrap(
          spacing: 8,
          children: [
            IconButton(
              tooltip: 'Rename',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => _rename(context, controller),
            ),
            IconButton(
              tooltip: 'Remove',
              icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
              onPressed: () => controller.removeProjectRoot(root.path),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _rename(
    BuildContext context,
    SettingsController controller,
  ) async {
    final labelController = TextEditingController(text: root.label ?? '');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Rename project'),
          content: TextField(
            controller: labelController,
            decoration: const InputDecoration(labelText: 'Display name'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
    if (confirmed == true) {
      await controller.renameProjectRoot(
        root.path,
        labelController.text.trim().isEmpty ? null : labelController.text.trim(),
      );
    }
  }
}

class _LibraryTile extends ConsumerWidget {
  const _LibraryTile({required this.root});

  final ProjectRoot root;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(settingsControllerProvider.notifier);
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        title: Text(root.label?.isNotEmpty == true ? root.label! : root.path),
        subtitle: root.label?.isNotEmpty == true ? Text(root.path) : null,
        trailing: Wrap(
          spacing: 8,
          children: [
            IconButton(
              tooltip: 'Rename',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => _rename(context, controller),
            ),
            IconButton(
              tooltip: 'Remove',
              icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
              onPressed: () => controller.removeDefaultLibrary(root.path),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _rename(
    BuildContext context,
    SettingsController controller,
  ) async {
    final labelController = TextEditingController(text: root.label ?? '');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Rename default library'),
          content: TextField(
            controller: labelController,
            decoration: const InputDecoration(labelText: 'Display name'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
    if (confirmed == true) {
      await controller.renameDefaultLibrary(
        root.path,
        labelController.text.trim().isEmpty ? null : labelController.text.trim(),
      );
    }
  }
}
