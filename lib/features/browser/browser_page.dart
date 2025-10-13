import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/indexing_service.dart';
import '../../core/platform.dart';
import '../../core/reload_signal.dart';
import '../../models/file_record.dart';
import '../settings/settings_controller.dart';
import 'browser_controller.dart';
import 'details_panel.dart';
import 'file_grid.dart';
import 'file_preview_list.dart';
import 'folder_tree.dart';
import 'search_bar.dart';
import 'package:path/path.dart' as p;

class BrowserPage extends ConsumerStatefulWidget {
  const BrowserPage({super.key});

  @override
  ConsumerState<BrowserPage> createState() => _BrowserPageState();
}

class _BrowserPageState extends ConsumerState<BrowserPage> {
  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(settingsControllerProvider);
    final indexingAsync = ref.watch(indexingControllerProvider);
    final browserState = ref.watch(browserControllerProvider);
    final reloadToken = ref.watch(filesReloadSignalProvider);
    final includeSubfolders = browserState.includeSubfolders;

    final appBarTitle = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/images/FreeCadExplorer_Logo.png',
          height: 34,
        ),
        const SizedBox(width: 8),
        const Text('FreeCAD Explorer'),
      ],
    );

    return Scaffold(
      appBar: AppBar(
        title: appBarTitle,
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => GoRouter.of(context).push('/settings'),
          ),
        ],
      ),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => _ErrorView(error: error, stackTrace: stackTrace),
        data: (settings) {
          if (!settings.hasProjects) {
            return const _EmptyState();
          }

          final indexingState = indexingAsync.valueOrNull;
          final activeRoot = settings.activeProject?.path ?? '';
          final isIndexing = indexingState?.isIndexing(activeRoot) ?? false;

          return Row(
            children: [
              SizedBox(
                width: 280,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Project',
                          border: OutlineInputBorder(),
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            dropdownColor: Theme.of(context).colorScheme.primaryContainer,
                            selectedItemBuilder: (context) {
                              final theme = Theme.of(context);
                              return settings.projectRoots.map((root) {
                                final label = root.label?.isNotEmpty == true
                                    ? root.label!
                                    : p.basename(root.path);
                                return Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    label,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                );
                              }).toList();
                            },
                            value: settings.activeProject?.path,
                            onChanged: (value) {
                              if (value != null) {
                                ref.read(settingsControllerProvider.notifier).setActiveProject(value);
                              }
                            },
                            items: settings.projectRoots
                                .map(
                                  (root) => DropdownMenuItem<String>(
                                    value: root.path,
                                    child: Text(
                                      root.label?.isNotEmpty == true
                                          ? root.label!
                                          : p.basename(root.path),
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                            icon: Icon(
                              Icons.arrow_drop_down,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                          ),
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: FolderTree(
                        projectRoot: settings.activeProject?.path ?? '',
                        activeFolder: browserState.activeFolder,
                        refreshToken: reloadToken,
                      ),
                    ),
                  ],
                ),
              ),
              const VerticalDivider(width: 1),
              Expanded(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      child: Row(
                        children: [
                          IconButton(
                            tooltip: browserState.searchExclude
                                ? 'Exclude search term'
                                : 'Include search term',
                            onPressed: browserState.searchQuery.isEmpty
                                ? null
                                : () => ref
                                    .read(browserControllerProvider.notifier)
                                    .toggleSearchExclude(),
                            color: browserState.searchExclude
                                ? Theme.of(context).colorScheme.primary
                                : null,
                            icon: Icon(
                              browserState.searchExclude
                                  ? Icons.priority_high
                                  : Icons.priority_high_outlined,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: BrowserSearchBar(
                              initialText: browserState.searchQuery,
                              onChanged: (value) => ref
                                  .read(browserControllerProvider.notifier)
                                  .updateSearchQuery(value),
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 160,
                            child: DropdownButtonFormField<BrowserSort>(
                                initialValue: browserState.sort,
                                decoration: const InputDecoration(
                                  labelText: 'Sort',
                                  isDense: true,
                                  border: OutlineInputBorder(),
                                ),
                                onChanged: (value) {
                                  if (value != null) {
                                    ref.read(browserControllerProvider.notifier).setSortOption(value);
                                  }
                                },
                                items: const [
                                  DropdownMenuItem(
                                    value: BrowserSort.nameAsc,
                                    child: Text('Name ↑'),
                                  ),
                                  DropdownMenuItem(
                                    value: BrowserSort.nameDesc,
                                    child: Text('Name ↓'),
                                  ),
                                  DropdownMenuItem(
                                    value: BrowserSort.dateDesc,
                                    child: Text('Modified ↓'),
                                  ),
                                  DropdownMenuItem(
                                    value: BrowserSort.dateAsc,
                                    child: Text('Modified ↑'),
                                  ),
                                ],
                              ),
                          ),
                          const SizedBox(width: 12),
                          ToggleButtons(
                            isSelected: [
                              browserState.viewMode == BrowserViewMode.grid,
                              browserState.viewMode == BrowserViewMode.list,
                            ],
                            onPressed: (index) {
                              final mode = index == 0
                                  ? BrowserViewMode.grid
                                  : BrowserViewMode.list;
                              ref.read(browserControllerProvider.notifier).setViewMode(mode);
                            },
                            borderRadius: BorderRadius.circular(8),
                            children: const [
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 12),
                                child: Icon(Icons.grid_view),
                              ),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 12),
                                child: Icon(Icons.view_list),
                              ),
                            ],
                          ),
                          const SizedBox(width: 12),
                          Tooltip(
                            message: includeSubfolders
                                ? 'Showing files from this folder and all subfolders'
                                : 'Showing files only from this folder',
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Switch.adaptive(
                                  value: includeSubfolders,
                                  onChanged: (value) => ref
                                      .read(browserControllerProvider.notifier)
                                      .setIncludeSubfolders(value),
                                ),
                                const SizedBox(width: 4),
                                const Text('Subfolders'),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          IconButton.filledTonal(
                            tooltip: 'Refresh index',
                            onPressed: activeRoot.isEmpty || isIndexing
                                ? null
                                : () => ref
                                    .read(indexingControllerProvider.notifier)
                                    .ensureIndexed(activeRoot),
                            icon: const Icon(Icons.refresh),
                          ),
                        ],
                      ),
                    ),
                    if (isIndexing)
                      const LinearProgressIndicator(minHeight: 2),
                    const Divider(height: 1),
                    Expanded(
                      child: browserState.viewMode == BrowserViewMode.grid
                          ? FileGrid(
                              projectRoot: settings.activeProject?.path ?? '',
                              folder: browserState.activeFolder,
                              includeSubfolders: includeSubfolders,
                              selection: browserState.selectedFileIds,
                              sort: browserState.sort,
                              searchExclude: browserState.searchExclude,
                              isIndexing: isIndexing,
                              onOpenFile: (record) => _openInFreecad(context, settings.freecadExecutable, record),
                            )
                          : FilePreviewList(
                              projectRoot: settings.activeProject?.path ?? '',
                              folder: browserState.activeFolder,
                              includeSubfolders: includeSubfolders,
                              sort: browserState.sort,
                              searchExclude: browserState.searchExclude,
                              selection: browserState.selectedFileIds,
                              isIndexing: isIndexing,
                              onTap: (record) => ref.read(browserControllerProvider.notifier).toggleSelection(record),
                              onOpen: (record) => _openInFreecad(context, settings.freecadExecutable, record),
                            ),
                    ),
                  ],
                ),
              ),
              const VerticalDivider(width: 1),
              SizedBox(
                width: 320,
                child: DetailsPanel(
                  projectRoot: settings.activeProject?.path ?? '',
                  selectedFileIds: browserState.selectedFileIds,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.folder_open, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'No project roots configured yet.',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              'Use the settings panel to add one or more FreeCAD project folders.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              icon: const Icon(Icons.settings),
              label: const Text('Open settings'),
              onPressed: () => GoRouter.of(context).push('/settings'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.stackTrace});

  final Object error;
  final StackTrace stackTrace;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Failed to load settings: $error',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }
}
  Future<void> _openInFreecad(
    BuildContext context,
    String? executable,
    FileRecord record,
  ) async {
    if (executable == null || executable.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Set the FreeCAD executable in Settings first.')),
      );
      return;
    }
    try {
      await openInFreecad(
        executable: executable,
        files: [record.path],
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to open file in FreeCAD: $error')),
      );
    }
  }
