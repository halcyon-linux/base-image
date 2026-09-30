#!/usr/bin/env bash
# halcyon build step — devtools (Stage 05): Fedora + halcyon-cli builds.
# Three Fedora groups, one transaction each: a bad name in one group must not
# abort the others. lazygit, starship, yazi, zellij, bun, pixi and opencode
# resolve from COPR aahsnr-work/halcyon-cli via the staged priority-1 repos
# (they replaced the retired Homebrew payload); the rest resolve from Fedora.
# The rpm -q loop is the devtools verify (inline, no separate gate file).
set -euo pipefail

echo "████ STAGE 05/13 · devtools · Fedora devtools + halcyon-cli ████"

echo "::group::devtools — cli-tools/devtools/misc (Fedora + halcyon-cli)"
echo "  INFO  installing cli-tools group"
readarray -t PKGS_CLI_TOOLS < <(jq -r '.all.include.cli-tools[]' /tmp/files/packages.json)
dnf5 -y --setopt=install_weak_deps=False install "${PKGS_CLI_TOOLS[@]}"
echo "  OK    cli-tools transaction done"
echo "  INFO  installing devtools group"
readarray -t PKGS_DEVTOOLS < <(jq -r '.all.include.devtools[]' /tmp/files/packages.json)
dnf5 -y --setopt=install_weak_deps=False install "${PKGS_DEVTOOLS[@]}"
echo "  OK    devtools transaction done"
echo "  INFO  installing misc group"
readarray -t PKGS_MISC < <(jq -r '.all.include.misc[]' /tmp/files/packages.json)
dnf5 -y --setopt=install_weak_deps=False install "${PKGS_MISC[@]}"
echo "  OK    misc transaction done"

for pkg in "${PKGS_CLI_TOOLS[@]}" "${PKGS_DEVTOOLS[@]}" "${PKGS_MISC[@]}"; do
  rpm -q "${pkg%%.i686}" >/dev/null 2>&1 || { echo "  FAIL  devtools package not installed after transaction: ${pkg}" >&2; exit 1; }
done
echo "::endgroup::"

/tmp/files/scripts/lib/cleanup.sh
echo "--- devtools complete ---"