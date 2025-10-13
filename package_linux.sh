#!/bin/bash

# This script packages the FreeCAD Navigator application for Linux distribution.

# --- Configuration ---
APP_NAME="freecad_navigator"
BUILD_DIR="build/linux/x64/release/bundle"
RELEASE_DIR="build/linux/x64/release"
# Read version from pubspec.yaml (e.g., 1.0.0+1)
VERSION=$(grep 'version:' pubspec.yaml | sed 's/version: //')
# Clean the version string for URL compatibility (e.g., 1.0.0-1 instead of 1.0.0+1)
CLEAN_VERSION=$(echo "${VERSION}" | sed 's/+/-/')
ARCHIVE_NAME="${APP_NAME}-${CLEAN_VERSION}-linux-x64.tar.gz"

# --- Script ---
set -e
echo "Starting packaging of FreeCAD Navigator version ${CLEAN_VERSION}..."

# 1. Build the release version of the application
echo "Building Flutter application (release mode)..."
flutter build linux --release

# 2. Create the archive
echo "Creating archive: ${ARCHIVE_NAME}"
# The -C option tells tar to change to that directory before adding files.
# This avoids creating a tarball with the full 'build/linux/x64/release/bundle' path inside.
cd "${BUILD_DIR}"
tar -czf "../../${ARCHIVE_NAME}" .
cd - > /dev/null # Go back to previous directory silently

echo ""
echo "✅ Packaging complete!"
echo "Distribution archive created at: ${RELEASE_DIR}/${ARCHIVE_NAME}"
