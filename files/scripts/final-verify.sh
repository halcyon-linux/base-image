#!/usr/bin/env bash
# halcyon build step — final-verify: FINAL cross-cutting gates.
# Stage-scoped checks live in the per-module verify scripts (verify-*.sh) and
# the stage tails (install-kernel.sh, ujust-system.sh); this script gates what
# only the finished image can answer: kernel/NVIDIA end state, gaming keepers,
# the repo sweep, identity files and the package census.
set -uo pipefail

echo "████ STAGE 10/13 · final-verify · cross-cutting gates ████"

KVER="$(rpm -q --qf '%{VERSION}-%{RELEASE}.%{ARCH}' kernel-p03)"
NV_KO="$(find "/usr/lib/modules/${KVER}" -name 'nvidia.ko*' 2>/dev/null | head -1)"
NV_MOD_VER="$(modinfo -F version "${NV_KO}" 2>/dev/null || true)"

fail=0
gate() {
  local desc="$1"
  shift
  if "$@" >/dev/null 2>&1; then echo "  PASS  $desc"; else
    echo "  FAIL  $desc"
    fail=1
  fi
}

echo "::group::final-verify — p03 kernel + NVIDIA end state"
gate "p03 kernel installed" rpm -q kernel-p03
gate "nvidia-open built for p03" rpm -q kernel-p03-nvidia-open
gate "stock kernel absent" sh -c '! rpm -q kernel'
gate "p03 vmlinuz present" test -f "/usr/lib/modules/${KVER}/vmlinuz"
gate "p03 initramfs present" test -f "/usr/lib/modules/${KVER}/initramfs.img"
gate "nvidia modules for p03" sh -c "find /usr/lib/modules/${KVER} -name 'nvidia.ko*' | grep -q ."
gate "p03 keeps SELinux config" grep -q '^CONFIG_SECURITY_SELINUX=y' "/usr/lib/modules/${KVER}/config"
gate "nvidia SELinux policy linked" sh -c 'semodule -lfull 2>/dev/null | grep -q nvidia-driver'
# Without this, `test "" = ""` PASSES when modinfo failed, turning the single
# most important NVIDIA gate into a no-op.
gate "nvidia module version readable" test -n "${NV_MOD_VER}"
gate "nvidia userland matches modules" test "${NV_MOD_VER}" = "$(rpm -q --qf '%{VERSION}' nvidia-driver-libs.x86_64)"
gate "nvidia-smi present" test -x /usr/bin/nvidia-smi
gate "32-bit nvidia + mesa libs" rpm -q nvidia-driver-libs.i686 mesa-libGL.i686
gate "systemd-oomd masked (p03 LRU-Marie)" test "$(systemctl is-enabled systemd-oomd.service 2>/dev/null)" = masked
echo "::endgroup::"

echo "::group::final-verify — gaming keeper set (final state)"
gate "gaming keeper packages" rpm -q scx-scheds scx-tools umu-launcher umu-wrapper bazaar bazzite-portal lutris gamescope input-remapper usbip
gate "steam installed" rpm -q steam
gate "bazzite-steam wrapper" test -x /usr/bin/bazzite-steam
gate "steam desktop -> bazzite-steam" grep -q 'bazzite-steam' /usr/share/applications/steam.desktop
gate "devtools keepers" rpm -q zed starship lazygit bat eza fzf pandoc chezmoi bun pixi opencode
gate "zen-browser installed" rpm -q zen-browser
echo "::endgroup::"

echo "::group::final-verify — repo end state"
# finalize.sh DELETES every third-party repo file, so a "terra repos all
# disabled" glob gate would match nothing and could never fail. This single
# gate is the property that survives: only Fedora repo files remain.
gate "only Fedora repo files remain" sh -c '! ls /etc/yum.repos.d/ | grep -Eqi "copr|vscode|brave|terra|negativo|rpmfusion|halcyon|ublue|base-pkgs|cli-tools|texlive-packages|applications"'
echo "::endgroup::"

echo "::group::final-verify — identity files"
# the bluebuild os-release module writes values double-quoted (NAME="halcyon")
gate "os-release NAME=halcyon" grep -qE '^NAME="?halcyon"?$' /etc/os-release
gate "image-info.json baked" test -s /usr/share/ublue-os/image-info.json
gate "texlive installed" rpm -q texlive-bin texlive-basic
gate "texlive tree + formats" test -s /etc/profile.d/texlive.sh && find /usr/lib/texlive/*/texmf-var/web2c -name 'pdflatex.fmt' 2>/dev/null | grep -q .
echo "::endgroup::"

echo "::group::final-verify — chezmoi"
gate "chezmoi installed" rpm -q chezmoi
gate "chezmoi-init wired --global" test -L /etc/systemd/user/default.target.wants/chezmoi-init.service
gate "chezmoi-update.timer wired" test -L /etc/systemd/user/timers.target.wants/chezmoi-update.timer
echo "::endgroup::"

echo "::group::final-verify — package census"
TOTAL_PACKAGES="$(rpm -qa | wc -l)"
echo "::notice title=halcyon package count::${TOTAL_PACKAGES} RPMs installed"
rpm -qa --qf '%{VENDOR}\n' | sed 's/^$/  (no vendor)/' | sort | uniq -c | sort -rn | head -12 || true
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
gate "package census baked" test -s /usr/share/halcyon/package-count
echo "::endgroup::"

[ "$fail" = 0 ] || {
  echo "::error::final-verify failed"
  exit 1
}
echo "--- final-verify: all checks passed ---"
