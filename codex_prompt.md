# Role
You are a senior Flutter engineer building a cross-platform desktop app called **FreeCAD Navigator**, a lightweight PDM/asset browser for FreeCAD projects. Target platforms: Linux, Windows, macOS.

# Goals
- Let users register multiple project root folders.
- Provide a 3-pane UI: folder tree (left), file cards with thumbnails (center), metadata editor (right).
- Index `.FCStd` files, extract metadata/thumbnails, and keep a fast local cache for browsing/searching.
- Offer actions to open a file in FreeCAD and reveal it in the OS file explorer.
- Persist user edits to sidecar JSON (no in-place `.FCStd` edits by default).

# Architecture & Tech
- Flutter w/ Riverpod for state management.
- Desktop-friendly SQLite via `sqflite_common_ffi`.
- Shared preferences or Hive (tiny box) for quick app settings; default to shared_preferences unless a blocker appears.
- File watching via `watcher`.
- ZIP handling with `archive`.
- Path utilities via `path` + `path_provider`.
- Optional: `desktop_drop` for drag-and-drop of folders, `go_router` for navigation, `transparent_image` for placeholders.
- Run heavy IO/ZIP parsing in isolates to keep UI responsive.

# Core Features
1. **Project Management**
   - Settings dialog to add/remove project root folders.
   - Remember FreeCAD executable path (auto-detect per platform when possible).
   - Project selector dropdown tied to the indexed roots.
2. **Navigation UI**
   - Resizable 3-pane layout.
   - Left: lazy folder tree scoped to active project root (directories only).
   - Center: toolbar (search, refresh, optional manual index), grid of `.FCStd` files in selected folder with thumbnails and metadata preview.
   - Right: details panel for selected file(s), showing merged metadata and editable sidecar fields.
3. **File Indexing & Watching**
   - Initial recursive scan per root to find `.FCStd` files.
   - Maintain SQLite schema:
     ```
     files(id, path, project_root, folder, filename, ext, mtime, size, has_thumbnail, thumb_path, title, last_indexed)
     file_meta(file_id, key, value)
     file_meta_sidecar(file_id, key, value)
     settings(key, value)
     ```
   - Extract metadata from `Document.xml` (<Properties>) and thumbnails from `thumbnails/Thumbnail.png`.
   - Cache thumbnails in an app cache dir (stable hash per path).
   - Load sidecar `${filename}.fcmeta.json`; treat as source of truth for editable fields.
   - Use `DirectoryWatcher` to update DB/UI on filesystem changes (create/move/delete/modify) with debouncing.
4. **Metadata Editing**
   - Editable fields: Title, Tags, Status, Notes.
   - Save writes to sidecar JSON + `file_meta_sidecar`, without touching `.FCStd`.
   - Present merged view: sidecar value → built-in metadata → empty.
   - Support multi-select with limited batch edits (Tags/Status apply to N files).
5. **Actions**
   - Launch FreeCAD with selected file(s) via configured executable path.
   - Reveal file in OS explorer (`explorer.exe /select,`, `open -R`, `xdg-open`).
   - Stub “Write into .FCStd meta (coming soon)” button; no functionality yet.

# Implementation Notes
- Start from `flutter create --platforms=windows,macos,linux freecad_explorer`.
- Folder structure under `lib/` (suggested):
  ```
  lib/
    main.dart
    app.dart
    core/
      db.dart
      paths.dart
      platform.dart
      fcstd_reader.dart
      indexing_service.dart
    features/
      settings/
        settings_page.dart
        settings_controller.dart
      browser/
        browser_page.dart
        folder_tree.dart
        file_grid.dart
        details_panel.dart
        search_bar.dart
    models/
      file_record.dart
      file_meta.dart
      settings_model.dart
  ```
- Initialize SQLite FFI on desktop (`sqfliteFfiInit(); databaseFactory = databaseFactoryFfi;`).
- Derive cache and data directories via `path_provider`.
- Extract metadata in isolates (`compute` or `Isolate.run`). Return thumbnail path, built-in metadata, and timestamps.
- Use Riverpod for app-wide providers: DB, settings, project list, folder selection, file list, selected files, metadata.
- Keep folder tree purely filesystem-driven; use DB for file metadata lookups.
- Debounce watcher events to avoid thrash; re-index touched files.

# Data Handling
- Metadata keys to parse from `Document.xml`:
  - Title (fallback: filename without extension)
  - Comment
  - Company
  - CreatedBy
  - CreationDate
  - LastModifiedBy
  - LastModifiedDate
  - FreeCADVersion
  - Document Label (if present)
- Sidecar JSON format: `{ "Title": "...", "Tags": "...", "Status": "...", "Notes": "..." }`.
- On save, update DB and overwrite sidecar file atomically (write-temp + rename).
- Ensure indexer is idempotent; prune missing files on next scan.

# UI/UX Details
- Show placeholder icon when thumbnail absent (use `transparent_image` or in-app asset).
- Display file stats in details pane: full path, size, modified date.
- Tooltip or status line showing item count, selected count.
- Handle errors with non-blocking snackbars/toasts; log details for debugging.
- Keep app responsive during indexing (progress indicator optional).

# Non-Functional Requirements
- Fast, offline-first; avoid unnecessary network calls.
- Safe by default: read-only interactions with `.FCStd`.
- Cross-platform parity for core flows.
- Clear error messaging and resilient to partial failures.

# Testing Checklist
- Add/remove project roots; restart to ensure persistence.
- Deep folder hierarchies with many `.FCStd` files.
- Files with and without metadata/thumbnails/sidecar.
- Sidecar creation, update, delete flows.
- File rename/move/delete detection via watcher.
- Open in FreeCAD on all platforms.
- Reveal in OS explorer on all platforms.

# Deliverables
- Working Flutter desktop app with the above capabilities.
- Source organized per layout above, with Riverpod-based state management and SQLite-backed indexing.
- Document any major trade-offs or TODOs inline and in README if relevant.
