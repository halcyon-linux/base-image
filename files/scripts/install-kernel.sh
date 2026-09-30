#!/usr/bin/env bash
# halcyon build step — install-kernel (p03 + nvidia-open, Stage K1)
#
# Kernel + prebuilt nvidia-open modules: COPR catpieleaf/kernel-p03
# (ABI-matched by the COPR; Stage K2 transfers the build to halcyon-packages).
# NVIDIA userland: negativo17 — the only repo on the 615.71.09 driver line the
# COPR modules were built for. Four negativo17 subpackages are dependency-
# entangled with a kmod package and can NOT be installed alongside the COPR's
# prebuilt modules (verified 2026-09-19 against the repo metadata):
#   nvidia-driver (meta)  -> requires nvidia-kmod-common
#   nvidia-driver-cuda    -> requires nvidia-kmod-common
#   nvidia-settings       -> requires nvidia-driver (the meta)
#   nvidia-kmod-common    -> requires nvidia-kmod (only provider: dkms-nvidia,
#                            which Conflicts with kernel-p03-nvidia-open)
# RPM Fusion is equally unusable: userland 595.58.03 (version mismatch) and
# xorg-x11-drv-nvidia hard-requires nvidia-kmod/akmod-nvidia too.
# Therefore: install the clean leaf RPMs, and payload-extract the three
# entangled subpackages file-only via rpm2cpio (GSP firmware, modprobe/udev/
# dracut confs, nvidia-smi, OpenCL ICD) — no rpmdb entry, no dependency chain.
# rakuos-base solves the same conflict by DKMS-building dkms-nvidia against
# its own kernel — that is our K2 fallback if the versions ever drift; the
# 90-verify.sh gate fails the build on userland/module version mismatch.
#
# Install mechanics follow rakuos-base (build/nvidia.sh):
# RPM %post scriptlets fail in containers, so install with
# tsflags=noscripts, then depmod + dracut explicitly.
set -euo pipefail

echo "████ STAGE 02/13 · kernel-nvidia · p03 + nvidia-open (Stage K1) ████"
echo "::group::install-kernel — p03 kernel + nvidia-open (Stage K1)"

# --- stock Fedora kernel out (rakuos-base pattern: --no-autoremove, then
# wipe the module trees so nothing stale is left behind). Only pass packages
# that are actually installed — dnf5 aborts the whole transaction on any
# absent argument, which would strand the stock kernel.
STOCK_KERNEL=()
for pkg in kernel kernel-core kernel-modules kernel-modules-core kernel-modules-extra \
           kernel-tools kernel-tools-libs; do
  rpm -q "${pkg}" >/dev/null 2>&1 && STOCK_KERNEL+=("${pkg}")
done
if [ "${#STOCK_KERNEL[@]}" -gt 0 ]; then
  # --no-autoremove must follow the remove command keyword (dnf5 CLI)
  dnf5 -y remove --no-autoremove "${STOCK_KERNEL[@]}"
fi
# find(1) instead of `rm -rf /boot/*`-style globs: identical end state, no
# glob edge cases, shellcheck-clean
find /boot -mindepth 1 -delete 2>/dev/null || true
find /usr/lib/modules /lib/modules -mindepth 1 -maxdepth 1 -exec rm -rf {} + 2>/dev/null || true

# --- p03 kernel + prebuilt nvidia-open modules (x86-64-v3 builds; the -gcc
# v2 fallback and kernel-p03-gcc-nvidia-open exist in the same COPR).
# Repo lifecycle: enable only for this transaction, disable immediately.
dnf5 -y copr enable catpieleaf/kernel-p03
dnf5 -y --setopt=tsflags=noscripts --setopt=install_weak_deps=False install \
  kernel-p03 \
  kernel-p03-nvidia-open
dnf5 -y copr disable catpieleaf/kernel-p03

# --- NVIDIA userland from negativo17 (clean leaf packages only — see header).
# 32-bit libs for Steam/Proton, CUDA libs for NVENC/DLSS, VA-API bridge.
# NOTE (dnf5 multilib collapse, reproduced 2026-09-20): with the cuda-libs
# pair in the same transaction, dnf5 resolves the bare `nvidia-driver-libs`
# name onto the i686 package and silently DROPS nvidia-driver-libs.x86_64
# from the plan — the image would ship without its 64-bit GL/EGL/Vulkan
# stack. Spelling out both arches keeps the solver honest; the bare+`.i686`
# form only collapses when `nvidia-driver-cuda-libs` is in the transaction
# (verified: both forms reproduce in isolation, the pair collapses together).
dnf5 -y --setopt=tsflags=noscripts --setopt=install_weak_deps=False install \
  libva-nvidia-driver \
  nvidia-driver-cuda-libs.x86_64 \
  nvidia-driver-cuda-libs.i686 \
  nvidia-driver-libs.x86_64 \
  nvidia-driver-libs.i686 \
  nvidia-libXNVCtrl \
  nvidia-modprobe \
  nvidia-persistenced

# --- SELinux policy module for the NVIDIA device nodes (halcyon runs
# enforcing — sanctioned divergence). The package %post skips `semodule` when
# selinuxenabled is false — always true in a build container — so link it
# into the image's policy store explicitly.
dnf5 -y --setopt=install_weak_deps=False install \
  nvidia-driver-selinux
semodule -i /usr/share/selinux/packages/targeted/nvidia-driver.pp.bz2

# --- dependency-entangled subpackages: payload-extract without rpmdb entry
# (nvidia-kmod-common: GSP firmware + modprobe/udev/dracut confs;
#  nvidia-driver-cuda: nvidia-smi/MPS/debugdump + OpenCL ICD;
#  nvidia-settings: nvidia-settings GUI + libXNVCtrl + lib64 GUI libs)
# Verified against the repo filelists: none of these payload paths collide
# with RPM-owned files (Fedora's nvidia-gpu-firmware does not ship the
# 615.71.09 GSP blobs).
dnf5 -y --setopt=install_weak_deps=False install \
  cpio
mkdir -p /tmp/nkc
( cd /tmp/nkc && dnf5 -y download nvidia-kmod-common nvidia-driver-cuda nvidia-settings )
for rpm in /tmp/nkc/nvidia-kmod-common-*.noarch.rpm \
           /tmp/nkc/nvidia-driver-cuda-*.x86_64.rpm \
           /tmp/nkc/nvidia-settings-*.x86_64.rpm; do
  rpm2cpio "$rpm" | cpio -idmu --quiet -D /tmp/nkc
done
rm -rf /tmp/nkc/usr/lib/.build-id /tmp/nkc/usr/lib64/.build-id
cp -a /tmp/nkc/etc/. /etc/
cp -a /tmp/nkc/usr/. /usr/
chmod 0644 /usr/lib/modprobe.d/nvidia.conf /usr/lib/udev/rules.d/60-nvidia.rules
rm -rf /tmp/nkc

KVER="$(rpm -q --qf '%{VERSION}-%{RELEASE}.%{ARCH}' kernel-p03)"
echo "  INFO  p03 kernel: ${KVER}"

# VERIFY (sanctioned divergence): p03 is Fedora-SRPM-derived and must keep SELinux
grep -q '^CONFIG_SECURITY_SELINUX=y' "/usr/lib/modules/${KVER}/config" || {
  echo "  FAIL  CONFIG_SECURITY_SELINUX is not =y in the p03 kernel config"
  exit 1
}

# --- module deps (scriptlets were skipped above). The initramfs is NOT built
# here: dracut runs in 70-initramfs.sh after all packages and the plymouth
# theme exist (rakuos-base generates its initramfs last for the same reason —
# the BlueBuild build did it with an initramfs module after branding.yml).
depmod "${KVER}"

# repo lifecycle: the NVIDIA userland is complete — disable negativo17 so no
# later stage can silently pull from it (finalize removes the file entirely)
sed -i 's/^enabled=1/enabled=0/' /etc/yum.repos.d/fedora-nvidia.repo 2>/dev/null || true

NV_MOD_VER="$(modinfo -F version "$(find "/usr/lib/modules/${KVER}" -name 'nvidia.ko*' | head -1)")"
echo "  INFO  nvidia userland: $(rpm -q --qf '%{VERSION}' nvidia-driver-libs.x86_64) (module: ${NV_MOD_VER})"
echo "::endgroup::"

# --- verification (absorbed from kernel-verify in the 2026-09-29 one-file-
# per-stage consolidation; same RUN, gate-fail semantics unchanged: any FAIL
# sets fail=1 and the script exits 1 with a ::error:: annotation).
# Verifies p03 kernel + prebuilt nvidia-open modules, removal of the
# stock kernel, vmlinuz presence, SELinux kernel configuration and module
# policy, version match between driver modules and Negativo17 userland,
# nvidia-smi tool, 32-bit driver libraries, and Negativo17 repo deactivation.
fail=0
gate() { local desc="$1"; shift; if "$@" >/dev/null 2>&1; then echo "  PASS  $desc"; else echo "  FAIL  $desc"; fail=1; fi; }

echo "::group::kernel-verify — p03 kernel + nvidia-open + userland"
VKVER="$(rpm -q --qf '%{VERSION}-%{RELEASE}.%{ARCH}' kernel-p03)"
NV_KO="$(find "/usr/lib/modules/${VKVER}" -name 'nvidia.ko*' 2>/dev/null | head -1)"
VNV_MOD_VER="$(modinfo -F version "${NV_KO}" 2>/dev/null || true)"

gate "p03 kernel installed"              rpm -q kernel-p03
gate "nvidia-open built for p03"         rpm -q kernel-p03-nvidia-open
# shellcheck disable=SC2016  # single quotes for inner subshell
gate "stock kernel absent"               sh -c '! rpm -q kernel >/dev/null 2>&1'
gate "p03 vmlinuz present"               test -f "/usr/lib/modules/${VKVER}/vmlinuz"
gate "nvidia modules for p03"            sh -c "find /usr/lib/modules/${VKVER} -name 'nvidia.ko*' | grep -q ."
gate "p03 keeps SELinux config"          grep -q '^CONFIG_SECURITY_SELINUX=y' "/usr/lib/modules/${VKVER}/config"
gate "nvidia SELinux policy linked"      sh -c 'semodule -lfull 2>/dev/null | grep -q nvidia-driver'
gate "nvidia userland matches modules"   test "${VNV_MOD_VER}" = "$(rpm -q --qf '%{VERSION}' nvidia-driver-libs.x86_64)"
gate "nvidia-smi present"                test -x /usr/bin/nvidia-smi
gate "32-bit nvidia + mesa libs"         rpm -q nvidia-driver-libs.i686 mesa-libGL.i686
gate "negativo17 repo disabled"          sh -c '! grep -l "^enabled=1" /etc/yum.repos.d/fedora-nvidia.repo 2>/dev/null | grep -q .'
echo "::endgroup::"

[ "$fail" = 0 ] || { echo "::error::kernel-verify failed"; exit 1; }
echo "--- kernel-verify: all checks passed ---"
/tmp/files/scripts/lib/cleanup.sh
echo "--- kernel-nvidia complete ---"
