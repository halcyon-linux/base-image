#!/usr/bin/env bash
# halcyon verify — removals: the base's KDE Plasma stack, the packages.md
# checked set, nano and the input-method frameworks are really gone after the
# dnf remove block + guarded-removals + fonts-cleanup. Runs BEFORE any module
# installs, so there are deliberately no "keeper installed" gates here —
# final-verify.sh owns the keeper set at end state. Mutates nothing.
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
gate "KDE Plasma stack gone" all_absent plasma-workspace plasma-desktop kwin konsole dolphin kate kwrite spectacle kscreenlocker ksshaskpass kwalletmanager5 polkit-kde powerdevil breeze-icon-theme plasma-login-manager steamdeck-kde-presets-desktop xdg-desktop-portal-kde
gate "GNOME stack gone" all_absent gnome-shell gdm mutter gnome-session ptyxis gnome-control-center gnome-settings-daemon gjs xdg-desktop-portal-gnome
gate "firefox + langpacks gone" all_absent firefox firefox-langpacks
gate "nano gone" all_absent nano nano-default-editor
gate "steam-deck leftovers gone" all_absent inputplumber steamos-manager-powerstation jupiter-fan-control jupiter-hw-support-btrfs galileo-mura steamdeck-dsp powerbuttond vpower sdgyrodsu steamdeck-backgrounds steamdeck-gnome-presets
gate "waydroid gone" all_absent waydroid waydroid-nvidia
gate "packages.md checked set gone" all_absent rom-properties ryzen_smu ryzenadj signon system76-driver system76-io tesseract-libs twitter-twemoji-fonts urw-base35-fonts vlc-libs zenergy
gate "input-method frameworks gone" all_absent ibus fcitx5 fcitx5-configtool
# Fonts pulled back in by later packages as deps are ACCEPTED (user decision)
# — the sweep is best-effort, so there is deliberately no font-absence gate.
# The gaming/media stack is the opposite: it must REMAIN (user decision) —
# protect-media-stack.sh marks it user-installed so the cascade cannot take
# it; these are the canaries the broken runs actually lost.
gate "media stack kept" rpm -q mesa-libEGL libglvnd-egl mesa-libGL gstreamer1-plugins-base gstreamer1-plugins-good ffmpeg-libs libavcodec pipewire-libs
gate "greetd + noctalia-greeter gone" all_absent greetd noctalia-greeter-git
gate "Thunar suite gone" all_absent Thunar thunar-archive-plugin thunar-media-tags-plugin thunar-vcs-plugin thunar-volman
gate "noscripts drop-in unstaged (install stages need %post)" test ! -e /etc/dnf/libdnf5.conf.d/99-halcyon-erase-noscripts.conf
gate "dnf still functional" dnf5 --version
echo "::endgroup::"

[ "$fail" = 0 ] || {
  echo "::error::removals-verify failed"
  exit 1
}
echo "--- verify-removals: all checks passed ---"
