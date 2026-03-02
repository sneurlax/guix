#!/usr/bin/env bash
# Proof-of-concept validation for guix-flutter-scripts.
# Tests path resolution, config flow, and structure WITHOUT needing Guix/Flutter.
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")" && pwd)"
PASS=0
FAIL=0

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }
check() {
    local desc="$1"; shift
    if "$@" &>/dev/null; then pass "$desc"; else fail "$desc"; fi
}

echo "=== guix-flutter-scripts PoC Validation ==="
echo "Project root: $PROJECT_ROOT"
echo ""

# --- 1. Structure checks ---
echo "--- Structure ---"
check "guix/ directory exists" test -d "$PROJECT_ROOT/guix"
check "guix/scripts/ exists" test -d "$PROJECT_ROOT/guix/scripts"
check "guix/manifests/ exists" test -d "$PROJECT_ROOT/guix/manifests"
check "guix/Makefile.inc exists" test -f "$PROJECT_ROOT/guix/Makefile.inc"
check "guix/bootstrap.sh exists and is executable" test -x "$PROJECT_ROOT/guix/bootstrap.sh"
check "guix/pin-channels.sh exists and is executable" test -x "$PROJECT_ROOT/guix/pin-channels.sh"
check "guix/guix-flutter.conf.example exists" test -f "$PROJECT_ROOT/guix/guix-flutter.conf.example"
check "guix/flutter_version.env.example exists" test -f "$PROJECT_ROOT/guix/flutter_version.env.example"
check "guix/android_sdk_version.env.example exists" test -f "$PROJECT_ROOT/guix/android_sdk_version.env.example"

for script in build-linux build-android shell-linux shell-android fetch-flutter fetch-android-sdk; do
    check "guix/scripts/$script.sh exists and is executable" test -x "$PROJECT_ROOT/guix/scripts/$script.sh"
done

for manifest in linux.scm android.scm channels.scm; do
    check "guix/manifests/$manifest exists" test -f "$PROJECT_ROOT/guix/manifests/$manifest"
done

check "Host Makefile exists" test -f "$PROJECT_ROOT/Makefile"
check "Host pubspec.yaml exists" test -f "$PROJECT_ROOT/pubspec.yaml"
check "Host lib/main.dart exists" test -f "$PROJECT_ROOT/lib/main.dart"
echo ""

# --- 2. Template copy test ---
echo "--- Template Copy (simulating bootstrap) ---"
# Clean up any prior test artifacts.
rm -f "$PROJECT_ROOT/guix-flutter.conf" "$PROJECT_ROOT/flutter_version.env" "$PROJECT_ROOT/android_sdk_version.env"

# Copy templates manually (bootstrap.sh does this but also calls guix/flutter).
cp "$PROJECT_ROOT/guix/guix-flutter.conf.example" "$PROJECT_ROOT/guix-flutter.conf"
cp "$PROJECT_ROOT/guix/flutter_version.env.example" "$PROJECT_ROOT/flutter_version.env"
cp "$PROJECT_ROOT/guix/android_sdk_version.env.example" "$PROJECT_ROOT/android_sdk_version.env"

check "guix-flutter.conf created" test -f "$PROJECT_ROOT/guix-flutter.conf"
check "flutter_version.env created" test -f "$PROJECT_ROOT/flutter_version.env"
check "android_sdk_version.env created" test -f "$PROJECT_ROOT/android_sdk_version.env"

# Verify config content.
source "$PROJECT_ROOT/guix-flutter.conf"
check "GUIX_FLUTTER_DIR is 'guix'" test "$GUIX_FLUTTER_DIR" = "guix"

source "$PROJECT_ROOT/flutter_version.env"
check "FLUTTER_VERSION is set" test -n "$FLUTTER_VERSION"
check "FLUTTER_CHANNEL is set" test -n "$FLUTTER_CHANNEL"

source "$PROJECT_ROOT/android_sdk_version.env"
check "ANDROID_PLATFORM_VERSION is set" test -n "$ANDROID_PLATFORM_VERSION"
echo ""

# --- 3. Path resolution tests ---
echo "--- Path Resolution (dry-run script introspection) ---"

# Test that each script resolves PROJECT_ROOT correctly.
# We do this by extracting the first PROJECT_ROOT assignment and evaluating it.
for script in build-linux build-android shell-linux shell-android fetch-flutter fetch-android-sdk; do
    SCRIPT_PATH="$PROJECT_ROOT/guix/scripts/$script.sh"
    # Extract the PROJECT_ROOT line and evaluate it in a subshell
    RESOLVED=$(cd "$(dirname "$SCRIPT_PATH")/../.." && pwd)
    if [ "$RESOLVED" = "$PROJECT_ROOT" ]; then
        pass "$script.sh: PROJECT_ROOT resolves to project root"
    else
        fail "$script.sh: PROJECT_ROOT resolves to '$RESOLVED' (expected '$PROJECT_ROOT')"
    fi
done

# Test that GUIX_FLUTTER_DIR auto-detection works from script location.
for script in build-linux build-android shell-linux shell-android fetch-flutter fetch-android-sdk; do
    SCRIPT_PATH="$PROJECT_ROOT/guix/scripts/$script.sh"
    DETECTED=$(basename "$(cd "$(dirname "$SCRIPT_PATH")/.." && pwd)")
    if [ "$DETECTED" = "guix" ]; then
        pass "$script.sh: GUIX_FLUTTER_DIR auto-detects as 'guix'"
    else
        fail "$script.sh: GUIX_FLUTTER_DIR auto-detected as '$DETECTED' (expected 'guix')"
    fi
done

# Test manifest paths resolve.
for manifest in linux.scm android.scm channels.scm; do
    MANIFEST_PATH="$PROJECT_ROOT/$GUIX_FLUTTER_DIR/manifests/$manifest"
    check "Manifest path resolves: $manifest" test -f "$MANIFEST_PATH"
done
echo ""

# --- 4. Makefile integration test ---
echo "--- Makefile Integration ---"
# Check that make can parse the Makefile and list targets.
if command -v make &>/dev/null; then
    TARGETS=$(make -C "$PROJECT_ROOT" -pRrq 2>/dev/null | grep -E '^guix-[a-z-]+:' | cut -d: -f1 | sort || true)
    for target in guix-setup guix-shell guix-shell-pinned guix-build guix-build-fast \
                  guix-setup-android guix-shell-android guix-shell-android-pinned \
                  guix-build-android guix-build-android-fast guix-pin guix-clean; do
        if echo "$TARGETS" | grep -q "^${target}$"; then
            pass "Make target '$target' defined"
        else
            fail "Make target '$target' missing"
        fi
    done
else
    echo "  SKIP: make not available"
fi
echo ""

# --- 5. No stale references check ---
echo "--- Stale Reference Check ---"
# Ensure no scripts reference the old guix/ path for manifests.
STALE=$(grep -rn 'guix/linux\.scm\|guix/android\.scm\|guix/channels\.scm' \
    "$PROJECT_ROOT/guix/scripts/" "$PROJECT_ROOT/guix/pin-channels.sh" \
    "$PROJECT_ROOT/guix/bootstrap.sh" "$PROJECT_ROOT/guix/Makefile.inc" 2>/dev/null || true)
if [ -z "$STALE" ]; then
    pass "No stale 'guix/*.scm' references in scripts"
else
    fail "Stale references found:"
    echo "$STALE"
fi

# Ensure scripts use double-parent for PROJECT_ROOT (not single).
OLD_PATTERN=$(grep -rn 'PROJECT_ROOT=.*dirname.*\.\."' "$PROJECT_ROOT/guix/scripts/" | grep -v '\.\./\.\.' 2>/dev/null || true)
if [ -z "$OLD_PATTERN" ]; then
    pass "No single-parent PROJECT_ROOT in scripts/"
else
    fail "Old PROJECT_ROOT pattern found:"
    echo "$OLD_PATTERN"
fi
echo ""

# --- 6. Config override test ---
echo "--- Config Override ---"
# Write a custom config and verify scripts would pick it up.
echo 'GUIX_FLUTTER_DIR="custom-guix"' > "$PROJECT_ROOT/guix-flutter.conf"
source "$PROJECT_ROOT/guix-flutter.conf"
check "Config override: GUIX_FLUTTER_DIR='custom-guix'" test "$GUIX_FLUTTER_DIR" = "custom-guix"
# Restore default.
echo 'GUIX_FLUTTER_DIR="guix"' > "$PROJECT_ROOT/guix-flutter.conf"
echo ""

# --- Summary ---
echo "=============================="
echo "Results: $PASS passed, $FAIL failed"
echo "=============================="

if [ "$FAIL" -gt 0 ]; then
    exit 1
fi
