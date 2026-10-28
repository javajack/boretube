#!/usr/bin/env bash
# Save a restore point of the TV's package/settings state to ~/.boretube/snapshots/.
source "$(dirname "$0")/lib.sh"
D=~/.boretube/snapshots/$(date +%Y%m%d-%H%M%S); mkdir -p "$D"
tv getprop > "$D/getprop.txt"
tv pm list packages -f -u > "$D/packages-all.txt"
tv pm list packages -d > "$D/packages-disabled.txt"
tv pm list packages -3 > "$D/packages-thirdparty.txt"
for ns in global secure system; do tv settings list $ns > "$D/settings-$ns.txt"; done
tv cmd package resolve-activity --brief -c android.intent.category.HOME -a android.intent.action.MAIN > "$D/home.txt"
tv dumpsys package com.google.android.tts | grep -m1 versionName > "$D/tts.txt" || true
echo "$D"
