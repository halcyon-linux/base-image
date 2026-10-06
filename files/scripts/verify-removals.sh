#!/usr/bin/env bash
# halcyon verify — removals: the explicitly removed set is really gone after
# the dnf remove block + guarded-removals + fonts-cleanup. Only names that
# verifiably existed in the base before the sweep are asserted — nothing that
# was never shipped is checked, and the base inventory file is not consulted
# (the gate list mirrors the removals module, not the inventory). The media
# stack must REMAIN (see the exclusion in erase-noscripts-on.sh). Mutates
# nothing.
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
gate "nano gone" all_absent nano nano-default-editor
gate "waydroid-nvidia gone" all_absent waydroid-nvidia
gate "explicit removals gone" all_absent rom-properties ryzen_smu ryzenadj signon system76-driver system76-io twitter-twemoji-fonts vlc-libs zenergy
# tesseract-libs/-common/-langpack-eng/-tessdata-doc are exempt from that
# gate: the protected ffmpeg (libavfilter) hard-requires libtesseract, so
# the minimal tesseract closure stays with the media stack (user decision).
# urw-base35-fonts stays too (kept by decision, no longer removed).
gate "input-method frameworks gone" all_absent ibus fcitx5 fcitx5-configtool
# Fonts pulled back in by later packages as deps are ACCEPTED (user decision)
# — the sweep is best-effort, so there is deliberately no font-absence gate.
# The gaming/media stack is the opposite: it must REMAIN (user decision) —
# the staged removals drop-in excludes it so the auto-remove closure cannot
# select it (dnf5's remove-time cleanup ignores install reasons); these are
# the canaries the broken runs actually lost.
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
