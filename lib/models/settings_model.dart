import 'dart:convert';

import 'package:flutter/material.dart';

enum ThemePreference { system, light, dark }

extension ThemePreferenceX on ThemePreference {
  String get storageValue => switch (this) {
        ThemePreference.system => 'system',
        ThemePreference.light => 'light',
        ThemePreference.dark => 'dark',
      };

  ThemeMode toThemeMode() => switch (this) {
        ThemePreference.system => ThemeMode.system,
        ThemePreference.light => ThemeMode.light,
        ThemePreference.dark => ThemeMode.dark,
      };

  static ThemePreference fromStorage(String? value) {
    switch (value) {
      case 'light':
        return ThemePreference.light;
      case 'dark':
        return ThemePreference.dark;
      case 'system':
      default:
        return ThemePreference.system;
    }
  }

  String get label => switch (this) {
        ThemePreference.system => 'System',
        ThemePreference.light => 'Light',
        ThemePreference.dark => 'Dark',
      };
}

class ProjectRoot {
  ProjectRoot({
    required this.path,
    this.label,
  });

  final String path;
  final String? label;

  Map<String, dynamic> toJson() => {
        'path': path,
        if (label != null) 'label': label,
      };

  static ProjectRoot fromJson(Map<String, dynamic> json) {
    return ProjectRoot(
      path: json['path'] as String,
      label: json['label'] as String?,
    );
  }
}

class SettingsState {
  SettingsState({
    required this.projectRoots,
    required this.defaultLibraries,
    required this.activeProjectPath,
    required this.activeLibraryPath,
    required this.freecadExecutable,
    required this.themePreference,
  });

  final List<ProjectRoot> projectRoots;
  final List<ProjectRoot> defaultLibraries;
  final String? activeProjectPath;
  final String? activeLibraryPath;
  final String? freecadExecutable;
  final ThemePreference themePreference;

  bool get hasProjects => projectRoots.isNotEmpty;
  bool get hasDefaultLibraries => defaultLibraries.isNotEmpty;

  ProjectRoot? get activeProject {
    if (activeProjectPath == null) {
      return null;
    }
    return projectRoots.firstWhere(
      (root) => root.path == activeProjectPath,
      orElse: () => ProjectRoot(path: activeProjectPath!),
    );
  }

  ProjectRoot? get activeLibrary {
    if (activeLibraryPath == null) {
      return null;
    }
    return defaultLibraries.firstWhere(
      (root) => root.path == activeLibraryPath,
      orElse: () => ProjectRoot(path: activeLibraryPath!),
    );
  }

  SettingsState copyWith({
    List<ProjectRoot>? projectRoots,
    List<ProjectRoot>? defaultLibraries,
    String? activeProjectPath,
    String? activeLibraryPath,
    String? freecadExecutable,
    bool resetActiveProjectPath = false,
    bool resetActiveLibraryPath = false,
    ThemePreference? themePreference,
  }) {
    return SettingsState(
      projectRoots: projectRoots ?? this.projectRoots,
      defaultLibraries: defaultLibraries ?? this.defaultLibraries,
      activeProjectPath: resetActiveProjectPath
          ? null
          : activeProjectPath ?? this.activeProjectPath,
      activeLibraryPath: resetActiveLibraryPath
          ? null
          : activeLibraryPath ?? this.activeLibraryPath,
      freecadExecutable: freecadExecutable ?? this.freecadExecutable,
      themePreference: themePreference ?? this.themePreference,
    );
  }

  Map<String, dynamic> toJson() => {
        'projectRoots': projectRoots.map((e) => e.toJson()).toList(),
        'defaultLibraries': defaultLibraries.map((e) => e.toJson()).toList(),
        'activeProjectPath': activeProjectPath,
        'activeLibraryPath': activeLibraryPath,
        'freecadExecutable': freecadExecutable,
        'themePreference': themePreference.storageValue,
      };

  static SettingsState fromJson(Map<String, dynamic> json) {
    final rootsJson = json['projectRoots'] as List<dynamic>? ?? const [];
    final librariesJson = json['defaultLibraries'] as List<dynamic>? ?? const [];
    return SettingsState(
      projectRoots: rootsJson
          .map((e) => ProjectRoot.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      defaultLibraries: librariesJson
          .map((e) => ProjectRoot.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      activeProjectPath: json['activeProjectPath'] as String?,
      activeLibraryPath: json['activeLibraryPath'] as String?,
      freecadExecutable: json['freecadExecutable'] as String?,
      themePreference: ThemePreferenceX.fromStorage(json['themePreference'] as String?),
    );
  }

  String toJsonString() => jsonEncode(toJson());

  static SettingsState empty() => SettingsState(
        projectRoots: const [],
        defaultLibraries: const [],
        activeProjectPath: null,
        activeLibraryPath: null,
        freecadExecutable: null,
        themePreference: ThemePreference.system,
      );
}
