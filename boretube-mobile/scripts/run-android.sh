#!/usr/bin/env bash
#
# run-android.sh — Build and run the Boretube app on a connected Android device
#
# USAGE:
#   bash scripts/run-android.sh           # debug mode with hot reload
#   bash scripts/run-android.sh --release # release APK

set -euo pipefail

# ---- Environment ----

export JAVA_HOME="$HOME/development/jdk-17.0.2"
export ANDROID_HOME="$HOME/Android/Sdk"
export PATH="$HOME/development/flutter/bin:$JAVA_HOME/bin:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH"

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# ---- Preflight checks ----

if ! command -v flutter &> /dev/null; then
  echo "ERROR: flutter not found at ~/development/flutter/bin/flutter"
  exit 1
fi

if ! command -v adb &> /dev/null; then
  echo "ERROR: adb not found. Is Android SDK installed at ~/Android/Sdk?"
  exit 1
fi

# ---- Detect devices ----

DEVICES=$(adb devices 2>/dev/null | grep -E "^[a-zA-Z0-9]+" | grep -w "device" || true)
DEVICE_COUNT=$(echo "$DEVICES" | grep -c . 2>/dev/null || echo "0")

if [[ "$DEVICE_COUNT" -eq 0 ]]; then
  echo "ERROR: No authorized Android device found."
  echo ""
  echo "Troubleshooting:"
  echo "  1. Is your phone plugged in via USB?"
  echo "  2. Is USB Debugging enabled? (Settings > Developer Options > USB Debugging)"
  echo "  3. Did you tap 'Allow' on the USB debugging prompt on your phone?"
  echo ""
  adb devices
  exit 1
fi

if [[ "$DEVICE_COUNT" -gt 1 ]]; then
  echo "Multiple Android devices detected:"
  echo ""
  INDEX=1
  while IFS=$'\t' read -r SERIAL STATE; do
    MODEL=$(adb -s "$SERIAL" shell getprop ro.product.model 2>/dev/null || echo "unknown")
    echo "  [$INDEX] $MODEL ($SERIAL)"
    INDEX=$((INDEX + 1))
  done <<< "$DEVICES"
  echo ""
  read -rp "Choose device number (or 'q' to quit): " CHOICE
  [[ "$CHOICE" == "q" ]] && exit 0
  DEVICE_SERIAL=$(echo "$DEVICES" | sed -n "${CHOICE}p" | cut -f1)
  [[ -z "$DEVICE_SERIAL" ]] && echo "ERROR: Invalid choice." && exit 1
else
  DEVICE_SERIAL=$(echo "$DEVICES" | head -1 | cut -f1)
fi

# ---- Print device info ----

MODEL=$(adb -s "$DEVICE_SERIAL" shell getprop ro.product.model 2>/dev/null || echo "unknown")
ANDROID_VER=$(adb -s "$DEVICE_SERIAL" shell getprop ro.build.version.release 2>/dev/null || echo "unknown")
SDK_VER=$(adb -s "$DEVICE_SERIAL" shell getprop ro.build.version.sdk 2>/dev/null || echo "unknown")

echo "========================================"
echo "  Device:   $MODEL"
echo "  Android:  $ANDROID_VER (API $SDK_VER)"
echo "  Serial:   $DEVICE_SERIAL"
echo "========================================"
echo ""

# ---- Run ----

EXTRA_ARGS=""

if [[ "${1:-}" == "--release" ]]; then
  EXTRA_ARGS="--release"
  echo "Building RELEASE APK..."
elif [[ "${1:-}" == "--profile" ]]; then
  EXTRA_ARGS="--profile"
  echo "Building PROFILE mode..."
else
  echo "Running in DEBUG mode (hot reload enabled)..."
  echo "  Press 'r' for hot reload, 'R' for restart, 'q' to quit"
  echo ""
fi

cd "$PROJECT_DIR"
flutter run -d "$DEVICE_SERIAL" $EXTRA_ARGS
