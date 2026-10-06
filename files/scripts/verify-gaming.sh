#!/usr/bin/env bash
# halcyon verify — gaming: the native (RakuOS-model) stack is complete —
# steam/lutris/gamescope/mangohud come from the bazzite base (terra-builds
# ship under terra-* names here), gamemode/heroic-games-launcher install in
# this module, and the base's bazzite-steam wrapper still fronts steam.
# Mutates nothing.
set -uo pipefail

echo "████ verify · gaming ████"

fail=0
gate() {
  local desc="$1"
  shift
  if "$@" >/dev/null 2>&1; then echo "  PASS  $desc"; else
    echo "  FAIL  $desc"
    fail=1
  fi
}

echo "::group::verify-gaming"
gate "base gaming stack" rpm -q steam steam-devices lutris terra-gamescope terra-mangohud zenity input-remapper evtest usbip ydotool
gate "32-bit graphics stack" rpm -q terra-mangohud.i686 mesa-libGL.i686
gate "module installs" rpm -q gamemode heroic-games-launcher
gate "steam binary" test -x /usr/bin/steam
gate "bazzite-steam wrapper present" test -x /usr/bin/bazzite-steam
gate "steam.desktop launched via bazzite-steam" grep -q "bazzite-steam" /usr/share/applications/steam.desktop
gate "terra-gaming repo cleaned" test ! -e /etc/yum.repos.d/terra-gaming.repo
echo "::endgroup::"

[ "$fail" = 0 ] || {
  echo "::error::gaming-verify failed"
  exit 1
}
echo "--- verify-gaming: all checks passed ---"
