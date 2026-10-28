#!/usr/bin/env bash
# Roll Google Speech Services back to the factory build (fixes SIGILL crash on Realtek 32-bit).
source "$(dirname "$0")/lib.sh"
tv dumpsys package com.google.android.tts | grep -m1 versionName
tv pm uninstall-system-updates com.google.android.tts
tv dumpsys package com.google.android.tts | grep -m1 versionName
