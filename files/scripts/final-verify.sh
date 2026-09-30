#!/usr/bin/env bash
# halcyon verify — FINAL cross-cutting gates. Stage-scoped checks live in
# the per-module verify sections (base-packages/nix/built-apps/ujust-system/
# image-info); this script gates what only the finished image can answer:
# the p03 kernel + NVIDIA end state, the third-party repo sweep, the gaming
# keeper set, and the baked package census.
set -euo pipefail

echo "████ STAGE 10/13 · final-verify · cross-cutting gates ████"
fail=0
gate() { local desc="$1"; shift; if "$@" >/dev/null 2>&1; then echo "  PASS  $desc"; else echo "  FAIL  $desc"; fail=1; fi; }
echo "::group::final-verify — p03 kernel + NVIDIA end state"
KVER="$(rpm -q --qf '%{VERSION}-%{RELEASE}.%{ARCH}' kernel-p03)"
# the COPR kmod package's %{VERSION} is the KERNEL version — the DRIVER
# version lives in the module metadata, which is what the userland must match
NV_KO="$(find "/usr/lib/modules/${KVER}" -name 'nvidia.ko*' 2>/dev/null | head -1)"
NV_MOD_VER="$(modinfo -F version "${NV_KO}" 2>/dev/null || true)"
gate "p03 kernel installed"              rpm -q kernel-p03
gate "nvidia-open built for p03"         rpm -q kernel-p03-nvidia-open
gate "stock kernel absent"               sh -c '! rpm -q kernel >/dev/null 2>&1'
gate "p03 vmlinuz"                       test -f "/usr/lib/modules/${KVER}/vmlinuz"
gate "p03 initramfs"                     test -f "/usr/lib/modules/${KVER}/initramfs.img"
gate "nvidia modules for p03"            sh -c "find /usr/lib/modules/${KVER} -name 'nvidia.ko*' | grep -q ."
gate "p03 keeps SELinux config"          grep -q '^CONFIG_SECURITY_SELINUX=y' "/usr/lib/modules/${KVER}/config"
gate "nvidia SELinux policy linked"      sh -c 'semodule -lfull 2>/dev/null | grep -q nvidia-driver'
# Without this, `test "" = ""` PASSES when modinfo failed, turning the single
# most important NVIDIA gate into a no-op.
gate "nvidia module version readable"    test -n "${NV_MOD_VER}"
gate "nvidia userland matches modules"   test "${NV_MOD_VER}" = "$(rpm -q --qf '%{VERSION}' nvidia-driver-libs.x86_64)"
gate "nvidia-smi present"                test -x /usr/bin/nvidia-smi
gate "32-bit nvidia + mesa libs"         rpm -q nvidia-driver-libs.i686 mesa-libGL.i686
echo "::endgroup::"

echo "::group::final-verify — gaming keeper set (final state)"
gate "gaming keeper packages"            sh -c 'rpm -q scx-scheds scx-tools umu-launcher umu-wrapper bazaar bazzite-portal lutris gamescope input-remapper usbip'
gate "steam installed"                   rpm -q steam
gate "bazzite-steam wrapper"             test -x /usr/bin/bazzite-steam
gate "steam desktop -> bazzite-steam"    grep -q 'bazzite-steam' /usr/share/applications/steam.desktop
gate "devtools (halcyon + fedora)"       sh -c "rpm -q zed starship yazi zellij lazygit bat eza fzf pandoc-cli chezmoi bun pixi opencode"
gate "zen-browser (terra) installed"     rpm -q zen-browser
echo "::endgroup::"

echo "::group::final-verify — repo end state"
# finalize DELETES every third-party repo file (including terra*.repo), so a
# "terra repos all disabled" glob gate would match nothing and could never fail.
# This single gate is the property that survives.
gate "only Fedora repo files remain"     sh -c '! ls /etc/yum.repos.d/ | grep -Eqi "copr|vscode|brave|terra|negativo|rpmfusion|halcyon"'
echo "::endgroup::"

echo "::group::final-verify — chezmoi"
gate "chezmoi installed"                 rpm -q chezmoi
gate "chezmoi-init wired --global"       test -L /etc/systemd/user/default.target.wants/chezmoi-init.service
gate "chezmoi-update.timer wired"        test -L /etc/systemd/user/timers.target.wants/chezmoi-update.timer
echo "::endgroup::"

# --- package census (distinctively reported in CI; baked into the image) ---
echo "::group::final-verify — package census"
TOTAL_PACKAGES="$(rpm -qa | wc -l)"
echo "  ############################################"
echo "  INFO  total installed RPM packages: ${TOTAL_PACKAGES}"
echo "  ############################################"
echo "::notice title=halcyon package count::${TOTAL_PACKAGES} RPMs installed"
echo "  INFO  per-vendor breakdown (repo provenance):"
rpm -qa --qf '%{VENDOR}\n' | sed 's/^$/  (no vendor)/' | sort | uniq -c | sort -rn | sed 's/^/        /'
install -d -m0755 /usr/share/halcyon
{
  echo "halcyon image package census (generated at build time)"
  echo "date_utc: $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  echo "kernel_p03: $(rpm -q --qf '%{VERSION}-%{RELEASE}.%{ARCH}' kernel-p03 2>/dev/null || echo unknown)"
  echo "total_packages: ${TOTAL_PACKAGES}"
  echo
  echo "per-vendor:"
  rpm -qa --qf '%{VENDOR}\n' | sed 's/^$/  (no vendor)/' | sort | uniq -c | sort -rn | sed 's/^/  /'
} > /usr/share/halcyon/package-count
chmod 0644 /usr/share/halcyon/package-count
gate "package census baked"              test -s /usr/share/halcyon/package-count
echo "::endgroup::"

[ "$fail" = 0 ] || { echo "::error::final-verify failed"; exit 1; }
echo "--- final-verify: all checks passed ---"
