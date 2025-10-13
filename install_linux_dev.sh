#!/bin/bash

# This script installs the FreeCAD Navigator application locally for the current user.

# --- Configuration ---
APP_NAME="freecad_navigator"
DESKTOP_FILE_NAME="com.freecad.navigator.desktop"
ICON_NAME="freecad_navigator"
BUILD_DIR="build/linux/x64/release/bundle"

# --- Paths ---
# The directory where the final application bundle will be stored
APP_INSTALL_DIR="$HOME/.local/share/$APP_NAME"
# The directory for the .desktop file (for the application menu)
DESKTOP_INSTALL_DIR="$HOME/.local/share/applications"
# The base directory for icons
ICON_INSTALL_DIR_BASE="$HOME/.local/share/icons/hicolor"
# Directory for creating a symlink for command-line access
BIN_INSTALL_DIR="$HOME/.local/bin"

# --- Script ---
set -e
echo "Starting local installation of FreeCAD Navigator..."

# 1. Build the release version of the application
echo "Building Flutter application (release mode)..."
flutter build linux --release

# 2. Create installation directories
echo "Creating installation directories..."
mkdir -p "$DESKTOP_INSTALL_DIR"
mkdir -p "$BIN_INSTALL_DIR"
# Clean any previous installation
rm -rf "$APP_INSTALL_DIR"
mkdir -p "$APP_INSTALL_DIR"

# 3. Copy the entire application bundle
echo "Installing application bundle to $APP_INSTALL_DIR..."
cp -r "$BUILD_DIR"/* "$APP_INSTALL_DIR/"

# 4. Create a symbolic link for command-line access
echo "Creating symlink for command-line access..."
ln -sf "$APP_INSTALL_DIR/$APP_NAME" "$BIN_INSTALL_DIR/$APP_NAME"

# 5. Install icons
echo "Installing icons..."
for size in 128x128 256x256 512x512; do
    mkdir -p "$ICON_INSTALL_DIR_BASE/$size/apps"
    cp "linux/packaging/icons/hicolor/$size/apps/${ICON_NAME}.png" "$ICON_INSTALL_DIR_BASE/$size/apps/"
done

# 6. Install the .desktop file
echo "Installing .desktop file..."
# The Exec path must now point to the binary inside the bundle
cat > "$DESKTOP_INSTALL_DIR/$DESKTOP_FILE_NAME" <<EOL
[Desktop Entry]
Name=FreeCAD Navigator
Comment=Browse and manage FreeCAD project assets
Exec=$APP_INSTALL_DIR/$APP_NAME
Icon=$ICON_NAME
Terminal=false
Type=Application
Categories=Graphics;Utility;Engineering;
EOL

# 7. Update the desktop database
echo "Updating desktop icon cache and database..."
gtk-update-icon-cache -f -t "$ICON_INSTALL_DIR_BASE" || echo "gtk-update-icon-cache not found, continuing..."
update-desktop-database "$DESKTOP_INSTALL_DIR"

echo ""
echo "✅ Installation complete!"
echo "You can now launch 'FreeCAD Navigator' from your system's application menu."
echo "The taskbar icon should now appear correctly."
