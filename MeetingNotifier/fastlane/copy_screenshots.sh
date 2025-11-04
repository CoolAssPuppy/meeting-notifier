#!/bin/bash

# Script to copy screenshots from Fastlane's temp location to project folder
# Run this after executing UI tests in Xcode

echo "🔍 Looking for screenshots..."

# Fastlane's temp locations (both regular and sandboxed)
TEMP_DIR="$HOME/Library/Caches/tools.fastlane"
CONTAINER_DIR="$HOME/Library/Containers/com.strategicnerds.MeetingNotifierUITests.xctrunner/Data/Library/Caches/tools.fastlane"

# Destination
DEST_DIR="./fastlane/screenshots/en-US"

# Create destination directory
mkdir -p "$DEST_DIR"

# Find all PNG files in temp directory (from last 24 hours)
SCREENSHOT_COUNT=0

# Check sandboxed container location first (Xcode uses this)
if [ -d "$CONTAINER_DIR" ]; then
    echo "📂 Checking sandboxed container: $CONTAINER_DIR"
    while IFS= read -r -d '' file; do
        filename=$(basename "$file")
        echo "📸 Copying: $filename"
        cp "$file" "$DEST_DIR/$filename"
        ((SCREENSHOT_COUNT++))
    done < <(find "$CONTAINER_DIR" -name "*.png" -mtime -1 -print0)
fi

# Check regular cache location (Fastlane uses this)
if [ $SCREENSHOT_COUNT -eq 0 ] && [ -d "$TEMP_DIR" ]; then
    echo "📂 Checking regular cache: $TEMP_DIR"
    while IFS= read -r -d '' file; do
        filename=$(basename "$file")
        echo "📸 Copying: $filename"
        cp "$file" "$DEST_DIR/$filename"
        ((SCREENSHOT_COUNT++))
    done < <(find "$TEMP_DIR" -name "*.png" -mtime -1 -print0)
fi

if [ $SCREENSHOT_COUNT -eq 0 ]; then
    echo "❌ No screenshots found"
    echo ""
    echo "Searched locations:"
    echo "  - $CONTAINER_DIR"
    echo "  - $TEMP_DIR"
    echo ""
    echo "Did you run the UI tests in Xcode?"
    echo "Run: SimpleScreenshotTests/testCaptureAllScreenshots"
    exit 1
else
    echo ""
    echo "✅ Copied $SCREENSHOT_COUNT screenshot(s) to $DEST_DIR"
    echo ""
    echo "View them:"
    echo "  open $DEST_DIR"
    echo ""
    echo "Upload to App Store Connect:"
    echo "  bundle exec fastlane update_screenshots"
fi
