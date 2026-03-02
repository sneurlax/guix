#!/usr/bin/env bash
# Dry-run test: exercises the same path logic as build-linux.sh
# without needing Guix or Flutter installed.
set -euo pipefail

GUIX_FLUTTER_DIR="$(basename "$(cd "$(dirname "$0")" && pwd)")"
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

CONF="$PROJECT_ROOT/guix-flutter.conf"
[ -f "$CONF" ] && source "$CONF"

echo "=== Dry-run path resolution ==="
echo "GUIX_FLUTTER_DIR: $GUIX_FLUTTER_DIR"
echo "PROJECT_ROOT:     $PROJECT_ROOT"
echo ""

# Source version env if present.
if [ -f "$PROJECT_ROOT/flutter_version.env" ]; then
    source "$PROJECT_ROOT/flutter_version.env"
    echo "Flutter version: $FLUTTER_VERSION ($FLUTTER_CHANNEL)"
else
    echo "WARNING: flutter_version.env not found at $PROJECT_ROOT/"
fi

if [ -f "$PROJECT_ROOT/android_sdk_version.env" ]; then
    source "$PROJECT_ROOT/android_sdk_version.env"
    echo "Android platform: $ANDROID_PLATFORM_VERSION"
    echo "Android build-tools: $ANDROID_BUILD_TOOLS_VERSION"
else
    echo "WARNING: android_sdk_version.env not found at $PROJECT_ROOT/"
fi
echo ""

echo "Resolved paths:"
echo "  Channels manifest: $PROJECT_ROOT/$GUIX_FLUTTER_DIR/manifests/channels.scm"
echo "  Linux manifest:    $PROJECT_ROOT/$GUIX_FLUTTER_DIR/manifests/linux.scm"
echo "  Android manifest:  $PROJECT_ROOT/$GUIX_FLUTTER_DIR/manifests/android.scm"
echo "  Flutter SDK dir:   $PROJECT_ROOT/.flutter-sdk/flutter"
echo "  Android SDK dir:   $PROJECT_ROOT/.android-sdk"
echo ""

# Verify manifests exist.
ERRORS=0
for f in channels.scm linux.scm android.scm; do
    FULL="$PROJECT_ROOT/$GUIX_FLUTTER_DIR/manifests/$f"
    if [ -f "$FULL" ]; then
        echo "  OK: $f"
    else
        echo "  MISSING: $FULL"
        ((ERRORS++))
    fi
done
echo ""

if [ "$ERRORS" -eq 0 ]; then
    echo "All paths resolve correctly."
else
    echo "ERROR: $ERRORS manifest(s) not found."
    exit 1
fi
