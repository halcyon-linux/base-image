#!/usr/bin/env bash
# halcyon verify — flatpaks: the zero-flatpak enforcement is shipped in the
# image (halcyon-flatpak-setup.service + the libexec script with the baked
# app list and the unused-runtime sweep). The removals themselves run on the
# BOOTED system — a build container cannot assert /var/lib/flatpak end
# state. The bazzite-service masks AND the unit enablement are ujust-stage
# state; final-verify.sh owns them at end state. Mutates nothing.
set -uo pipefail

echo "████ verify · flatpaks ████"

# shellcheck source=files/scripts/lib/verify.sh
source /tmp/files/scripts/lib/verify.sh

SCRIPT=/usr/libexec/halcyon-image/flatpak-setup

# Every ref the baked removal list must carry — apps AND runtime-type
# extensions (the OBS plugins and VulkanLayers are runtime-type; an
# --app-only match never sees them).
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
  org.freedesktop.Platform
  org.freedesktop.Platform.Compat.i386
  org.freedesktop.Platform.GL.default
  org.freedesktop.Platform.GL32.default
  org.freedesktop.Platform.VulkanLayer.MangoHud
  org.freedesktop.Platform.VulkanLayer.OBSVkCapture
  org.freedesktop.Platform.VulkanLayer.vkBasalt
  org.freedesktop.Platform.codecs-extra
  org.gnome.Platform
  org.kde.KStyle.Adwaita
  org.kde.Platform
)

remove_list_has_all() {
  local id
  for id in "$@"; do
    # the IDs live indented inside the script's FLATPAK_IDS array — strip
    # leading whitespace before the exact-line match (grep -x anchors to
    # the whole line, so an indented line never matches a bare ID)
    sed 's/^[[:space:]]*//' "${SCRIPT}" | grep -Fxq "${id}" || return 1
  done
}

echo "::group::verify-flatpaks"
gate "flatpak-setup script shipped" test -x "${SCRIPT}"
gate "unit shipped" test -f /usr/lib/systemd/system/halcyon-flatpak-setup.service
gate "removal list carries the full app set" remove_list_has_all "${FLATPAK_IDS[@]}"
gate "unused-runtime sweep wired" grep -qF -- '--unused' "${SCRIPT}"
gate "auto-pin cleanup wired (pinned refs survive --unused)" \
  grep -qF 'flatpak pin --system --remove' "${SCRIPT}"
# Enablement is NOT gated here: halcyon-flatpak-setup.service is enabled by
# the ujust systemd module, which runs AFTER this module — final-verify.sh
# owns the is-enabled check at end state.
echo "::endgroup::"

[ "$fail" = 0 ] || {
  echo "::error::flatpaks-verify failed"
  exit 1
}
echo "--- verify-flatpaks: all checks passed ---"
