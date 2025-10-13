import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import 'browser_controller.dart';

class FolderTree extends ConsumerWidget {
  const FolderTree({
    required this.projectRoot,
    required this.activeFolder,
    required this.refreshToken,
    this.emptyPlaceholder = 'Select a project root to view folders.',
    super.key,
  });

  final String projectRoot;
  final String activeFolder;
  final int refreshToken;
  final String emptyPlaceholder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (projectRoot.isEmpty) {
      return Center(child: Text(emptyPlaceholder, textAlign: TextAlign.center));
    }

    return FutureBuilder<bool>(
      future: Directory(projectRoot).exists(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !(snapshot.data ?? false)) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Project root not found:\n$projectRoot',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            FolderNode(
              projectRoot: projectRoot,
              relativePath: '',
              displayName: p.basename(projectRoot),
              isActive: activeFolder.isEmpty,
              refreshToken: refreshToken,
            ),
          ],
        );
      },
    );
  }
}

class FolderNode extends ConsumerStatefulWidget {
  const FolderNode({
    required this.projectRoot,
    required this.relativePath,
    required this.displayName,
    required this.isActive,
    required this.refreshToken,
    super.key,
  });

  final String projectRoot;
  final String relativePath;
  final String displayName;
  final bool isActive;
  final int refreshToken;

  @override
  ConsumerState<FolderNode> createState() => _FolderNodeState();
}

class _FolderNodeState extends ConsumerState<FolderNode> {
  late Future<List<String>> _childrenFuture;

  @override
  void initState() {
    super.initState();
    _childrenFuture = _loadChildren();
  }

  @override
  void didUpdateWidget(covariant FolderNode oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.projectRoot != widget.projectRoot ||
        oldWidget.relativePath != widget.relativePath) {
      _childrenFuture = _loadChildren();
    } else if (oldWidget.refreshToken != widget.refreshToken) {
      _childrenFuture = _loadChildren();
    }
  }

  Future<List<String>> _loadChildren() async {
    final absolute =
        widget.relativePath.isEmpty ? widget.projectRoot : p.join(widget.projectRoot, widget.relativePath);
    final directory = Directory(absolute);
    if (!await directory.exists()) {
      return const [];
    }

    final entries = <String>[];
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is Directory) {
        entries.add(p.basename(entity.path));
      }
    }
    entries.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return entries;
  }

  void _onFolderTap() {
    final path = widget.relativePath;
    ref.read(browserControllerProvider.notifier).setActiveFolder(path);
  }

  String _childRelativePath(String childName) {
    if (widget.relativePath.isEmpty) {
      return childName;
    }
    return p.join(widget.relativePath, childName);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeFolder =
        ref.watch(browserControllerProvider).activeFolder;

    return FutureBuilder<List<String>>(
      future: _childrenFuture,
      builder: (context, snapshot) {
        final children = snapshot.data ?? const [];
        final hasChildren = children.isNotEmpty;

        return ExpansionTile(
          key: PageStorageKey<String>('${widget.projectRoot}:${widget.relativePath}'),
          title: InkWell(
            onTap: _onFolderTap,
            child: Row(
              children: [
                Icon(
                  widget.isActive ? Icons.folder_open : Icons.folder_outlined,
                  color: widget.isActive ? theme.colorScheme.primary : null,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.displayName,
                    style: TextStyle(
                      fontWeight: widget.isActive ? FontWeight.bold : null,
                      color: widget.isActive ? theme.colorScheme.primary : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
          initiallyExpanded: widget.relativePath.isEmpty,
          childrenPadding: const EdgeInsets.only(left: 16),
          children: hasChildren
              ? children
                  .map(
                    (child) => FolderNode(
                      projectRoot: widget.projectRoot,
                      relativePath: _childRelativePath(child),
                      displayName: child,
                      isActive: activeFolder == _childRelativePath(child),
                      refreshToken: widget.refreshToken,
                    ),
                  )
                  .toList()
              : [
                  if (snapshot.connectionState == ConnectionState.waiting)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: LinearProgressIndicator(),
                    ),
                  if (!hasChildren && snapshot.connectionState == ConnectionState.done)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Text('Empty'),
                    ),
                ],
        );
      },
    );
  }
}
