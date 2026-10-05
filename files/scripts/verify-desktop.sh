#!/usr/bin/env bash
# halcyon verify — desktop: the Hyprland + Noctalia stack landed and the
# retired greeter/file-manager stack is really gone. greetd/noctalia-greeter
# and the Thunar suite are absence-gated; the polkit agent is Noctalia's own.
# Mutates nothing.
set -uo pipefail

echo "████ verify · desktop ████"

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

echo "::group::verify-desktop"
gate "hyprland stack" rpm -q hyprland-git hyprland-guiutils hyprland-protocols hyprlang hyprutils aquamarine hyprcursor hyprgraphics xdg-desktop-portal-hyprland xdg-desktop-portal-gtk
gate "noctalia shell" rpm -q noctalia-git
gate "session tooling" rpm -q gnome-keyring gnome-keyring-pam pyprland qt6ct nwg-look nwg-displays adw-gtk3 papirus-icon-theme wl-clipboard cliphist
gate "nautilus present" rpm -q nautilus
gate "Hyprland binary" test -x /usr/bin/Hyprland
gate "greeter/file-manager stack gone" all_absent greetd noctalia-greeter-git Thunar thunar-archive-plugin thunar-media-tags-plugin thunar-vcs-plugin thunar-volman
gate "polkit daemon present (agent = noctalia)" rpm -q polkit
gate "vendor repo cleaned" sh -c '! ls /etc/yum.repos.d/ | grep -qi base-pkgs'
echo "::endgroup::"

[ "$fail" = 0 ] || {
  echo "::error::desktop-verify failed"
  exit 1
}
echo "--- verify-desktop: all checks passed ---"
