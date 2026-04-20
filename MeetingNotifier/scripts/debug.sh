#!/bin/bash
#
# Build a local Debug copy of MeetingNotifier and launch it, without opening Xcode.
#
# Usage:
#   ./scripts/debug.sh              # build and launch
#   ./scripts/debug.sh --no-launch  # build only, don't open the app
#
# Output:
#   dist/debug/MeetingNotifier.app

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST="$REPO_ROOT/dist/debug"
DERIVED="$REPO_ROOT/build/DerivedData"

LAUNCH=1
if [[ "${1:-}" == "--no-launch" ]]; then
  LAUNCH=0
fi

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "Error: xcodegen not installed. Run: brew install xcodegen"
  exit 1
fi

echo "==> Regenerating Xcode project"
(cd "$REPO_ROOT" && xcodegen generate >/dev/null)

echo "==> Building (Debug)"
xcodebuild \
  -project "$REPO_ROOT/MeetingNotifier.xcodeproj" \
  -scheme MeetingNotifier \
  -configuration Debug \
  -derivedDataPath "$DERIVED" \
  -quiet \
  build

SRC_APP="$DERIVED/Build/Products/Debug/MeetingNotifier.app"
if [[ ! -d "$SRC_APP" ]]; then
  echo "Error: expected built app at $SRC_APP but it's not there."
  exit 1
fi

mkdir -p "$DIST"
rm -rf "$DIST/MeetingNotifier.app"
ditto "$SRC_APP" "$DIST/MeetingNotifier.app"

# Both the DerivedData copy and dist/debug copy share the same bundle ID and
# URL schemes. If both stay registered with LaunchServices, macOS may route
# OAuth callbacks to the wrong one and the auth flow will "hang" — the app
# that doesn't own the pending AppAuth session silently drops the callback.
# Remove and unregister the DerivedData copy so dist/debug is the sole handler,
# then force a fresh registration of dist/debug to make it the preferred handler.
LSREG="/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister"
"$LSREG" -u "$SRC_APP" >/dev/null 2>&1 || true
rm -rf "$SRC_APP"
"$LSREG" -f "$DIST/MeetingNotifier.app" >/dev/null 2>&1 || true

echo ""
echo "Built: $DIST/MeetingNotifier.app"

if [[ "$LAUNCH" == "1" ]]; then
  # Kill any running copy so the new binary takes over.
  pkill -x "MeetingNotifier" 2>/dev/null || true
  sleep 1
  open "$DIST/MeetingNotifier.app"
  echo "Launched."
fi
