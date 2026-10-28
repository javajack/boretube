#!/usr/bin/env bash
# Shared helpers for the debloat scripts. Plain adb only.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TV="${TV:-}"
[ -n "$TV" ] || { echo "Set TV=<ip>:5555 (e.g. TV=192.168.1.3:5555)" >&2; exit 2; }
adb connect "$TV" >/dev/null 2>&1 || true
tv() { adb -s "$TV" shell "$@"; }

# Package names from a profile file; --extras includes lines tagged [extra].
packages() {
  local file=$1 extras=${2:-no}
  grep -vE '^\s*(#|$)' "$file" | while read -r line; do
    pkg=${line%%[[:space:]#]*}
    if [[ $line == *"[extra]"* && $extras != yes ]]; then continue; fi
    [[ $pkg =~ ^[a-zA-Z0-9_.]+$ ]] && echo "$pkg"
  done
}

never_touch() { grep -qxF "$1" <(grep -vE '^\s*(#|$)' "$HERE/profiles/never-touch.txt"); }

# Package lists are read once per run (pm is slow on TVs), then looked up locally.
_lists_loaded=no
load_lists() {
  [ $_lists_loaded = yes ] && return
  ALL=$(tv pm list packages -u | tr -d '\r')
  INSTALLED=$(tv pm list packages | tr -d '\r')
  DISABLED=$(tv pm list packages -d | tr -d '\r')
  _lists_loaded=yes
}
reload_lists() { _lists_loaded=no; load_lists; }

state() { # enabled | disabled | removed | absent
  load_lists
  local p="package:$1"
  grep -qxF "$p" <<<"$ALL" || { echo absent; return; }
  grep -qxF "$p" <<<"$INSTALLED" || { echo removed; return; }
  grep -qxF "$p" <<<"$DISABLED" && echo disabled || echo enabled
}
