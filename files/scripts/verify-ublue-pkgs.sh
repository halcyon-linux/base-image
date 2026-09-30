#!/usr/bin/env bash
# halcyon verify — ublue-pkgs: the ujust/uupd machinery from COPR
# ublue-os/packages landed. Mutates nothing.
set -uo pipefail

echo "████ verify · ublue-pkgs ████"

fail=0
gate() {
  local desc="$1"
  shift
  if "$@" >/dev/null 2>&1; then echo "  PASS  $desc"; else
    echo "  FAIL  $desc"
    fail=1
  fi
}

echo "::group::verify-ublue-pkgs"
gate "ublue packages" rpm -q ublue-os-just ublue-os-luks ublue-os-signing ublue-recipes uupd bazaar
gate "ujust binary" test -x /usr/bin/ujust
gate "justfile present" test -f /usr/share/ublue-os/justfile
gate "ujust.sh library" test -f /usr/lib/ujust/ujust.sh
gate "default recipes" test -f /usr/share/ublue-os/just/00-default.just
gate "uupd timer unit" test -f /usr/lib/systemd/system/uupd.timer
gate "repo cleaned" sh -c '! ls /etc/yum.repos.d/ | grep -qi ublue'
echo "::endgroup::"

[ "$fail" = 0 ] || {
  echo "::error::ublue-pkgs-verify failed"
  exit 1
}
echo "--- verify-ublue-pkgs: all checks passed ---"
