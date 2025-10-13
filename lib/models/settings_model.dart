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
    required this.activeProjectPath,
    required this.freecadExecutable,
    required this.themePreference,
  });

  final List<ProjectRoot> projectRoots;
  final String? activeProjectPath;
  final String? freecadExecutable;
  final ThemePreference themePreference;

  bool get hasProjects => projectRoots.isNotEmpty;

  ProjectRoot? get activeProject {
    if (activeProjectPath == null) {
      return null;
    }
    return projectRoots.firstWhere(
      (root) => root.path == activeProjectPath,
      orElse: () => ProjectRoot(path: activeProjectPath!),
    );
  }

  SettingsState copyWith({
    List<ProjectRoot>? projectRoots,
    String? activeProjectPath,
    String? freecadExecutable,
    bool resetActiveProjectPath = false,
    ThemePreference? themePreference,
  }) {
    return SettingsState(
      projectRoots: projectRoots ?? this.projectRoots,
      activeProjectPath: resetActiveProjectPath
          ? null
          : activeProjectPath ?? this.activeProjectPath,
      freecadExecutable: freecadExecutable ?? this.freecadExecutable,
      themePreference: themePreference ?? this.themePreference,
    );
  }

  Map<String, dynamic> toJson() => {
        'projectRoots': projectRoots.map((e) => e.toJson()).toList(),
        'activeProjectPath': activeProjectPath,
        'freecadExecutable': freecadExecutable,
        'themePreference': themePreference.storageValue,
      };

  static SettingsState fromJson(Map<String, dynamic> json) {
    final rootsJson = json['projectRoots'] as List<dynamic>? ?? const [];
    return SettingsState(
      projectRoots: rootsJson
          .map((e) => ProjectRoot.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      activeProjectPath: json['activeProjectPath'] as String?,
      freecadExecutable: json['freecadExecutable'] as String?,
      themePreference: ThemePreferenceX.fromStorage(json['themePreference'] as String?),
    );
  }

  String toJsonString() => jsonEncode(toJson());

  static SettingsState empty() => SettingsState(
        projectRoots: const [],
        activeProjectPath: null,
        freecadExecutable: null,
        themePreference: ThemePreference.system,
      );
}
