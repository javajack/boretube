#!/usr/bin/env bash
#
# prodbuild.sh — Production build pipeline (analyze, test, build release APK).
#
# Does NOT install on device — produces a signed release APK for distribution.
#
# USAGE:
#   bash scripts/prodbuild.sh
#
# TODO: Add keystore signing config for Play Store distribution.
#       Currently builds an unsigned release APK.
#

set -euo pipefail
source "$(dirname "$0")/_env.sh"

cd "$PROJECT_DIR"

echo "==> Step 1/4: flutter analyze..."
flutter analyze
echo ""

echo "==> Step 2/4: flutter test..."
flutter test
echo ""

echo "==> Step 3/4: Building release APK..."
flutter build apk --release
echo ""

APK="build/app/outputs/flutter-apk/app-release.apk"
SIZE=$(du -h "$APK" | cut -f1)

echo "==> Step 4/4: Build summary"
echo ""
echo "  APK:     $APK"
echo "  Size:    $SIZE"
echo "  Version: $(grep '^version:' pubspec.yaml | cut -d' ' -f2)"
echo ""
echo "To install on a connected device:"
echo "  adb install -r $APK"
echo ""
echo "Production build complete."
