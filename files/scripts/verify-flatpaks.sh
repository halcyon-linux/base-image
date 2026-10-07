#!/usr/bin/env bash
# halcyon verify — flatpaks: the zero-flatpak enforcement is shipped in the
# image (halcyon-flatpak-setup.service + the libexec script with the baked
# app list and the unused-runtime sweep). The removals themselves run on the
# BOOTED system — a build container cannot assert /var/lib/flatpak end
# state. The bazzite-service masks are ujust-stage state; final-verify.sh
# owns them at end state. Mutates nothing.
set -uo pipefail

echo "████ verify · flatpaks ████"

# shellcheck source=files/scripts/lib/verify.sh
source /tmp/files/scripts/lib/verify.sh

SCRIPT=/usr/libexec/halcyon-image/flatpak-setup

# Every app the baked removal list must carry.
FLATPAK_IDS=(
  com.github.Matoking.protontricks
  com.github.tchx84.Flatseal
  com.obsproject.Studio.Plugin.GStreamerVaapi
  com.obsproject.Studio.Plugin.GStreamer
  com.obsproject.Studio.Plugin.OBSVkCapture
  com.vysp3r.ProtonPlus
  io.github.DenysMb.Kontainer
  io.github.flattool.Warehouse
  org.gnome.Firmware
  org.kde.gwenview
  org.kde.haruna
  org.kde.kcalc
  org.kde.okular
  org.mozilla.firefox
)

remove_list_has_all() {
  local id
  for id in "$@"; do
    grep -Fxq "${id}" "${SCRIPT}" || return 1
  done
}

echo "::group::verify-flatpaks"
gate "flatpak-setup script shipped" test -x "${SCRIPT}"
gate "unit shipped" test -f /usr/lib/systemd/system/halcyon-flatpak-setup.service
gate "removal list carries the full app set" remove_list_has_all "${FLATPAK_IDS[@]}"
gate "unused-runtime sweep wired" grep -qF -- '--unused' "${SCRIPT}"
gate "flatpak-setup.service enabled" systemctl is-enabled halcyon-flatpak-setup.service
echo "::endgroup::"

[ "$fail" = 0 ] || {
  echo "::error::flatpaks-verify failed"
  exit 1
}
echo "--- verify-flatpaks: all checks passed ---"
