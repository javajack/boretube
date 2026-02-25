#!/usr/bin/env bash
#
# normalbuild.sh — Build release APK and install on connected device.
#
# USAGE:
#   bash scripts/normalbuild.sh
#

set -euo pipefail
source "$(dirname "$0")/_env.sh"

_detect_device || exit 1
echo ""

cd "$PROJECT_DIR"

echo "==> Running flutter analyze..."
flutter analyze
echo ""

echo "==> Building release APK..."
flutter build apk --release

APK="build/app/outputs/flutter-apk/app-release.apk"
SIZE=$(du -h "$APK" | cut -f1)
echo "    APK: $APK ($SIZE)"
echo ""

echo "==> Installing on $DEVICE_SERIAL..."
adb -s "$DEVICE_SERIAL" install -r "$APK"

echo ""
echo "==> Launching app..."
adb -s "$DEVICE_SERIAL" shell am force-stop com.rakesh.boretube_mobile
adb -s "$DEVICE_SERIAL" shell am start -n com.rakesh.boretube_mobile/.MainActivity

echo ""
echo "Done. Release APK installed and running."
