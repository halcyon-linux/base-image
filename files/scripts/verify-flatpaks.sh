#!/usr/bin/env bash
# halcyon verify — flatpaks: the default-flatpaks state is shipped in the
# image and bazzite's own flatpak integration is fully masked. The flatpak
# removals themselves are enforced on the BOOTED system by
# system-flatpak-setup.timer — a build container cannot assert
# /var/lib/flatpak end state, so these gates check the image-shipped
# configuration instead. Mutates nothing.
set -uo pipefail

echo "████ verify · flatpaks ████"

# shellcheck source=files/scripts/lib/verify.sh
source /tmp/files/scripts/lib/verify.sh

REMOVE_LIST=/usr/share/bluebuild/default-flatpaks/system/remove

# The full screenshot set the module must enforce (apps + runtime refs).
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
    grep -Fxq "$id" "$REMOVE_LIST" || return 1
  done
}

# bazzite's flatpak machinery must never run (flatpaks.yml owns the state).
mask_unit() {
  test "$(readlink "/etc/systemd/system/$1")" = /dev/null
}

echo "::group::verify-flatpaks"
gate "default-flatpaks remove list exists" test -f "$REMOVE_LIST"
gate "remove list carries the full set" remove_list_has_all "${FLATPAK_IDS[@]}"
gate "no system repo forced (remote-add skipped at boot)" \
  grep -q '"repo-url": "null"' /usr/share/bluebuild/default-flatpaks/system/repo-info.json
gate "no user repo forced (user timer neutralized)" \
  grep -q '"repo-url": "null"' /usr/share/bluebuild/default-flatpaks/user/repo-info.json
gate "boot notifications disabled" grep -qx false /usr/share/bluebuild/default-flatpaks/notifications
gate "system-flatpak-setup.timer enabled" systemctl is-enabled system-flatpak-setup.timer
gate "user-flatpak-setup.timer enabled (--global)" \
  systemctl --global is-enabled user-flatpak-setup.timer
for unit in \
  bazzite-flatpak-manager.service \
  ublue-nvidia-flatpak-runtime-sync.service \
  ublue-nvidia-flatpak-runtime-verify.service \
  flatpak-add-fedora-repos.service; do
  gate "$unit masked" mask_unit "$unit"
done
echo "::endgroup::"

[ "$fail" = 0 ] || {
  echo "::error::flatpaks-verify failed"
  exit 1
}
echo "--- verify-flatpaks: all checks passed ---"
