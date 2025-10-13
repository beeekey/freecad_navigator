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
    final activeProjectPath = raw['active_project_path'];
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

    final state = SettingsState(
      projectRoots: projectRoots,
      activeProjectPath: projectRoots.any((e) => e.path == activeProjectPath)
          ? activeProjectPath
          : projectRoots.isNotEmpty
              ? projectRoots.first.path
              : null,
      freecadExecutable: freecadExecutable,
      themePreference: ThemePreferenceX.fromStorage(themePreferenceValue),
    );

    if (state.projectRoots.isEmpty) {
      return state;
    }

    if (state.activeProjectPath == null) {
      await _persistActiveProject(state.projectRoots.first.path);
      return state.copyWith(activeProjectPath: state.projectRoots.first.path);
    }

    return state;
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

  Future<void> _persistActiveProject(String? path) async {
    await _persistSetting('active_project_path', path);
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
