#!/usr/bin/env bash
# halcyon build step — final-verify: FINAL cross-cutting gates.
# Stage-scoped checks live in the per-module verify scripts (verify-*.sh) and
# the stage tails (ujust-system.sh); this script gates what only the finished
# image can answer: bazzite kernel/NVIDIA end state, the gaming + desktop
# keeper sets, the repo sweep, identity files and the package census.
set -uo pipefail

echo "████ STAGE 10/13 · final-verify · cross-cutting gates ████"

KVER="$(rpm -q --qf '%{VERSION}-%{RELEASE}.%{ARCH}' kernel)"
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

echo "::group::final-verify — bazzite kernel + NVIDIA end state"
gate "bazzite kernel installed" rpm -q kernel kernel-modules
gate "retired p03 kernel absent" sh -c '! rpm -q kernel-p03'
gate "vmlinuz present" test -f "/usr/lib/modules/${KVER}/vmlinuz"
gate "initramfs present" test -f "/usr/lib/modules/${KVER}/initramfs.img"
gate "nvidia modules for the base kernel" sh -c "find /usr/lib/modules/${KVER} -name 'nvidia.ko*' | grep -q ."
gate "nvidia kmod package installed" rpm -q kmod-nvidia
gate "kernel keeps SELinux config" grep -q '^CONFIG_SECURITY_SELINUX=y' "/usr/lib/modules/${KVER}/config"
gate "nvidia SELinux policy linked" sh -c 'semodule -lfull 2>/dev/null | grep -q nvidia-driver'
# Without this, `test "" = ""` PASSES when modinfo failed, turning the single
# most important NVIDIA gate into a no-op.
gate "nvidia module version readable" test -n "${NV_MOD_VER}"
gate "nvidia userland matches modules" test "${NV_MOD_VER}" = "$(rpm -q --qf '%{VERSION}' nvidia-driver-libs.x86_64)"
gate "nvidia-smi present" test -x /usr/bin/nvidia-smi
gate "32-bit nvidia + mesa libs" rpm -q nvidia-driver-libs.i686 mesa-libGL.i686
gate "systemd-oomd masked (gaming box)" test "$(systemctl is-enabled systemd-oomd.service 2>/dev/null)" = masked
echo "::endgroup::"

echo "::group::final-verify — gaming keeper set (final state)"
gate "base gaming keepers" rpm -q scx-scheds scx-tools umu-launcher umu-wrapper bazaar bazzite-portal lutris terra-gamescope terra-mangohud input-remapper usbip uupd
# media stack must remain (user decision) — end-state insurance for the
# removals-stage protection
gate "media stack kept" rpm -q mesa-libEGL libglvnd-egl gstreamer1-plugins-base ffmpeg-libs libavcodec tesseract-libs tesseract-common
gate "steam installed" rpm -q steam
gate "module gaming installs" rpm -q gamemode heroic-games-launcher
gate "bazzite-steam wrapper" test -x /usr/bin/bazzite-steam
gate "steam desktop -> bazzite-steam" grep -q 'bazzite-steam' /usr/share/applications/steam.desktop
gate "devtools keepers" rpm -q zed starship lazygit bat eza fzf pandoc bun pixi opencode
gate "zen-browser installed" rpm -q zen-browser
echo "::endgroup::"

echo "::group::final-verify — desktop keeper set (final state)"
gate "hyprland + noctalia keepers" rpm -q hyprland-git noctalia-git pyprland qt6ct xdg-desktop-portal-hyprland xdg-desktop-portal-gtk adw-gtk3 papirus-icon-theme
gate "file managers (thunar replacement)" rpm -q nautilus file-roller
gate "keyring + pinentry (GUI GPG)" rpm -q gnome-keyring gnome-keyring-pam pinentry-gnome3
gate "gpg-agent prompts via pinentry-gnome3" grep -q "pinentry-program /usr/bin/pinentry-gnome3" /etc/skel/.gnupg/gpg-agent.conf
gate "qt pinentry not resurrected" sh -c '! rpm -q pinentry-qt'
gate "openssh clients present" rpm -q openssh-clients
gate "retired desktop pieces absent" sh -c '! rpm -q kwin konsole dolphin greetd noctalia-greeter-git Thunar'
gate "curated font set" rpm -q jetbrains-mono-fonts-all nerd-fonts-jetbrainsmono nerd-fonts-symbols-only google-noto-color-emoji-fonts
# Fonts later packages pull back in as deps are ACCEPTED (user decision) —
# no gate on the absence of base font packages; the curated set is what counts.
gate "zsh is the default shell" grep -q 'SHELL=/bin/zsh' /etc/default/useradd
gate "grub menu visible for 10s" sh -c 'grep -q "^GRUB_TIMEOUT=10$" /etc/default/grub && grep -q "^GRUB_TIMEOUT_STYLE=menu$" /etc/default/grub'
echo "::endgroup::"

echo "::group::final-verify — repo end state"
# finalize.sh deletes only the repo files THIS recipe stages; the bazzite
# base's own repo set (fedora, terra, negativo17, tailscale,
# nvidia-container-toolkit) is deliberately kept. The gate anchors on the
# STAGED FILENAMES — the old broad "negativo|fedora-nvidia|..." pattern
# false-positived on the base's own negativo17 repos (first bazzite build,
# 2026-10-06).
gate "no halcyon-staged repo files remain" sh -c '! ls /etc/yum.repos.d/ | grep -Eq "^(_copr[:.]|brave-browser|applications\.repo|base-pkgs\.repo|cli-tools\.repo|fonts\.repo|texlive-packages\.repo|vscode\.repo|terra-gaming\.repo)"'
# the removals-stage noscripts drop-in must never survive into the shipped image
gate "no erase-noscripts drop-in remains" test ! -e /etc/dnf/libdnf5.conf.d/99-halcyon-erase-noscripts.conf
echo "::endgroup::"

echo "::group::final-verify — identity files"
# the bluebuild os-release module writes values double-quoted (NAME="halcyon")
gate "os-release NAME=halcyon" grep -qE '^NAME="?halcyon"?$' /etc/os-release
gate "image-info.json present (base-provided)" test -s /usr/share/ublue-os/image-info.json
gate "texlive installed" rpm -q texlive-bin texlive-basic
gate "texlive tree + formats" test -s /etc/profile.d/texlive.sh && find /usr/lib/texlive/*/texmf-var/web2c -name 'pdflatex.fmt' 2>/dev/null | grep -q .
echo "::endgroup::"

echo "::group::final-verify — chezmoi"
gate "chezmoi binary present" test -x /usr/bin/chezmoi
gate "chezmoi not RPM-managed" sh -c '! rpm -q chezmoi'
gate "chezmoi-init wired --global" test -L /etc/systemd/user/default.target.wants/chezmoi-init.service
gate "chezmoi-update.timer wired" test -L /etc/systemd/user/timers.target.wants/chezmoi-update.timer
gate "chezmoi first-rebase drop-in" test -f /usr/lib/systemd/user/chezmoi-init.service.d/10-halcyon.conf
echo "::endgroup::"

echo "::group::final-verify — package census"
TOTAL_PACKAGES="$(rpm -qa | wc -l)"
echo "::notice title=halcyon package count::${TOTAL_PACKAGES} RPMs installed"
rpm -qa --qf '%{VENDOR}\n' | sed 's/^$/  (no vendor)/' | sort | uniq -c | sort -rn | head -12 || true
install -d -m0755 /usr/share/halcyon
{
  echo "halcyon image package census (generated at build time)"
  echo "date_utc: $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  echo "kernel: $(rpm -q --qf '%{VERSION}-%{RELEASE}.%{ARCH}' kernel 2>/dev/null || echo unknown)"
  echo "nvidia_driver: $(rpm -q --qf '%{VERSION}' nvidia-driver-libs.x86_64 2>/dev/null || echo unknown)"
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
