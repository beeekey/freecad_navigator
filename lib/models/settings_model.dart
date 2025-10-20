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
  ProjectRoot({required this.path, this.label});

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
    required this.forceHeadlessPreviews,
    required this.themePreference,
    required this.folderFavorites,
  });

  final List<ProjectRoot> projectRoots;
  final List<ProjectRoot> defaultLibraries;
  final String? activeProjectPath;
  final String? activeLibraryPath;
  final String? freecadExecutable;
  final bool forceHeadlessPreviews;
  final ThemePreference themePreference;
  final Map<String, List<String>> folderFavorites;

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

  List<String> favoritesForRoot(String rootPath) =>
      folderFavorites[rootPath] ?? const <String>[];

  bool isFavorite(String rootPath, String relativePath) =>
      folderFavorites[rootPath]?.contains(relativePath) ?? false;

  SettingsState copyWith({
    List<ProjectRoot>? projectRoots,
    List<ProjectRoot>? defaultLibraries,
    String? activeProjectPath,
    String? activeLibraryPath,
    String? freecadExecutable,
    bool resetActiveProjectPath = false,
    bool resetActiveLibraryPath = false,
    bool? forceHeadlessPreviews,
    ThemePreference? themePreference,
    Map<String, List<String>>? folderFavorites,
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
      forceHeadlessPreviews:
          forceHeadlessPreviews ?? this.forceHeadlessPreviews,
      themePreference: themePreference ?? this.themePreference,
      folderFavorites: folderFavorites ?? this.folderFavorites,
    );
  }

  Map<String, dynamic> toJson() => {
    'projectRoots': projectRoots.map((e) => e.toJson()).toList(),
    'defaultLibraries': defaultLibraries.map((e) => e.toJson()).toList(),
    'activeProjectPath': activeProjectPath,
    'activeLibraryPath': activeLibraryPath,
    'freecadExecutable': freecadExecutable,
    'forceHeadlessPreviews': forceHeadlessPreviews,
    'themePreference': themePreference.storageValue,
    'folderFavorites': folderFavorites.map(
      (key, value) => MapEntry(key, List<String>.from(value)),
    ),
  };

  static SettingsState fromJson(Map<String, dynamic> json) {
    final rootsJson = json['projectRoots'] as List<dynamic>? ?? const [];
    final librariesJson =
        json['defaultLibraries'] as List<dynamic>? ?? const [];
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
      forceHeadlessPreviews: _parseBool(json['forceHeadlessPreviews']),
      themePreference: ThemePreferenceX.fromStorage(
        json['themePreference'] as String?,
      ),
      folderFavorites: _parseFolderFavorites(json['folderFavorites']),
    );
  }

  String toJsonString() => jsonEncode(toJson());

  static SettingsState empty() => SettingsState(
    projectRoots: const [],
    defaultLibraries: const [],
    activeProjectPath: null,
    activeLibraryPath: null,
    freecadExecutable: null,
    forceHeadlessPreviews: false,
    themePreference: ThemePreference.system,
    folderFavorites: const {},
  );

  static Map<String, List<String>> _parseFolderFavorites(dynamic json) {
    if (json == null) {
      return {};
    }
    final map = Map<String, dynamic>.from(json as Map);
    return map.map(
      (key, value) => MapEntry(key, List<String>.from(value as List)),
    );
  }

  static bool _parseBool(dynamic value) {
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    if (value is String) {
      final normalized = value.toLowerCase();
      return normalized == 'true' ||
          normalized == '1' ||
          normalized == 'yes' ||
          normalized == 'on';
    }
    return false;
  }
}
