import 'dart:convert';

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
  });

  final List<ProjectRoot> projectRoots;
  final String? activeProjectPath;
  final String? freecadExecutable;

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
  }) {
    return SettingsState(
      projectRoots: projectRoots ?? this.projectRoots,
      activeProjectPath: resetActiveProjectPath
          ? null
          : activeProjectPath ?? this.activeProjectPath,
      freecadExecutable: freecadExecutable ?? this.freecadExecutable,
    );
  }

  Map<String, dynamic> toJson() => {
        'projectRoots': projectRoots.map((e) => e.toJson()).toList(),
        'activeProjectPath': activeProjectPath,
        'freecadExecutable': freecadExecutable,
      };

  static SettingsState fromJson(Map<String, dynamic> json) {
    final rootsJson = json['projectRoots'] as List<dynamic>? ?? const [];
    return SettingsState(
      projectRoots: rootsJson
          .map((e) => ProjectRoot.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      activeProjectPath: json['activeProjectPath'] as String?,
      freecadExecutable: json['freecadExecutable'] as String?,
    );
  }

  String toJsonString() => jsonEncode(toJson());

  static SettingsState empty() => SettingsState(
        projectRoots: const [],
        activeProjectPath: null,
        freecadExecutable: null,
      );
}
