#!/bin/bash

# Script to blur PII in screenshots
# Requires ImageMagick: brew install imagemagick

SCREENSHOTS_DIR="./fastlane/screenshots/en-US"

if ! command -v convert &> /dev/null; then
    echo "❌ ImageMagick not installed"
    echo "Install with: brew install imagemagick"
    exit 1
fi

echo "🔒 Blurring PII in screenshots..."

# Function to blur a region: blur_region filename x y width height
blur_region() {
    local file=$1
    local x=$2
    local y=$3
    local w=$4
    local h=$5

    echo "   Blurring region in $(basename $file): ${x},${y} ${w}x${h}"

    # Create temp file
    local temp="${file}.tmp.png"

    # Extract region, blur it, composite back
    convert "$file" \
        \( +clone -crop ${w}x${h}+${x}+${y} +repage -blur 0x20 \) \
        -geometry +${x}+${y} -composite \
        "$temp"

    mv "$temp" "$file"
}

# Example: Blur email addresses in screenshots
# Adjust coordinates based on where PII appears in your screenshots

# Uncomment and adjust these examples:

# Blur email in dropdown
# blur_region "$SCREENSHOTS_DIR/01DropdownWithMeetings.png" 100 50 200 30

# Blur email in settings
# blur_region "$SCREENSHOTS_DIR/02SettingsAccounts.png" 150 100 250 40

echo ""
echo "💡 To use this script:"
echo "1. Open your screenshots and note the coordinates of PII"
echo "2. Edit this script and uncomment/adjust the blur_region calls"
echo "3. Run: ./fastlane/blur_pii.sh"
echo ""
echo "Or use Preview.app to manually blur regions"
