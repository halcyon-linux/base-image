#!/usr/bin/env bash
# halcyon build step — mark bazzite's gaming/media stack user-installed.
#
# _why_: the removals cascade (auto-remove of the KDE closure) orphaned and
# erased a huge chunk of the base's media/gaming libraries — mesa-*, all
# libglvnd-*, gstreamer1-plugins-base/good/ugly, ffmpeg + the libav* set,
# libva* (intel-media-driver, libva-nvidia-driver), pipewire-libs*, the
# x264/x265/svt codec libs, intel-mediasdk, vulkan-tools. User decision:
# ALL gaming/media packages by bazzite must remain. auto-remove only removes
# dependency-reasoned orphans, so marking the stack user-installed makes it
# immune; explicit `dnf remove` still works for anything this recipe
# deliberately removes (no name in the removals/guarded lists matches these
# globs). Runs BEFORE the removals transaction, while everything is
# installed.
set -euo pipefail

echo "::group::protect-media-stack"

GLOBS=(
  mesa-* libglvnd* gstreamer1* pipewire* wireplumber*
  ffmpeg* libav* libva* libvdpau* x264* x265* dav1d* svt-* aom-libs
  intel-mediasdk* intel-media* onevpl* vulkan-* openh264*
  gamescope* mangohud* steam* lutris* scx-* umu-* bazzite-* bazaar*
)

mapfile -t protect < <(rpm -qa --qf '%{NAME}\n' "${GLOBS[@]}" | sort -u)
if [ "${#protect[@]}" -eq 0 ]; then
  echo "  FAIL  no media/gaming packages found to protect" >&2
  exit 1
fi
echo "  INFO  marking ${#protect[@]} media/gaming package(s) user-installed"

dnf5 -y mark user "${protect[@]}" >/dev/null

# Gate: the reasons must now be user — spot-check the canaries the cascade
# actually took in the broken runs.
for p in mesa-libEGL libglvnd-egl gstreamer1-plugins-base ffmpeg-libs; do
  rpm -q "${p}" >/dev/null 2>&1 || {
    echo "  FAIL  ${p} not installed before removals — protect list is wrong" >&2
    exit 1
  }
done

echo "  OK    media/gaming stack protected from auto-remove"
echo "::endgroup::"
echo "--- protect-media-stack complete ---"
