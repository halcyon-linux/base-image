#!/usr/bin/env bash
# halcyon verify — core: the base desktop/tool set (and the custom-environment
# group) landed. Mutates nothing.
set -uo pipefail

echo "████ verify · core ████"

fail=0
gate() {
  local desc="$1"
  shift
  if "$@" >/dev/null 2>&1; then echo "  PASS  $desc"; else
    echo "  FAIL  $desc"
    fail=1
  fi
}

echo "::group::verify-core"
gate "core packages" rpm -q git curl zsh podman just fastfetch ImageMagick gnupg2 distrobox btop ethtool wget2-wget hostname
gate "flatpak/portal base" rpm -q xdg-desktop-portal xdg-user-dirs
gate "plymouth base" rpm -q plymouth plymouth-theme-spinner
gate "cockpit set" rpm -q cockpit-system cockpit-networkmanager cockpit-podman cockpit-files cockpit-storaged cockpit-selinux
gate "selinux tooling" rpm -q policycoreutils-python-utils setools-console udica
gate "binaries on PATH" sh -c 'command -v git && command -v curl && command -v zsh && command -v just && command -v podman && command -v fastfetch'
echo "::endgroup::"

[ "$fail" = 0 ] || {
  echo "::error::core-verify failed"
  exit 1
}
echo "--- verify-core: all checks passed ---"
