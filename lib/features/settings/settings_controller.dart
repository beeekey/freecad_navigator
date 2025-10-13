import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common/sqlite_api.dart';

import '../../core/db.dart';
import '../../models/settings_model.dart';

final settingsControllerProvider =
    AsyncNotifierProvider<SettingsController, SettingsState>(
  SettingsController.new,
);

class SettingsController extends AsyncNotifier<SettingsState> {
  late Database _db;

  @override
  Future<SettingsState> build() async {
    _db = await ref.watch(databaseProvider.future);
    final records = await _db.query('settings');
    final Map<String, String?> raw = {
      for (final row in records) row['key'] as String: row['value'] as String?
    };

    final rootsJson = raw['project_roots'];
    final librariesJson = raw['default_libraries'];
    final activeProjectPath = raw['active_project_path'];
    final activeLibraryPath = raw['active_library_path'];
    final freecadExecutable = raw['freecad_executable'];
    final themePreferenceValue = raw['theme_preference'];

    final projectRoots = <ProjectRoot>[];
    if (rootsJson != null && rootsJson.isNotEmpty) {
      final parsed = jsonDecode(rootsJson) as List<dynamic>;
      for (final entry in parsed) {
        projectRoots.add(
          ProjectRoot.fromJson(Map<String, dynamic>.from(entry as Map)),
        );
      }
    }

    final defaultLibraries = <ProjectRoot>[];
    if (librariesJson != null && librariesJson.isNotEmpty) {
      final parsed = jsonDecode(librariesJson) as List<dynamic>;
      for (final entry in parsed) {
        defaultLibraries.add(
          ProjectRoot.fromJson(Map<String, dynamic>.from(entry as Map)),
        );
      }
    }

    final state = SettingsState(
      projectRoots: projectRoots,
      defaultLibraries: defaultLibraries,
      activeProjectPath: projectRoots.any((e) => e.path == activeProjectPath)
          ? activeProjectPath
          : projectRoots.isNotEmpty
              ? projectRoots.first.path
              : null,
      activeLibraryPath: defaultLibraries.any((e) => e.path == activeLibraryPath)
          ? activeLibraryPath
          : defaultLibraries.isNotEmpty
              ? defaultLibraries.first.path
              : null,
      freecadExecutable: freecadExecutable,
      themePreference: ThemePreferenceX.fromStorage(themePreferenceValue),
    );

    SettingsState nextState = state;

    if (state.projectRoots.isNotEmpty && state.activeProjectPath == null) {
      await _persistActiveProject(state.projectRoots.first.path);
      nextState = nextState.copyWith(activeProjectPath: state.projectRoots.first.path);
    }

    if (state.defaultLibraries.isNotEmpty && state.activeLibraryPath == null) {
      await _persistActiveLibrary(state.defaultLibraries.first.path);
      nextState = nextState.copyWith(activeLibraryPath: state.defaultLibraries.first.path);
    }

    return nextState;
  }

  Future<void> addProjectRoot(String path, {String? label}) async {
    final current = await future;

    if (current.projectRoots.any((root) => root.path == path)) {
      // Already registered; ensure active project is set.
      await _ensureActiveProject();
      return;
    }

    final normalized = p.normalize(path);
    final updatedRoots = [
      ...current.projectRoots,
      ProjectRoot(path: normalized, label: label),
    ];

    await _persistProjectRoots(updatedRoots);

    var newActive = current.activeProjectPath;
    newActive ??= normalized;

    if (current.projectRoots.isEmpty) {
      await _persistActiveProject(normalized);
      newActive = normalized;
    }

    state = AsyncValue.data(
      current.copyWith(
        projectRoots: updatedRoots,
        activeProjectPath: newActive,
      ),
    );
  }

  Future<void> removeProjectRoot(String path) async {
    final current = await future;
    final normalized = p.normalize(path);

    final updatedRoots =
        current.projectRoots.where((root) => root.path != normalized).toList();

    if (updatedRoots.length == current.projectRoots.length) {
      return;
    }

    await _persistProjectRoots(updatedRoots);

    var newActive = current.activeProjectPath;
    if (newActive == normalized) {
      newActive = updatedRoots.isNotEmpty ? updatedRoots.first.path : null;
      await _persistActiveProject(newActive);
    }

    state = AsyncValue.data(
      current.copyWith(
        projectRoots: updatedRoots,
        activeProjectPath: newActive,
      ),
    );
  }

  Future<void> addDefaultLibrary(String path, {String? label}) async {
    final current = await future;

    if (current.defaultLibraries.any((root) => root.path == path)) {
      await _ensureActiveLibrary();
      return;
    }

    final normalized = p.normalize(path);
    final updatedLibraries = [
      ...current.defaultLibraries,
      ProjectRoot(path: normalized, label: label),
    ];

    await _persistDefaultLibraries(updatedLibraries);

    var newActive = current.activeLibraryPath;
    newActive ??= normalized;

    if (current.defaultLibraries.isEmpty) {
      await _persistActiveLibrary(normalized);
      newActive = normalized;
    }

    state = AsyncValue.data(
      current.copyWith(
        defaultLibraries: updatedLibraries,
        activeLibraryPath: newActive,
      ),
    );
  }

  Future<void> removeDefaultLibrary(String path) async {
    final current = await future;
    final normalized = p.normalize(path);

    final updatedLibraries =
        current.defaultLibraries.where((root) => root.path != normalized).toList();

    if (updatedLibraries.length == current.defaultLibraries.length) {
      return;
    }

    await _persistDefaultLibraries(updatedLibraries);

    var newActive = current.activeLibraryPath;
    if (newActive == normalized) {
      newActive = updatedLibraries.isNotEmpty ? updatedLibraries.first.path : null;
      await _persistActiveLibrary(newActive);
    }

    state = AsyncValue.data(
      current.copyWith(
        defaultLibraries: updatedLibraries,
        activeLibraryPath: newActive,
      ),
    );
  }

  Future<void> renameDefaultLibrary(String path, String? label) async {
    final current = await future;
    final normalized = p.normalize(path);

    final updatedLibraries = current.defaultLibraries
        .map((root) =>
            root.path == normalized ? ProjectRoot(path: root.path, label: label) : root)
        .toList();

    await _persistDefaultLibraries(updatedLibraries);

    state = AsyncValue.data(
      current.copyWith(defaultLibraries: updatedLibraries),
    );
  }

  Future<void> renameProjectRoot(String path, String? label) async {
    final current = await future;
    final normalized = p.normalize(path);

    final updatedRoots = current.projectRoots
        .map((root) =>
            root.path == normalized ? ProjectRoot(path: root.path, label: label) : root)
        .toList();

    await _persistProjectRoots(updatedRoots);

    state = AsyncValue.data(
      current.copyWith(projectRoots: updatedRoots),
    );
  }

  Future<void> setActiveProject(String path) async {
    final current = await future;
    final normalized = p.normalize(path);

    if (!current.projectRoots.any((root) => root.path == normalized)) {
      return;
    }

    await _persistActiveProject(normalized);
    state = AsyncValue.data(
      current.copyWith(activeProjectPath: normalized),
    );
  }

  Future<void> setActiveLibrary(String path) async {
    final current = await future;
    final normalized = p.normalize(path);

    if (!current.defaultLibraries.any((root) => root.path == normalized)) {
      return;
    }

    await _persistActiveLibrary(normalized);
    state = AsyncValue.data(
      current.copyWith(activeLibraryPath: normalized),
    );
  }

  Future<void> updateFreecadExecutable(String? path) async {
    final current = await future;
    await _persistSetting('freecad_executable', path);
    state = AsyncValue.data(
      current.copyWith(freecadExecutable: path),
    );
  }

  Future<void> updateThemePreference(ThemePreference preference) async {
    final current = await future;
    await _persistSetting('theme_preference', preference.storageValue);
    state = AsyncValue.data(
      current.copyWith(themePreference: preference),
    );
  }

  Future<void> _persistProjectRoots(List<ProjectRoot> roots) async {
    final jsonString = jsonEncode(roots.map((root) => root.toJson()).toList());
    await _persistSetting('project_roots', jsonString);
  }

  Future<void> _persistDefaultLibraries(List<ProjectRoot> libraries) async {
    final jsonString = jsonEncode(libraries.map((root) => root.toJson()).toList());
    await _persistSetting('default_libraries', jsonString);
  }

  Future<void> _persistActiveProject(String? path) async {
    await _persistSetting('active_project_path', path);
  }

  Future<void> _persistActiveLibrary(String? path) async {
    await _persistSetting('active_library_path', path);
  }

  Future<void> _ensureActiveProject() async {
    final current = await future;
    if (current.activeProjectPath != null || current.projectRoots.isEmpty) {
      return;
    }
    final first = current.projectRoots.first.path;
    await _persistActiveProject(first);
    state = AsyncValue.data(
      current.copyWith(activeProjectPath: first),
    );
  }

  Future<void> _ensureActiveLibrary() async {
    final current = await future;
    if (current.activeLibraryPath != null || current.defaultLibraries.isEmpty) {
      return;
    }
    final first = current.defaultLibraries.first.path;
    await _persistActiveLibrary(first);
    state = AsyncValue.data(
      current.copyWith(activeLibraryPath: first),
    );
  }

  Future<void> _persistSetting(String key, Object? value) async {
    await _db.insert(
      'settings',
      {
        'key': key,
        'value': value?.toString(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
