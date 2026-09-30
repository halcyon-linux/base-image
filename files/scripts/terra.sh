#!/usr/bin/env bash
# halcyon build step — terra (Stage 04): Terra packages with exclusive
# resolution. Every transaction resolves from TERRA REPOS ONLY
# (--disablerepo='*' --enablerepo='terra*'), never as a Fedora fallback; a
# package missing from Terra fails the build loudly. Terra is enabled only
# for this window and disabled immediately after (finalize sweeps leftovers).
# NOTE (2026-09-29): zed, zen-browser, the nerd fonts, starship, yazi, zellij
# and lazygit moved to the halcyon group repos — the group now holds only the
# packages no halcyon project builds. terra-release{-mesa,-multimedia} are the
# repo bootstrap and stay hardcoded, not catalog entries.
set -euo pipefail

echo "████ STAGE 04/13 · terra · Terra-only resolution ████"
FEDORA_MAJOR="$(rpm -E %fedora)"
dnf5 -y --setopt=install_weak_deps=False install --nogpgcheck \
    --disablerepo='*' --enablerepo='terra' \
    --repofrompath "terra,https://repos.fyralabs.com/terra${FEDORA_MAJOR}" \
    terra-release
dnf5 -y --setopt=install_weak_deps=False install --nogpgcheck \
    --disablerepo='*' --enablerepo='terra' \
    --repofrompath "terra,https://repos.fyralabs.com/terra${FEDORA_MAJOR}" \
    terra-release-mesa \
    terra-release-multimedia \
    || true
sed -i '/^priority=/d' /etc/yum.repos.d/terra*.repo 2>/dev/null || true
readarray -t PKGS_TERRA < <(jq -r '.all.include.terra[]' /tmp/files/packages.json)
dnf5 -y --setopt=install_weak_deps=False install \
    --disablerepo='*' --enablerepo='terra*' \
    "${PKGS_TERRA[@]}"
for pkg in "${PKGS_TERRA[@]}"; do
  rpm -q "${pkg%%.i686}" >/dev/null 2>&1 || { echo "  FAIL  terra package not installed: ${pkg}" >&2; exit 1; }
done
dnf5 -y config-manager setopt "terra.enabled=0" 2>/dev/null || true
for f in /etc/yum.repos.d/terra*.repo; do [ -f "${f}" ] && sed -i 's/^enabled=1/enabled=0/' "${f}"; done
echo "  OK    terra packages installed and Terra disabled"

/tmp/files/scripts/lib/cleanup.sh
echo "--- terra complete ---"