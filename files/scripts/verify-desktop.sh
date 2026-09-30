#!/usr/bin/env bash
# halcyon verify — desktop: the Hyprland + Noctalia + greeter stack landed.
# The overlay files (greetd config, PAM) must have survived the greetd RPM
# install (config(noreplace) keeps overlays as verified on fedora-bootc:44).
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

echo "::group::verify-desktop"
gate "hyprland stack" rpm -q hyprland-git hyprland-guiutils hyprland-protocols hyprlang hyprutils aquamarine hyprcursor hyprgraphics xdg-desktop-portal-hyprland xdg-desktop-portal-gtk
gate "noctalia + greeter" rpm -q noctalia-git noctalia-greeter-git greetd
gate "session tooling" rpm -q gnome-keyring pyprland qt6ct nwg-look nwg-displays adw-gtk3 papirus-icon-theme wl-clipboard cliphist
gate "thunar set" rpm -q Thunar thunar-archive-plugin thunar-volman
gate "Hyprland binary" test -x /usr/bin/Hyprland
gate "greeter session wrapper" test -x /usr/bin/noctalia-greeter-session
gate "overlay greetd config survived" grep -q noctalia-greeter-session /etc/greetd/config.toml
gate "overlay PAM keyring survived" grep -q pam_gnome_keyring.so /etc/pam.d/greetd
gate "greeter state tmpfiles" test -f /usr/lib/tmpfiles.d/noctalia-greeter-state.conf
gate "vendor repo cleaned" sh -c '! ls /etc/yum.repos.d/ | grep -qi halcyon-base-pkgs'
echo "::endgroup::"

[ "$fail" = 0 ] || {
  echo "::error::desktop-verify failed"
  exit 1
}
echo "--- verify-desktop: all checks passed ---"
