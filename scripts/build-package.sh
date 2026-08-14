#!/usr/bin/env bash
# Build deployment package for KolkaUICameras (Linux/macOS)
# Run from the project root: ./scripts/build-package.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OUTPUT_FILE="$PROJECT_ROOT/KolkaUICameras.zip"
APP_ZIP="$PROJECT_ROOT/app.zip"
BUILD_DIR="/tmp/KolkaUICameras_build"
PACKAGE_DIR="/tmp/KolkaUICameras_package"

echo -e "\033[36m=== Building KolkaUICameras deployment package ===\033[0m"
echo "Project root: $PROJECT_ROOT"

# Remove old archives
rm -f "$OUTPUT_FILE" "$APP_ZIP"

# Clean and create staging directory
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

echo "Building app.zip..."

# Copy root files
ROOT_FILES=(
    app.py
    config.py
    models.py
    calibration.py
    config_loader.py
    kolka_snapshot_and_download.py
    compress_images.py
    appsettings.json
    requirements.txt
)

for file in "${ROOT_FILES[@]}"; do
    if [[ -f "$PROJECT_ROOT/$file" ]]; then
        cp "$PROJECT_ROOT/$file" "$BUILD_DIR/"
        echo -e "  \033[90m+ $file\033[0m"
    fi
done

# Copy directories
DIRS=(routes templates static sql fortest)
for dir in "${DIRS[@]}"; do
    if [[ -d "$PROJECT_ROOT/$dir" ]]; then
        cp -r "$PROJECT_ROOT/$dir" "$BUILD_DIR/$dir"
        echo -e "  \033[90m+ $dir/\033[0m"
    fi
done

# Create app.zip (Linux zip uses forward slashes natively)
echo "Creating app.zip..."
(cd "$BUILD_DIR" && zip -qr "$APP_ZIP" .)
rm -rf "$BUILD_DIR"

echo "Creating KolkaUICameras.zip..."

# Create final package directory
rm -rf "$PACKAGE_DIR"
mkdir -p "$PACKAGE_DIR"

# Move app.zip into package
mv "$APP_ZIP" "$PACKAGE_DIR/"

# Copy scripts
SCRIPTS_TO_INCLUDE=(
    install-KolkaUICameras.sh
    update-KolkaUICameras.sh
    uninstall-KolkaUICameras.sh
    verify-KolkaUICameras.sh
)
for script in "${SCRIPTS_TO_INCLUDE[@]}"; do
    if [[ -f "$PROJECT_ROOT/scripts/$script" ]]; then
        cp "$PROJECT_ROOT/scripts/$script" "$PACKAGE_DIR/"
        echo -e "  \033[90m+ $script\033[0m"
    fi
done

# Create final zip
(cd "$PACKAGE_DIR" && zip -qr "$OUTPUT_FILE" .)
rm -rf "$PACKAGE_DIR"

# Show result
ARCHIVE_SIZE=$(du -k "$OUTPUT_FILE" | cut -f1)
echo ""
echo -e "\033[32m=== Package created successfully ===\033[0m"
echo "File: $OUTPUT_FILE"
echo "Size: ${ARCHIVE_SIZE} KB"
echo ""
echo -e "\033[36mArchive contents:\033[0m"
echo "  - app.zip (application files)"
echo "  - install-KolkaUICameras.sh"
echo "  - update-KolkaUICameras.sh"
echo "  - uninstall-KolkaUICameras.sh"
echo "  - verify-KolkaUICameras.sh"
