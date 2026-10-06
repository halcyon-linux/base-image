#!/usr/bin/env bash
# halcyon verify — nix: winter-pattern nix with the /var/nix bind-mount
# contract (var-nix.service creates /var/nix, nix.mount binds it to /nix,
# nix-daemon serves it). Mutates nothing.
set -uo pipefail

echo "████ verify · nix ████"

# shellcheck source=files/scripts/lib/verify.sh
source /tmp/files/scripts/lib/verify.sh

echo "::group::verify-nix"
gate "nix packages" rpm -q nix nix-daemon
gate "nix-daemon enabled" systemctl is-enabled nix-daemon
gate "var-nix.service enabled" systemctl is-enabled var-nix.service
gate "nix.mount enabled" systemctl is-enabled nix.mount
gate "units shipped by overlay" sh -c 'test -f /usr/lib/systemd/system/var-nix.service && test -f /usr/lib/systemd/system/nix.mount'
gate "tmpfiles contract" grep -q '/var/nix' /usr/lib/tmpfiles.d/zz-halcyon-nix.conf
gate "HOME resolution hook" test -f /etc/profile.d/01-nix-resolve-home-env.sh
echo "::endgroup::"

[ "$fail" = 0 ] || {
  echo "::error::nix-verify failed"
  exit 1
}
echo "--- verify-nix: all checks passed ---"
