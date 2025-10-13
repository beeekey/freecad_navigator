# FreeCAD Navigator

Lightweight, single-user product data management (PDM) companion for FreeCAD projects. Built with Flutter for desktop, FreeCAD Navigator keeps a local index of your `.FCStd` files, surfaces their metadata, and launches FreeCAD right where you need it.

![FreeCAD Navigator UI](FreeCadExplorer_Base.png)

## Highlights
- **Project-aware file explorer** – Add multiple project roots, browse them with a folder tree, toggle between grid and list views, and sort by name or modified date.
- **Fast local indexing** – Watches your project folders, extracts metadata, and caches thumbnails in a SQLite database for instant searching.
- **Rich metadata editing** – View FreeCAD built-in properties and update title, tags, status, notes, and more. Sidecar JSON files keep edits alongside your models.
- **Batch updates** – Apply tag and status changes to many files at once without leaving the navigator.
- **Preview pipeline** – Uses FreeCAD to generate thumbnails and optional OBJ meshes (for the 3D viewer) and stores them under the app cache.
- **Launch workflows** – Open files in FreeCAD with one click or reveal them in your system file browser.
- **Desktop-first UX** – Custom window chrome, material design theming, and adaptive light/dark modes; auto-detects the FreeCAD executable on each platform.

> **Scope note:** FreeCAD Navigator is intentionally lightweight and entirely local. There is no multi-user sync, server, or permissions layer—ideal for individual makers or small labs needing quick PDM-style organization without infrastructure.

## Getting Started
1. Install Flutter 3.16+ with desktop support (Linux, Windows, or macOS).
2. Install FreeCAD (GUI build). Ensure it can be launched from your desktop session.
3. Clone this repository and fetch dependencies:
   ```bash
   flutter pub get
   ```
4. Run the desktop app for your platform, for example:
   ```bash
   flutter run -d linux
   ```
5. On first launch, open **Settings** to:
   - Add one or more project roots (directories containing `.FCStd` files).
   - Point the app at your FreeCAD executable or let it auto-detect.

Once a project root is added, the indexer scans it, builds thumbnails, and makes files searchable. Changes on disk are picked up via file watchers; use the refresh action if you pause the watcher or move large folders around.

## How It Works
- **Indexing service:** Recursively scans project roots, extracting document metadata and thumbnails through `fcstd_reader.dart`, and stores them in `freecad_explorer.db`. A watcher keeps the index in sync and purges removed files.
- **Metadata storage:** FreeCAD properties go into the main table; user edits live in sidecar JSON files (`*.fcmeta.json`) so your annotations travel with the model. Both are merged in the details panel.
- **Search & filter:** Queries span filenames, titles, tags, status, and other metadata. Toggle include/exclude modes and decide whether subfolders are part of the result set.
- **Previews & meshes:** When available, cached thumbnails are shown immediately. Mesh generation powers the experimental 3D viewer, storing OBJ files in the mesh cache.
- **Launch helpers:** The settings controller tracks the FreeCAD executable and offers auto-detection plus quick linking for different desktop platforms.

## Packaging & Distribution
- `install_linux.sh` and `install_linux_dev.sh` help install the Flutter Linux bundle on systems that already satisfy the runtime dependencies.
- `package_linux.sh` builds a distributable Linux archive using Flutter's `linux` target.
- For Windows or macOS, use the standard Flutter desktop build commands (`flutter build windows`, `flutter build macos`)—platform-specific packaging scripts can be added later.

## Limitations & Roadmap
- Single-user only; there is no shared database, revision history, or user management.
- Mesh/preview generation requires the FreeCAD GUI executable and, on headless Linux sessions, an `xvfb-run` setup.
- Mobile builds are untested; focus remains on desktop productivity.

Planned enhancements include richer filtering, more automation around preview regeneration, and optional export of metadata reports. Contributions and feedback are welcome.
