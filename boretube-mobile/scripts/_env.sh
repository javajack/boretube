#!/usr/bin/env bash
#
# _env.sh — Shared environment setup for Boretube build scripts.
# Source this, don't execute it directly.
#

# ---- Detect / set JAVA_HOME ----

if [[ -z "${JAVA_HOME:-}" ]] || ! "$JAVA_HOME/bin/java" -version &>/dev/null; then
  if [[ -d "$HOME/development/jdk-17.0.2" ]]; then
    export JAVA_HOME="$HOME/development/jdk-17.0.2"
  elif command -v java &>/dev/null; then
    export JAVA_HOME="$(dirname "$(dirname "$(readlink -f "$(command -v java)")")")"
  else
    echo "ERROR: No JDK found. Install JDK 17 or set JAVA_HOME."
    exit 1
  fi
fi

# ---- Detect / set ANDROID_HOME ----

if [[ -z "${ANDROID_HOME:-}" ]] || [[ ! -d "${ANDROID_HOME:-}" ]]; then
  if [[ -d "$HOME/Android/Sdk" ]]; then
    export ANDROID_HOME="$HOME/Android/Sdk"
  elif [[ -d "$HOME/Library/Android/sdk" ]]; then
    export ANDROID_HOME="$HOME/Library/Android/sdk"
  else
    echo "ERROR: No Android SDK found. Set ANDROID_HOME."
    exit 1
  fi
fi

# ---- Detect / set Flutter ----

FLUTTER_BIN=""
if [[ -x "$HOME/development/flutter/bin/flutter" ]]; then
  FLUTTER_BIN="$HOME/development/flutter/bin/flutter"
elif command -v flutter &>/dev/null; then
  FLUTTER_BIN="$(command -v flutter)"
else
  echo "ERROR: Flutter not found. Install Flutter or add it to PATH."
  exit 1
fi

export PATH="$(dirname "$FLUTTER_BIN"):$JAVA_HOME/bin:$ANDROID_HOME/platform-tools:$PATH"

# ---- Project dir ----

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# ---- Device helper ----

_detect_device() {
  local devices count

  # Get list of authorized device serials (one per line)
  devices="$(adb devices 2>/dev/null | awk '/\tdevice$/{print $1}')"

  if [[ -z "$devices" ]]; then
    echo "ERROR: No Android device connected."
    echo "  - Is USB debugging enabled?"
    echo "  - Did you authorize this computer?"
    adb devices
    return 1
  fi

  # Count devices
  count=0
  while IFS= read -r _; do count=$((count + 1)); done <<< "$devices"

  if [[ "$count" -gt 1 ]]; then
    echo "Multiple devices found:"
    local i=1
    while IFS= read -r serial; do
      local model
      model=$(adb -s "$serial" shell getprop ro.product.model 2>/dev/null || echo "unknown")
      echo "  [$i] $model ($serial)"
      i=$((i + 1))
    done <<< "$devices"
    read -rp "Choose [1-$count]: " choice
    DEVICE_SERIAL=$(echo "$devices" | sed -n "${choice}p")
    [[ -z "$DEVICE_SERIAL" ]] && echo "Invalid choice." && return 1
  else
    DEVICE_SERIAL="$devices"
  fi

  local model android_ver
  model=$(adb -s "$DEVICE_SERIAL" shell getprop ro.product.model 2>/dev/null || echo "unknown")
  android_ver=$(adb -s "$DEVICE_SERIAL" shell getprop ro.build.version.release 2>/dev/null || echo "?")

  echo "Device: $model (Android $android_ver) [$DEVICE_SERIAL]"
}
