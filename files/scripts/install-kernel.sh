#!/usr/bin/env bash
# halcyon build step — install-kernel (Stage 02): p03 kernel + nvidia-open.
#
# Kernel + prebuilt nvidia-open modules: COPR catpieleaf/kernel-p03 (ABI-matched
# by the COPR; Stage K2 moves it to halcyon-packages). NVIDIA userland:
# negativo17 — the only repo on the driver line the COPR modules were built
# for (RPM Fusion's userland mismatches and its xorg-x11-drv-nvidia hard-requires
# nvidia-kmod/akmod-nvidia).
#
# Repo windows (each repo resolves packages only inside its own window):
#   kernel COPR  : enabled only for the kernel transaction
#   negativo17   : enabled only for the userland install + RPM download
#   RPM Fusion   : disabled for every transaction here (not needed by Stage 02)
#
# Three negativo17 subpackages are dependency-entangled with a kmod package and
# can NOT be installed next to the COPR's prebuilt modules:
#   nvidia-driver-cuda, nvidia-kmod-common -> nvidia-kmod (only provider:
#   dkms-nvidia, which Conflicts with kernel-p03-nvidia-open);
#   nvidia-settings -> nvidia-driver (meta) -> nvidia-kmod-common.
# They are payload-extracted file-only via rpm2cpio (GSP firmware, modprobe/
# udev/dracut confs, nvidia-smi, OpenCL ICD, nvidia-settings): no rpmdb entry,
# no dependency chain. Fallback if module/userland versions ever drift: DKMS
# (rakuos-base pattern) — the verify section fails the build on a mismatch.
#
# Kernel/NVIDIA RPMs install with tsflags=noscripts (scriptlets fail in
# containers); depmod runs here, dracut runs in build-initramfs.sh (finish).
set -euo pipefail

echo "████ STAGE 02/13 · kernel-nvidia · p03 + nvidia-open (Stage K1) ████"

NV_REPO=fedora-nvidia
KERNEL_COPR=catpieleaf/kernel-p03
DNF=(dnf5 -y --setopt=install_weak_deps=False --disable-repo='rpmfusion-*')
# enable|disable — dnf5 records this in repos.override.d/99-config_manager.repo;
# the .repo file itself is untouched (finalize.sh deletes it later).
nvidia_repo() { dnf5 -y config-manager "$1" "${NV_REPO}"; }

echo "::group::install-kernel — preflight"
# Fail fast if the negativo17 repo id ever changes, then close its window.
# (Captured, not piped: `dnf5 | grep -q` can SIGPIPE-fail under pipefail.)
REPOS="$(dnf5 -q repolist --all)"
grep -Eq "(^|[[:space:]])${NV_REPO}([[:space:]]|$)" <<<"${REPOS}" ||
  {
    echo "  FAIL  repo '${NV_REPO}' not found (repos module ran?)" >&2
    exit 1
  }
nvidia_repo disable
echo "::endgroup::"

echo "::group::install-kernel — stock kernel out"
# Only pass installed packages: dnf5 aborts the whole transaction on an absent
# argument, which would strand the stock kernel.
readarray -t STOCK < <(rpm -qa --qf '%{NAME}\n' kernel kernel-core kernel-modules \
  kernel-modules-core kernel-modules-extra kernel-tools kernel-tools-libs | sort -u)
# --no-autoremove must follow the remove keyword (dnf5 CLI)
[ "${#STOCK[@]}" -eq 0 ] || dnf5 -y remove --no-autoremove "${STOCK[@]}"
find /boot -mindepth 1 -delete 2>/dev/null || true
find /usr/lib/modules -mindepth 1 -maxdepth 1 -exec rm -rf {} + 2>/dev/null || true
echo "::endgroup::"

echo "::group::install-kernel — p03 kernel + nvidia-open (COPR window)"
# x86-64-v3 builds; the -gcc v2 fallback exists in the same COPR.
dnf5 -y copr enable "${KERNEL_COPR}"
"${DNF[@]}" --setopt=tsflags=noscripts install kernel-p03 kernel-p03-nvidia-open
dnf5 -y copr disable "${KERNEL_COPR}"
echo "::endgroup::"

echo "::group::install-kernel — NVIDIA userland (negativo17 window)"
nvidia_repo enable
# Both arches are spelled out on purpose: with the cuda-libs pair in the same
# transaction dnf5 collapses bare `nvidia-driver-libs` onto the i686 package
# and silently drops the x86_64 one (reproduced 2026-09-20). 32-bit libs are
# for Steam/Proton, CUDA libs for NVENC/DLSS, libva-nvidia-driver for VA-API.
"${DNF[@]}" --setopt=tsflags=noscripts install \
  libva-nvidia-driver nvidia-libXNVCtrl nvidia-modprobe nvidia-persistenced \
  nvidia-driver-cuda-libs.{x86_64,i686} nvidia-driver-libs.{x86_64,i686}

# The package %post skips `semodule` when selinuxenabled is false (always true
# in a build container), so link the policy module into the store explicitly.
"${DNF[@]}" install nvidia-driver-selinux cpio
semodule -i /usr/share/selinux/packages/targeted/nvidia-driver.pp.bz2

# Entangled subpackages: download only, then extract the payload (see header).
install -d /tmp/nkc
dnf5 -y --disable-repo='rpmfusion-*' download --destdir /tmp/nkc \
  nvidia-kmod-common nvidia-driver-cuda nvidia-settings
nvidia_repo disable # NVIDIA userland is complete: close the negativo17 window
echo "::endgroup::"

echo "::group::install-kernel — payload-extract entangled subpackages"
for rpm in /tmp/nkc/nvidia-kmod-common-[0-9]*.noarch.rpm \
  /tmp/nkc/nvidia-driver-cuda-[0-9]*.x86_64.rpm \
  /tmp/nkc/nvidia-settings-[0-9]*.x86_64.rpm; do
  rpm2cpio "${rpm}" | cpio -idmu --quiet -D /tmp/nkc
done
rm -rf /tmp/nkc/usr/lib/.build-id /tmp/nkc/usr/lib64/.build-id
cp -a /tmp/nkc/etc/. /etc/
cp -a /tmp/nkc/usr/. /usr/
chmod 0644 /usr/lib/modprobe.d/nvidia.conf /usr/lib/udev/rules.d/60-nvidia.rules
rm -rf /tmp/nkc

KVER="$(rpm -q --qf '%{VERSION}-%{RELEASE}.%{ARCH}' kernel-p03)"
depmod "${KVER}"
# -print -quit (not `| head -1`): no SIGPIPE, and a missing tree yields an empty
# value for the gates below instead of aborting the script before they run.
NV_KO="$(find "/usr/lib/modules/${KVER}" -name 'nvidia.ko*' -print -quit 2>/dev/null || true)"
NV_MOD_VER="$(modinfo -F version "${NV_KO}" 2>/dev/null || true)"
ENABLED="$(dnf5 -q repolist --enabled 2>/dev/null || true)"
echo "  INFO  p03 kernel: ${KVER}"
echo "  INFO  nvidia userland: $(rpm -q --qf '%{VERSION}' nvidia-driver-libs.x86_64) (module: ${NV_MOD_VER:-unreadable})"
echo "::endgroup::"

# --- verification (gate-fail semantics: any FAIL exits 1 with ::error::)
fail=0
gate() {
  local desc="$1"
  shift
  if "$@" >/dev/null 2>&1; then echo "  PASS  $desc"; else
    echo "  FAIL  $desc"
    fail=1
  fi
}

echo "::group::kernel-verify — p03 kernel + nvidia-open + userland + repos"
gate "p03 kernel installed" rpm -q kernel-p03
gate "nvidia-open built for p03" rpm -q kernel-p03-nvidia-open
gate "stock kernel absent" sh -c '! rpm -q kernel'
gate "p03 vmlinuz present" test -f "/usr/lib/modules/${KVER}/vmlinuz"
gate "nvidia modules for p03" test -n "${NV_KO}"
gate "p03 keeps SELinux config" grep -q '^CONFIG_SECURITY_SELINUX=y' "/usr/lib/modules/${KVER}/config"
gate "nvidia SELinux policy linked" sh -c 'semodule -lfull | grep -q nvidia-driver'
gate "nvidia module version readable" test -n "${NV_MOD_VER}"
gate "nvidia userland matches modules" test "${NV_MOD_VER}" = "$(rpm -q --qf '%{VERSION}' nvidia-driver-libs.x86_64)"
gate "nvidia-smi present" test -x /usr/bin/nvidia-smi
gate "32-bit nvidia + mesa libs" rpm -q nvidia-driver-libs.i686 mesa-libGL.i686
# Two gates: the first proves dnf5 actually answered, so the second cannot pass
# vacuously when `dnf5 repolist` fails and prints nothing.
gate "enabled-repo list readable" test -n "${ENABLED}"
gate "kernel COPR + negativo17 closed" sh -c '! grep -Eq "fedora-nvidia|catpieleaf"' <<<"${ENABLED}"
echo "::endgroup::"

[ "$fail" = 0 ] || {
  echo "::error::kernel-verify failed"
  exit 1
}
echo "--- kernel-verify: all checks passed ---"
/tmp/files/scripts/lib/cleanup.sh
echo "--- kernel-nvidia complete ---"
