#!/usr/bin/env bash
# Report drift after firmware/Play updates; --fix re-disables what came back.
#   TV=... ./check.sh profiles/sony-bravia-vu3.txt [--extras] [--fix]
source "$(dirname "$0")/lib.sh"
PROFILE=${1:?profile file}; shift
EXTRAS=no; FIX=no
for a in "$@"; do case $a in --extras) EXTRAS=yes;; --fix) FIX=yes;; esac; done
drift=0
for p in $(packages "$PROFILE" $EXTRAS); do
  s=$(state "$p"); [ "$s" = enabled ] || continue
  drift=$((drift+1)); echo "came back: $p"
  [ $FIX = yes ] && ! never_touch "$p" && tv pm disable-user --user 0 "$p"
done
reload_lists; yt=$(state com.google.android.youtube.tv); echo "stock YouTube: $yt"
tts=$(tv dumpsys package com.google.android.tts | grep -m1 versionName | sed 's/.*=//')
echo "speech services: $tts"
case $tts in *20251028*) ;; *) echo "  !! not the known-good build on VU3; roll back: ./speech-rollback.sh";; esac
echo "$drift package(s) re-enabled since cleanup"
