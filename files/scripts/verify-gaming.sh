#!/usr/bin/env bash
# halcyon verify — gaming: RPM Fusion window delivered steam/gamescope/lutris
# with the NVIDIA driver chain excluded. Mutates nothing.
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
gate "gaming packages" rpm -q steam steam-devices gamescope lutris mangohud gamemode zenity input-remapper evtest usbip ydotool
gate "32-bit mangohud" rpm -q mangohud.i686
gate "steam binary" test -x /usr/bin/steam
gate "rpmfusion repo cleaned" sh -c '! ls /etc/yum.repos.d/ | grep -qi rpmfusion'
echo "::endgroup::"

[ "$fail" = 0 ] || {
  echo "::error::gaming-verify failed"
  exit 1
}
echo "--- verify-gaming: all checks passed ---"
