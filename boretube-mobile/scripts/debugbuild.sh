#!/usr/bin/env bash
#
# debugbuild.sh — Build debug APK, install, and launch on connected device.
#
# USAGE:
#   bash scripts/debugbuild.sh
#

set -euo pipefail
source "$(dirname "$0")/_env.sh"

_detect_device || exit 1
echo ""

cd "$PROJECT_DIR"

echo "==> Building debug APK..."
flutter build apk --debug

echo ""
echo "==> Installing on $DEVICE_SERIAL..."
adb -s "$DEVICE_SERIAL" install -r build/app/outputs/flutter-apk/app-debug.apk

echo ""
echo "==> Launching app..."
adb -s "$DEVICE_SERIAL" shell am force-stop com.rakesh.boretube_mobile
adb -s "$DEVICE_SERIAL" shell am start -n com.rakesh.boretube_mobile/.MainActivity

echo ""
echo "==> Tailing logs (Ctrl+C to stop)..."
adb -s "$DEVICE_SERIAL" logcat -c
adb -s "$DEVICE_SERIAL" logcat -s flutter
