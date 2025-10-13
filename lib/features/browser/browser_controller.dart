import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/file_record.dart';
import '../../models/settings_model.dart';
import '../settings/settings_controller.dart';

final browserControllerProvider =
    NotifierProvider<BrowserController, BrowserState>(
  BrowserController.new,
);

enum BrowserSort { nameAsc, nameDesc, dateAsc, dateDesc }
enum BrowserViewMode { grid, list }
enum BrowserNavigationSource { project, defaultLibrary }

class BrowserState {
  BrowserState({
    this.source = BrowserNavigationSource.project,
    this.projectFolder = '',
    this.libraryFolder = '',
    this.searchQuery = '',
    this.includeSubfolders = false,
    this.sort = BrowserSort.nameAsc,
    this.viewMode = BrowserViewMode.grid,
    this.searchExclude = false,
    Set<int>? selectedFileIds,
  }) : selectedFileIds = selectedFileIds ?? <int>{};

  final BrowserNavigationSource source;
  final String projectFolder;
  final String libraryFolder;
  final String searchQuery;
  final bool includeSubfolders;
  final BrowserSort sort;
  final BrowserViewMode viewMode;
  final bool searchExclude;
  final Set<int> selectedFileIds;

  bool get hasSelection => selectedFileIds.isNotEmpty;
  String get activeFolder =>
      source == BrowserNavigationSource.project ? projectFolder : libraryFolder;

  BrowserState copyWith({
    BrowserNavigationSource? source,
    String? projectFolder,
    String? libraryFolder,
    String? searchQuery,
    bool? includeSubfolders,
    BrowserSort? sort,
    BrowserViewMode? viewMode,
    bool? searchExclude,
    Set<int>? selectedFileIds,
  }) {
    return BrowserState(
      source: source ?? this.source,
      projectFolder: projectFolder ?? this.projectFolder,
      libraryFolder: libraryFolder ?? this.libraryFolder,
      searchQuery: searchQuery ?? this.searchQuery,
      includeSubfolders: includeSubfolders ?? this.includeSubfolders,
      sort: sort ?? this.sort,
      viewMode: viewMode ?? this.viewMode,
      searchExclude: searchExclude ?? this.searchExclude,
      selectedFileIds: selectedFileIds ?? this.selectedFileIds,
    );
  }
}

class BrowserController extends Notifier<BrowserState> {
  @override
  BrowserState build() {
    final settingsAsync = ref.watch(settingsControllerProvider);
    final settings = settingsAsync.valueOrNull;

    final initialSource = settings?.activeProjectPath != null
        ? BrowserNavigationSource.project
        : settings?.activeLibraryPath != null
            ? BrowserNavigationSource.defaultLibrary
            : BrowserNavigationSource.project;

    ref.listen<AsyncValue<SettingsState>>(
      settingsControllerProvider,
      (previous, next) {
        final previousState = previous?.valueOrNull;
        final nextState = next.valueOrNull;
        if (nextState == null) {
          return;
        }

        final previousProject = previousState?.activeProjectPath;
        final nextProject = nextState.activeProjectPath;
        final previousLibrary = previousState?.activeLibraryPath;
        final nextLibrary = nextState.activeLibraryPath;

        if (previousProject != nextProject) {
          state = state.copyWith(
            projectFolder: '',
            selectedFileIds: state.source == BrowserNavigationSource.project
                ? <int>{}
                : state.selectedFileIds,
          );
        }

        if (previousLibrary != nextLibrary) {
          state = state.copyWith(
            libraryFolder: '',
            selectedFileIds: state.source == BrowserNavigationSource.defaultLibrary
                ? <int>{}
                : state.selectedFileIds,
          );
        }

        if (state.source == BrowserNavigationSource.defaultLibrary &&
            nextLibrary == null) {
          // Active library removed; fall back to projects.
          state = state.copyWith(
            source: BrowserNavigationSource.project,
            selectedFileIds: <int>{},
          );
        } else if (state.source == BrowserNavigationSource.project &&
            nextProject == null &&
            nextLibrary != null) {
          // No active project but libraries exist.
          state = state.copyWith(
            source: BrowserNavigationSource.defaultLibrary,
            selectedFileIds: <int>{},
          );
        }
      },
    );

    return BrowserState(source: initialSource);
  }

  void setActiveFolder(String folder) {
    state = switch (state.source) {
      BrowserNavigationSource.project => state.copyWith(
          projectFolder: folder,
          selectedFileIds: <int>{},
        ),
      BrowserNavigationSource.defaultLibrary => state.copyWith(
          libraryFolder: folder,
          selectedFileIds: <int>{},
        ),
    };
  }

  void updateSearchQuery(String query) {
    state = state.copyWith(
      searchQuery: query.toLowerCase(),
      selectedFileIds: state.selectedFileIds,
    );
  }

  void setIncludeSubfolders(bool value) {
    if (state.includeSubfolders == value) {
      return;
    }
    state = state.copyWith(
      includeSubfolders: value,
      selectedFileIds: state.selectedFileIds,
    );
  }

  void toggleSearchExclude() {
    state = state.copyWith(searchExclude: !state.searchExclude);
  }

  void setSortOption(BrowserSort sort) {
    if (state.sort == sort) return;
    state = state.copyWith(sort: sort);
  }

  void setViewMode(BrowserViewMode mode) {
    if (state.viewMode == mode) return;
    state = state.copyWith(viewMode: mode);
  }

  void toggleSelection(FileRecord record, {bool multiSelect = false}) {
    final updated = <int>{...state.selectedFileIds};
    if (multiSelect) {
      if (updated.contains(record.id)) {
        updated.remove(record.id);
      } else {
        updated.add(record.id);
      }
    } else {
      if (updated.length == 1 && updated.contains(record.id)) {
        updated.clear();
      } else {
        updated
          ..clear()
          ..add(record.id);
      }
    }

    state = state.copyWith(selectedFileIds: updated);
  }

  void clearSelection() {
   if (state.selectedFileIds.isEmpty) return;
   state = state.copyWith(selectedFileIds: <int>{});
  }

  void setNavigationSource(BrowserNavigationSource source) {
    if (state.source == source) {
      return;
    }
    state = state.copyWith(
      source: source,
      selectedFileIds: <int>{},
    );
  }

  void resetFolderForSource(BrowserNavigationSource source) {
    switch (source) {
      case BrowserNavigationSource.project:
        state = state.copyWith(projectFolder: '');
        break;
      case BrowserNavigationSource.defaultLibrary:
        state = state.copyWith(libraryFolder: '');
        break;
    }
  }
}
