#!/bin/bash

# Resize screenshots to macOS App Store dimensions
# Usage: ./resize_screenshots.sh [input_directory]
#
# Resizes all PNG files to 2880x1800 (Retina display size)
# This is the most commonly accepted size for macOS App Store

TARGET_WIDTH=2880
TARGET_HEIGHT=1800

# Input directory (default: current directory)
INPUT_DIR="${1:-.}"

echo "========================================="
echo "MeetingNotifier Screenshot Resizer"
echo "========================================="
echo ""
echo "Target dimensions: ${TARGET_WIDTH}x${TARGET_HEIGHT}"
echo "Input directory: $INPUT_DIR"
echo ""

# Create output directory
OUTPUT_DIR="${INPUT_DIR}/screenshots_resized"
mkdir -p "$OUTPUT_DIR"

# Count files
PNG_COUNT=$(find "$INPUT_DIR" -maxdepth 1 -name "*.png" -type f | wc -l | tr -d ' ')

if [ "$PNG_COUNT" -eq 0 ]; then
    echo "❌ No PNG files found in $INPUT_DIR"
    echo ""
    echo "Usage: ./resize_screenshots.sh [directory]"
    echo "Example: ./resize_screenshots.sh ~/Desktop/screenshots"
    exit 1
fi

echo "Found $PNG_COUNT PNG file(s) to resize"
echo ""

# Resize all PNG files in input directory
COUNT=0
for file in "$INPUT_DIR"/*.png; do
    if [ -f "$file" ]; then
        filename=$(basename "$file")
        output="$OUTPUT_DIR/${filename}"

        # Get current dimensions
        current_width=$(sips -g pixelWidth "$file" | grep pixelWidth | awk '{print $2}')
        current_height=$(sips -g pixelHeight "$file" | grep pixelHeight | awk '{print $2}')

        echo "Processing: $filename"
        echo "  Current:  ${current_width}x${current_height}"
        echo "  Resizing to: ${TARGET_WIDTH}x${TARGET_HEIGHT}"

        # Resize
        sips -z $TARGET_HEIGHT $TARGET_WIDTH "$file" --out "$output" > /dev/null 2>&1

        if [ $? -eq 0 ]; then
            echo "  ✅ Success"
        else
            echo "  ❌ Failed"
        fi

        COUNT=$((COUNT + 1))
        echo ""
    fi
done

echo "========================================="
echo "✅ Resized $COUNT screenshot(s)"
echo "========================================="
echo ""
echo "Output directory: $OUTPUT_DIR"
echo ""
echo "Next steps:"
echo "1. Review the resized screenshots in $OUTPUT_DIR"
echo "2. Upload them to App Store Connect"
echo "3. Go to https://appstoreconnect.apple.com"
echo "4. Select My Apps > MeetingNotifier > App Store"
echo "5. Upload screenshots in the 'App Preview and Screenshots' section"
echo ""
