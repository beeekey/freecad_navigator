import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/indexing_service.dart';
import '../../core/platform.dart';
import '../../core/reload_signal.dart';
import '../../models/file_record.dart';
import '../../models/settings_model.dart';
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
    final browserController = ref.read(browserControllerProvider.notifier);
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
          final hasProjects = settings.hasProjects;
          final hasLibraries = settings.hasDefaultLibraries;

          if (!hasProjects && !hasLibraries) {
            return const _EmptyState();
          }

          var effectiveSource = browserState.source;
          if (effectiveSource == BrowserNavigationSource.project && !hasProjects && hasLibraries) {
            effectiveSource = BrowserNavigationSource.defaultLibrary;
          } else if (effectiveSource == BrowserNavigationSource.defaultLibrary &&
              !hasLibraries &&
              hasProjects) {
            effectiveSource = BrowserNavigationSource.project;
          }

          if (effectiveSource != browserState.source) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              browserController.setNavigationSource(effectiveSource);
            });
          }

          final activeProjectPath = settings.activeProject?.path ?? '';
          final activeLibraryPath = settings.activeLibrary?.path ?? '';
          final activeRoot = effectiveSource == BrowserNavigationSource.project
              ? activeProjectPath
              : activeLibraryPath;

          final indexingState = indexingAsync.valueOrNull;
          final isIndexing =
              activeRoot.isNotEmpty ? indexingState?.isIndexing(activeRoot) ?? false : false;

          return Row(
            children: [
              SizedBox(
                width: 280,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildNavigationHeader(
                      context: context,
                      title: 'Projects',
                      labelText: 'Project',
                      emptyMessage: 'Add project roots in Settings.',
                      icon: Icons.folder_outlined,
                      isExpanded: effectiveSource == BrowserNavigationSource.project,
                      roots: settings.projectRoots,
                      activePath: activeProjectPath.isEmpty ? null : activeProjectPath,
                      onTapHeader: () =>
                          browserController.setNavigationSource(BrowserNavigationSource.project),
                      onChanged: (value) {
                        if (value != null) {
                          ref.read(settingsControllerProvider.notifier).setActiveProject(value);
                        }
                      },
                    ),
                    if (effectiveSource == BrowserNavigationSource.project)
                      Expanded(
                        child: FolderTree(
                          projectRoot: activeProjectPath,
                          activeFolder: browserState.projectFolder,
                          refreshToken: reloadToken,
                        ),
                      ),
                    const Divider(height: 1),
                    _buildNavigationHeader(
                      context: context,
                      title: 'Default libraries',
                      labelText: 'Default library',
                      emptyMessage: 'Add default libraries in Settings.',
                      icon: Icons.library_books_outlined,
                      isExpanded: effectiveSource == BrowserNavigationSource.defaultLibrary,
                      roots: settings.defaultLibraries,
                      activePath: activeLibraryPath.isEmpty ? null : activeLibraryPath,
                      onTapHeader: () =>
                          browserController.setNavigationSource(BrowserNavigationSource.defaultLibrary),
                      onChanged: (value) {
                        if (value != null) {
                          ref.read(settingsControllerProvider.notifier).setActiveLibrary(value);
                        }
                      },
                    ),
                    if (effectiveSource == BrowserNavigationSource.defaultLibrary)
                      Expanded(
                        child: FolderTree(
                          projectRoot: activeLibraryPath,
                          activeFolder: browserState.libraryFolder,
                          refreshToken: reloadToken,
                          emptyPlaceholder: 'Select a default library to view folders.',
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
                              projectRoot: activeRoot,
                              folder: browserState.activeFolder,
                              includeSubfolders: includeSubfolders,
                              selection: browserState.selectedFileIds,
                              sort: browserState.sort,
                              searchExclude: browserState.searchExclude,
                              isIndexing: isIndexing,
                              onOpenFile: (record) => _openInFreecad(context, settings.freecadExecutable, record),
                            )
                          : FilePreviewList(
                              projectRoot: activeRoot,
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
                  projectRoot: activeRoot,
                  selectedFileIds: browserState.selectedFileIds,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildNavigationHeader({
    required BuildContext context,
    required String title,
    required String labelText,
    required String emptyMessage,
    required IconData icon,
    required bool isExpanded,
    required List<ProjectRoot> roots,
    required String? activePath,
    required VoidCallback onTapHeader,
    required ValueChanged<String?> onChanged,
  }) {
    final theme = Theme.of(context);
    final hasRoots = roots.isNotEmpty;
    final resolvedActivePath = hasRoots
        ? (activePath != null && roots.any((root) => root.path == activePath)
            ? activePath
            : roots.first.path)
        : null;
    final headerColor = isExpanded ? theme.colorScheme.primary : theme.textTheme.titleSmall?.color;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: hasRoots ? onTapHeader : null,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Icon(icon, size: 20, color: headerColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: headerColor,
                      ),
                    ),
                  ),
                  if (hasRoots)
                    Icon(
                      isExpanded ? Icons.expand_less : Icons.expand_more,
                      color: headerColor,
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (hasRoots)
            InputDecorator(
              decoration: InputDecoration(
                labelText: labelText,
                border: const OutlineInputBorder(),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  dropdownColor: theme.colorScheme.primaryContainer,
                  value: resolvedActivePath,
                  onChanged: onChanged,
                  items: roots
                      .map(
                        (root) => DropdownMenuItem<String>(
                          value: root.path,
                          child: Text(
                            _displayNameForRoot(root),
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                  selectedItemBuilder: (context) {
                    return roots
                        .map(
                          (root) => Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              _displayNameForRoot(root),
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        )
                        .toList();
                  },
                  icon: Icon(
                    Icons.arrow_drop_down,
                    color: theme.colorScheme.primary,
                  ),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
              decoration: BoxDecoration(
                border: Border.all(
                  color: theme.dividerColor.withValues(alpha: 0.4),
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                emptyMessage,
                style: theme.textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );
  }

  String _displayNameForRoot(ProjectRoot root) {
    if (root.label?.isNotEmpty == true) {
      return root.label!;
    }
    return p.basename(root.path);
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
