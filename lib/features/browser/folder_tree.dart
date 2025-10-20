import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../settings/settings_controller.dart';
import 'browser_controller.dart';

class FolderTree extends ConsumerStatefulWidget {
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
  ConsumerState<FolderTree> createState() => _FolderTreeState();
}

class _FolderTreeState extends ConsumerState<FolderTree> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void didUpdateWidget(covariant FolderTree oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.projectRoot != widget.projectRoot &&
        widget.projectRoot.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scrollController.hasClients) return;
        _scrollController.jumpTo(0);
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(settingsControllerProvider);
    final favoriteFolders = settingsAsync.maybeWhen(
      data: (settings) =>
          List<String>.from(settings.favoritesForRoot(widget.projectRoot)),
      orElse: () => <String>[],
    );

    if (widget.projectRoot.isEmpty) {
      return Center(
        child: Text(widget.emptyPlaceholder, textAlign: TextAlign.center),
      );
    }

    return FutureBuilder<bool>(
      future: Directory(widget.projectRoot).exists(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !(snapshot.data ?? false)) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Project root not found:\n${widget.projectRoot}',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final children = <Widget>[
          ..._buildFavoritesSection(context, favoriteFolders),
          FolderNode(
            projectRoot: widget.projectRoot,
            relativePath: '',
            displayName: p.basename(widget.projectRoot),
            isActive: widget.activeFolder.isEmpty,
            refreshToken: widget.refreshToken,
          ),
        ];

        return ListView(
          key: PageStorageKey('folder-tree-${widget.projectRoot}'),
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: children,
        );
      },
    );
  }

  List<Widget> _buildFavoritesSection(
    BuildContext context,
    List<String> favorites,
  ) {
    if (favorites.isEmpty) {
      return const [];
    }

    final theme = Theme.of(context);

    final favoriteTiles = favorites
        .where((relativePath) => relativePath.isNotEmpty)
        .map(
          (relativePath) => _FavoriteFolderTile(
            key: ValueKey('favorite-${widget.projectRoot}::$relativePath'),
            projectRoot: widget.projectRoot,
            relativePath: relativePath,
            isActive: widget.activeFolder == relativePath,
            onSelect: () => ref
                .read(browserControllerProvider.notifier)
                .setActiveFolder(relativePath),
            onToggleFavorite: () => ref
                .read(settingsControllerProvider.notifier)
                .toggleFavoriteFolder(
                  rootPath: widget.projectRoot,
                  relativePath: relativePath,
                ),
          ),
        )
        .toList();

    if (favoriteTiles.isEmpty) {
      return const [];
    }

    return [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Text(
          'Favorites',
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.secondary,
          ),
        ),
      ),
      ...favoriteTiles,
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: Divider(height: 16),
      ),
    ];
  }
}

class _FavoriteFolderTile extends StatelessWidget {
  const _FavoriteFolderTile({
    required this.projectRoot,
    required this.relativePath,
    required this.isActive,
    required this.onSelect,
    required this.onToggleFavorite,
    super.key,
  });

  final String projectRoot;
  final String relativePath;
  final bool isActive;
  final VoidCallback onSelect;
  final VoidCallback onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayName = p.basename(relativePath);
    final showSubtitle = relativePath != displayName;
    final fullPath = p.join(projectRoot, relativePath);

    return Tooltip(
      message: fullPath,
      waitDuration: const Duration(milliseconds: 400),
      child: ListTile(
        dense: true,
        leading: Icon(Icons.star, color: theme.colorScheme.secondary),
        title: Text(
          displayName,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: isActive ? FontWeight.w600 : null,
            color: isActive ? theme.colorScheme.primary : null,
          ),
        ),
        subtitle: showSubtitle
            ? Text(
                relativePath,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              )
            : null,
        onTap: onSelect,
        selected: isActive,
        trailing: IconButton(
          tooltip: 'Remove from favorites',
          icon: Icon(Icons.star, color: theme.colorScheme.secondary),
          onPressed: onToggleFavorite,
        ),
      ),
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
    if (widget.isActive) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollIntoView());
    }
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
    if (!oldWidget.isActive && widget.isActive) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollIntoView());
    }
  }

  Future<List<String>> _loadChildren() async {
    final absolute = widget.relativePath.isEmpty
        ? widget.projectRoot
        : p.join(widget.projectRoot, widget.relativePath);
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

  void _scrollIntoView() {
    if (!mounted) return;
    try {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 250),
        alignment: 0.0,
        curve: Curves.easeOut,
      );
    } catch (_) {
      // Ignore focus failures; the tree may not be attached yet.
    }
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
    final activeFolder = ref.watch(browserControllerProvider).activeFolder;
    final settingsAsync = ref.watch(settingsControllerProvider);
    final settings = settingsAsync.valueOrNull;
    final isFavorite =
        settings?.isFavorite(widget.projectRoot, widget.relativePath) ?? false;

    return FutureBuilder<List<String>>(
      future: _childrenFuture,
      builder: (context, snapshot) {
        final children = snapshot.data ?? const [];
        final hasChildren = children.isNotEmpty;

        return ExpansionTile(
          key: PageStorageKey<String>(
            '${widget.projectRoot}:${widget.relativePath}',
          ),
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
                if (widget.relativePath.isNotEmpty)
                  IconButton(
                    iconSize: 20,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    splashRadius: 18,
                    tooltip: isFavorite
                        ? 'Remove from favorites'
                        : 'Add to favorites',
                    icon: Icon(
                      isFavorite ? Icons.star : Icons.star_border,
                      color: isFavorite
                          ? theme.colorScheme.secondary
                          : theme.iconTheme.color,
                    ),
                    onPressed: settings == null
                        ? null
                        : () => ref
                              .read(settingsControllerProvider.notifier)
                              .toggleFavoriteFolder(
                                rootPath: widget.projectRoot,
                                relativePath: widget.relativePath,
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
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: LinearProgressIndicator(),
                    ),
                  if (!hasChildren &&
                      snapshot.connectionState == ConnectionState.done)
                    const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Text('Empty'),
                    ),
                ],
        );
      },
    );
  }
}
