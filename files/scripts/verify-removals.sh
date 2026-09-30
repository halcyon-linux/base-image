#!/usr/bin/env bash
# halcyon verify — removals: the base's GNOME/Steam-Deck leftovers and
# firefox/nano are really gone after the dnf remove block + guarded-removals
# + fonts-cleanup. Runs BEFORE any module installs, so there are deliberately
# no "keeper installed" gates here — final-verify.sh owns the keeper set at
# end state. Mutates nothing.
set -uo pipefail

echo "████ verify · removals ████"

fail=0
gate() {
  local desc="$1"
  shift
  if "$@" >/dev/null 2>&1; then echo "  PASS  $desc"; else
    echo "  FAIL  $desc"
    fail=1
  fi
}

# Succeeds only when EVERY named package is absent.
all_absent() {
  local p
  for p in "$@"; do
    rpm -q "$p" >/dev/null 2>&1 && return 1
  done
  return 0
}

echo "::group::verify-removals"
gate "GNOME stack gone" all_absent gnome-shell gdm mutter gnome-session nautilus ptyxis gnome-control-center gnome-settings-daemon gjs xdg-desktop-portal-gnome
gate "firefox + langpacks gone" all_absent firefox firefox-langpacks
gate "nano gone" all_absent nano nano-default-editor
gate "steam-deck leftovers gone" all_absent inputplumber steamos-manager-powerstation jupiter-fan-control jupiter-hw-support-btrfs galileo-mura steamdeck-dsp powerbuttond vpower sdgyrodsu steamdeck-backgrounds steamdeck-gnome-presets
gate "waydroid gone" all_absent waydroid
gate "dnf still functional" dnf5 --version
echo "::endgroup::"

[ "$fail" = 0 ] || {
  echo "::error::removals-verify failed"
  exit 1
}
echo "--- verify-removals: all checks passed ---"
