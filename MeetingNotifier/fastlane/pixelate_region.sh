#!/bin/bash

# Quick pixelate script
# Usage: ./pixelate_region.sh image.png x y width height

if [ $# -ne 5 ]; then
    echo "Usage: $0 image.png x y width height"
    echo "Example: $0 screenshot.png 100 150 200 50"
    exit 1
fi

IMAGE=$1
X=$2
Y=$3
WIDTH=$4
HEIGHT=$5

if ! command -v convert &> /dev/null; then
    echo "❌ ImageMagick not installed"
    echo "Install with: brew install imagemagick"
    exit 1
fi

echo "🔒 Pixelating region ${WIDTH}x${HEIGHT} at ${X},${Y} in $(basename $IMAGE)"

# Create backup
cp "$IMAGE" "${IMAGE}.backup"

# Pixelate the region
convert "$IMAGE" \
  \( +clone -crop ${WIDTH}x${HEIGHT}+${X}+${Y} +repage -scale 5% -scale 2000% \) \
  -geometry +${X}+${Y} -composite \
  "$IMAGE"

echo "✅ Done! Backup saved as ${IMAGE}.backup"
