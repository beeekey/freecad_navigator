#!/bin/bash

# This script installs a pre-compiled version of the FreeCAD Navigator application.

# --- Configuration ---
APP_NAME="freecad_navigator"
REPO_OWNER="beeekey"
REPO_NAME="freecad_navigator"

# Get version from pubspec.yaml
VERSION=$(grep 'version:' pubspec.yaml | sed 's/version: //')
# Version for the tag (e.g., v1.0.0)
TAG_VERSION="v$(echo "${VERSION}" | cut -d'+' -f1)"
# Version for the filename (e.g., 1.0.0-1)
FILENAME_VERSION=$(echo "${VERSION}" | sed 's/+/-/')
ARCHIVE_NAME="${APP_NAME}-${FILENAME_VERSION}-linux-x64.tar.gz"

# Construct the GitHub release URL
RELEASE_URL="https://github.com/${REPO_OWNER}/${REPO_NAME}/releases/download/${TAG_VERSION}/${ARCHIVE_NAME}"

# --- Paths ---
INSTALL_DIR="$HOME/.local/share/$APP_NAME"
DESKTOP_INSTALL_DIR="$HOME/.local/share/applications"
ICON_INSTALL_DIR_BASE="$HOME/.local/share/icons/hicolor"
BIN_INSTALL_DIR="$HOME/.local/bin"
DOWNLOAD_DIR="/tmp"

# --- Script ---
set -e
echo "Starting installation of FreeCAD Navigator..."

# 1. Download the release archive
echo "Downloading from ${RELEASE_URL}..."
if command -v wget &> /dev/null; then
    wget -O "$DOWNLOAD_DIR/$ARCHIVE_NAME" "$RELEASE_URL"
elif command -v curl &> /dev/null; then
    curl -L -o "$DOWNLOAD_DIR/$ARCHIVE_NAME" "$RELEASE_URL"
else
    echo "Error: 'wget' or 'curl' is required to download the application." >&2
    exit 1
fi

# 2. Create installation directories and extract the bundle
echo "Installing application to ${INSTALL_DIR}..."
rm -rf "$INSTALL_DIR"
mkdir -p "$INSTALL_DIR"
tar -xzf "$DOWNLOAD_DIR/$ARCHIVE_NAME" -C "$INSTALL_DIR"

# 3. Create a symbolic link for command-line access
echo "Creating symlink for command-line access..."
mkdir -p "$BIN_INSTALL_DIR"
ln -sf "$INSTALL_DIR/$APP_NAME" "$BIN_INSTALL_DIR/$APP_NAME"

# 4. Install icons
echo "Installing icons..."
# Note: This assumes the icons are in the project structure relative to the script.
# For a truly standalone installer, icons should be included in the tarball.
# We will copy the main logo from the installed assets and resize it.
if ! command -v convert &> /dev/null; then
    echo "Warning: 'convert' (from ImageMagick) is not installed. Cannot install icons."
else
    for size in 128 256 512; do
        SIZE_SPEC="${size}x${size}"
        mkdir -p "$ICON_INSTALL_DIR_BASE/$SIZE_SPEC/apps"
        convert "$INSTALL_DIR/data/flutter_assets/assets/images/FreeCadExplorer_Logo.png" -resize "$SIZE_SPEC" "$ICON_INSTALL_DIR_BASE/$SIZE_SPEC/apps/${APP_NAME}.png"
    done
fi

# 5. Install the .desktop file
echo "Installing .desktop file..."
cat > "$DESKTOP_INSTALL_DIR/com.freecad.navigator.desktop" <<EOL
[Desktop Entry]
Name=FreeCAD Navigator
Comment=Browse and manage FreeCAD project assets
Exec=$BIN_INSTALL_DIR/$APP_NAME
Icon=$APP_NAME
Terminal=false
Type=Application
Categories=Graphics;Utility;Engineering;
EOL

# 6. Update the desktop database
echo "Updating desktop icon cache and database..."
gtk-update-icon-cache -f -t "$ICON_INSTALL_DIR_BASE" || echo "Warning: gtk-update-icon-cache failed."
update-desktop-database "$DESKTOP_INSTALL_DIR" || echo "Warning: update-desktop-database failed."

# 7. Clean up downloaded file
rm "$DOWNLOAD_DIR/$ARCHIVE_NAME"

echo ""
echo "✅ Installation complete!"
echo "You can now launch 'FreeCAD Navigator' from your system's application menu."
