#!/usr/bin/env bash
# halcyon build step — repos (Stage 00): dnf5 patience drop-in, keepcache=1,
# build-tooling bootstrap, external repos (RPM Fusion NVIDIA-excluded +
# negativo17) and the five halcyon group repos (copr enable + priority=1),
# ending with the fail-fast repolist gate.
#
# The dnf5 patience drop-in MUST land before the first dnf5 call — it exists
# to survive Copr CDN 504s during the transactions that follow (libdnf5 reads
# /etc/dnf/libdnf5.conf.d/ before the main config). keepcache=1 is the bazzite
# pattern: the dnf cache is a cache mount during builds; finalize flips it
# back to keepcache=0.
#
# The halcyon group repos are copr-enabled with priority=1 (bazzite pattern:
# `dnf5 copr enable` + `config-manager setopt` — the copr plugin itself does
# not set priorities), so every monorepo-built package outranks Fedora/Terra
# from Stage 03 onward; finalize sweeps the generated files.
#
# RPM Fusion's NVIDIA packages are EXCLUDED here — this is the ublue-os/akmods
# partition: NVIDIA userland/modules come from negativo17 ONLY, so the solver
# can never pull the conflicting RPM Fusion nvidia chain.
set -euo pipefail

echo "████ STAGE 00/13 · repos · dnf5 patience + external repos + halcyon groups + jq ████"

echo "::group::repos — dnf5 patience drop-in"
mkdir -p /etc/dnf/libdnf5.conf.d
cat >/etc/dnf/libdnf5.conf.d/99-halcyon-retries.conf <<'EOF'
# dnf5 main-config drop-in: libdnf5 loads /etc/dnf/libdnf5.conf.d/*.conf
# before the main config. Copr download CDN 504 survival — make dnf5
# patient instead of aborting the whole image build. Defaults were retries=10, timeout=30.
[main]
retries=20
timeout=60
EOF
echo "  OK    dnf5 patience drop-in written"
echo "::endgroup::"

echo "::group::repos — build tooling bootstrap"
dnf5 -y --setopt=install_weak_deps=False install \
    dnf5-plugins \
    jq
command -v jq >/dev/null 2>&1 || { echo "  FAIL  jq missing after bootstrap" >&2; exit 1; }
jq empty /tmp/files/packages.json || { echo "  FAIL  packages.json contains syntax errors" >&2; exit 1; }
echo "  OK    dnf5-plugins + jq present ($(jq --version)); packages.json parses"
echo "::endgroup::"

dnf5 config-manager setopt keepcache=1

echo "::group::repos — RPM Fusion (NVIDIA-excluded) + negativo17"
dnf5 -y --setopt=install_weak_deps=False --nogpgcheck install \
    "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm" \
    "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm"
dnf5 -y --setopt=install_weak_deps=False install \
    rpmfusion-free-appstream-data \
    rpmfusion-nonfree-appstream-data \
    || true
for f in /etc/yum.repos.d/rpmfusion-*.repo; do
  grep -q '^excludepkgs=' "${f}" || \
    echo "excludepkgs=xorg-x11-drv-nvidia* akmod-nvidia kmod-nvidia* nvidia-settings nvidia-modprobe nvidia-persistenced nvidia-driver-NVML" >> "${f}"
done
dnf5 -y config-manager addrepo --from-repofile=https://negativo17.org/repos/fedora-nvidia.repo
echo "::endgroup::"

echo "::group::repos — halcyon group repos (priority 1)"
for copr in aahsnr-work/halcyon aahsnr-work/halcyon-cli aahsnr-work/halcyon-apps aahsnr-work/halcyon-fonts aahsnr-work/halcyon-texlive; do
  echo "  INFO  enabling ${copr}"
  dnf5 -y copr enable "${copr}" || { echo "  FAIL  copr enable ${copr}" >&2; exit 1; }
  dnf5 -y config-manager setopt "copr:copr.fedorainfracloud.org:${copr////:}".priority=1
done
unset -v copr
echo "  OK    halcyon group repos staged with priority=1"
dnf5 -q repolist 2>/dev/null | grep -a "aahsnr-work" >/dev/null || { echo "  FAIL  halcyon repos not visible to dnf5 after staging" >&2; exit 1; }
echo "::endgroup::"

/tmp/files/scripts/lib/cleanup.sh
echo "--- repos complete ---"