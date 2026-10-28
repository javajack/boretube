#!/usr/bin/env bash
# Disable a profile's packages (reversible). Dry run unless --yes.
#   TV=192.168.1.3:5555 ./apply.sh profiles/sony-bravia-vu3.txt [--extras] [--yes]
source "$(dirname "$0")/lib.sh"
PROFILE=${1:?profile file}; shift
EXTRAS=no; YES=no
for a in "$@"; do case $a in --extras) EXTRAS=yes;; --yes) YES=yes;; esac; done
[ $YES = yes ] && echo "Snapshot: $("$HERE/snapshot.sh")"
for p in $(packages "$PROFILE" $EXTRAS); do
  if never_touch "$p"; then echo "SKIP never-touch $p"; continue; fi
  s=$(state "$p")
  if [ "$s" != enabled ]; then echo "ok   $p ($s)"; continue; fi
  if [ $YES = yes ]; then echo "DISABLE $p: $(tv pm disable-user --user 0 "$p")"; else echo "would disable $p"; fi
done
[ $YES = yes ] && echo "Done. Wait >=60 s before any reboot (package state is saved lazily)."
