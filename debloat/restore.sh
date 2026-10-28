#!/usr/bin/env bash
# Re-enable a profile's packages (back to stock for that list). Dry run unless --yes.
#   TV=... ./restore.sh profiles/sony-bravia-vu3.txt [--extras] [--youtube] [--yes]
source "$(dirname "$0")/lib.sh"
PROFILE=${1:?profile file}; shift
EXTRAS=no; YES=no; YT=no
for a in "$@"; do case $a in --extras) EXTRAS=yes;; --yes) YES=yes;; --youtube) YT=yes;; esac; done
for p in $(packages "$PROFILE" $EXTRAS); do
  s=$(state "$p"); [ "$s" = disabled ] || { echo "ok   $p ($s)"; continue; }
  if [ $YES = yes ]; then echo "ENABLE $p: $(tv pm enable "$p")"; else echo "would enable $p"; fi
done
if [ $YT = yes ]; then
  if [ $YES = yes ]; then tv cmd package install-existing com.google.android.youtube.tv; else echo "would restore stock YouTube"; fi
fi
