#!/usr/bin/env bash
# halcyon build step — nix (Stage 06): winter pattern
# (https://github.com/fu5ha/winter recipes/modules/nix.yaml). The same files
# ship via the static overlay (usr/lib/tmpfiles.d/zz-halcyon-nix.conf,
# etc/profile.d/01-nix-resolve-home-env.sh, systemd/{var-nix,nix.mount});
# the enablement of var-nix.service + nix.mount lives in the ujust-system
# module with the other unit wiring.
set -euo pipefail

echo "████ STAGE 06/13 · nix · winter pattern ████"
readarray -t PKGS_NIX < <(jq -r '.all.include.nix[]' /tmp/files/packages.json)
dnf5 -y --setopt=install_weak_deps=False install "${PKGS_NIX[@]}"
{ systemctl enable nix-daemon 2>/dev/null \
    || ln -sf /usr/lib/systemd/system/nix-daemon.service /usr/lib/systemd/system/multi-user.target.wants/nix-daemon.service; }

echo "::group::nix-verify — winter pattern wiring"
rpm -q nix nix-daemon || { echo "  FAIL  nix packages missing" >&2; exit 1; }
test -f /usr/lib/systemd/system/var-nix.service || { echo "  FAIL  var-nix.service missing" >&2; exit 1; }
test -f /usr/lib/systemd/system/nix.mount || { echo "  FAIL  nix.mount missing" >&2; exit 1; }
grep -q "1775 root nixbld" /usr/lib/tmpfiles.d/zz-halcyon-nix.conf || { echo "  FAIL  nix tmpfiles rule missing" >&2; exit 1; }
test -f /etc/profile.d/01-nix-resolve-home-env.sh || { echo "  FAIL  nix profile.d hook missing" >&2; exit 1; }
systemctl is-enabled nix-daemon >/dev/null 2>&1 || { echo "  FAIL  nix-daemon not enabled" >&2; exit 1; }
echo "  OK    nix wiring verified"
echo "::endgroup::"

/tmp/files/scripts/lib/cleanup.sh
echo "--- nix complete ---"