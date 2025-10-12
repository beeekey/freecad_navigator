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

class BrowserState {
  BrowserState({
    this.activeFolder = '',
    this.searchQuery = '',
    this.includeSubfolders = false,
    this.sort = BrowserSort.nameAsc,
    this.viewMode = BrowserViewMode.grid,
    this.searchExclude = false,
    Set<int>? selectedFileIds,
  }) : selectedFileIds = selectedFileIds ?? <int>{};

  final String activeFolder;
  final String searchQuery;
  final bool includeSubfolders;
  final BrowserSort sort;
  final BrowserViewMode viewMode;
  final bool searchExclude;
  final Set<int> selectedFileIds;

  bool get hasSelection => selectedFileIds.isNotEmpty;

  BrowserState copyWith({
    String? activeFolder,
    String? searchQuery,
    bool? includeSubfolders,
    BrowserSort? sort,
    BrowserViewMode? viewMode,
    bool? searchExclude,
    Set<int>? selectedFileIds,
  }) {
    return BrowserState(
      activeFolder: activeFolder ?? this.activeFolder,
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
    ref.listen<AsyncValue<SettingsState>>(
      settingsControllerProvider,
      (previous, next) {
        final previousActive = previous?.valueOrNull?.activeProjectPath;
        final nextActive = next.valueOrNull?.activeProjectPath;
        if (previousActive != nextActive) {
          // Reset folder and selection when switching projects.
          state = BrowserState();
        }
      },
      fireImmediately: true,
    );

    return BrowserState();
  }

  void setActiveFolder(String folder) {
    state = state.copyWith(
      activeFolder: folder,
      selectedFileIds: <int>{},
    );
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
}
