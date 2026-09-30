#!/usr/bin/env bash
# halcyon verify — hardware: firmware, audio and the 32-bit mesa pair for
# Steam/Proton landed. Mutates nothing.
set -uo pipefail

echo "████ verify · hardware ████"

fail=0
gate() {
  local desc="$1"
  shift
  if "$@" >/dev/null 2>&1; then echo "  PASS  $desc"; else
    echo "  FAIL  $desc"
    fail=1
  fi
}

echo "::group::verify-hardware"
gate "firmware set" rpm -q linux-firmware microcode_ctl intel-gpu-firmware nvidia-gpu-firmware atheros-firmware realtek-firmware iwlwifi-mvm-firmware
gate "audio stack" rpm -q pipewire pipewire-alsa pipewire-pulseaudio wireplumber alsa-ucm alsa-sof-firmware
gate "network" rpm -q NetworkManager-wifi wpa_supplicant
gate "smartcard" rpm -q pcsc-lite pcsc-lite-ccid
gate "64-bit mesa" rpm -q mesa-dri-drivers mesa-vulkan-drivers mesa-libEGL mesa-libGL
gate "32-bit mesa (Steam/Proton)" rpm -q mesa-dri-drivers.i686 mesa-vulkan-drivers.i686 mesa-libEGL.i686 mesa-libGL.i686
echo "::endgroup::"

[ "$fail" = 0 ] || {
  echo "::error::hardware-verify failed"
  exit 1
}
echo "--- verify-hardware: all checks passed ---"
