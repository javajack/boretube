#!/usr/bin/env bash
# Stock YouTube on/off for user 0 (factory copy stays on the TV).  TV=... ./youtube.sh on|off
source "$(dirname "$0")/lib.sh"
case ${1:-} in
  on)  tv cmd package install-existing com.google.android.youtube.tv; tv pm enable com.google.android.youtube.tvmusic ;;
  off) tv am force-stop com.google.android.youtube.tv; tv pm uninstall -k --user 0 com.google.android.youtube.tv
       tv pm disable-user --user 0 com.google.android.youtube.tvmusic ;;
  *) echo "usage: $0 on|off"; exit 2 ;;
esac
reload_lists; echo "stock YouTube: $(state com.google.android.youtube.tv)"
