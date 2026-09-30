#!/usr/bin/env bash
# halcyon build step — base-packages (Stage 03): programming + core +
# hardware + editors + desktop + gaming + ublue machinery + vendor apps.
#
# Package LISTS live in files/packages.json (mounted at /tmp/files); weak
# deps are OFF on every install — anything that used to arrive as a weak dep
# must be listed explicitly in its group (hyprland-guiutils,
# xdg-desktop-portal-{hyprland,gtk}, qt6ct, nwg-look, kitty-terminfo).
# Language toolchains install FIRST so later groups/stages can rely on them
# (gcc backs RPM builds; python3 backs pip), and a toolchain failure
# attributes itself to the toolchain transaction. The @custom-environment
# comps group stays hardcoded here — comps groups are not catalog entries.
# The vscode/brave vendor repos are per-use: written, consumed and deleted
# inside this window (finalize sweeps leftovers). The gate section below is
# the packages-verify tail: rpm -q with multiple names fails on the first
# missing package; zen-browser is intentionally not gated here — it resolves
# from Terra in the next module, whose rpm -q loop covers it, and
# final-verify keeps the end-state gate.
set -euo pipefail

echo "████ STAGE 03/13 · base-packages · programming + core + desktop + gaming + apps ████"

echo "::group::base-packages — programming toolchains (Fedora, first)"
readarray -t PKGS_PROGRAMMING < <(jq -r '.all.include.programming[]' /tmp/files/packages.json)
dnf5 -y --setopt=install_weak_deps=False install "${PKGS_PROGRAMMING[@]}"
echo "::endgroup::"

echo "::group::base-packages — core + hardware + editors (Fedora)"
dnf5 -y --setopt=install_weak_deps=False group-install \
    custom-environment \
    || true
readarray -t PKGS_CORE < <(jq -r '.all.include.core[]' /tmp/files/packages.json)
dnf5 -y --setopt=install_weak_deps=False install "${PKGS_CORE[@]}"
readarray -t PKGS_HARDWARE < <(jq -r '.all.include.hardware[]' /tmp/files/packages.json)
dnf5 -y --setopt=install_weak_deps=False install "${PKGS_HARDWARE[@]}"
readarray -t PKGS_EDITORS < <(jq -r '.all.include.editors[]' /tmp/files/packages.json)
dnf5 -y --setopt=install_weak_deps=False install "${PKGS_EDITORS[@]}"
echo "::endgroup::"

echo "::group::base-packages — desktop stack (halcyon core, priority 1)"
readarray -t PKGS_DESKTOP < <(jq -r '.all.include.desktop[]' /tmp/files/packages.json)
dnf5 -y --setopt=install_weak_deps=False install "${PKGS_DESKTOP[@]}"
echo "::endgroup::"

echo "::group::base-packages — gaming (RPM Fusion + Fedora)"
readarray -t PKGS_GAMING < <(jq -r '.all.include.gaming[]' /tmp/files/packages.json)
dnf5 -y --setopt=install_weak_deps=False install "${PKGS_GAMING[@]}"
echo "::endgroup::"

echo "::group::base-packages — ublue machinery (COPR ublue-os/packages)"
dnf5 -y copr enable ublue-os/packages
readarray -t PKGS_UBLUEO < <(jq -r '.all.include.ublueos-packages[]' /tmp/files/packages.json)
dnf5 -y --setopt=install_weak_deps=False install "${PKGS_UBLUEO[@]}"
dnf5 -y copr disable ublue-os/packages
echo "::endgroup::"

echo "::group::base-packages — vendor repos (per-use: vscode, brave)"
# Written with heredocs (scripts may use quoted heredocs; the
# no-Containerfile-heredocs rule does not apply inside module scripts).
cat >/etc/yum.repos.d/vscode.repo <<'REPO'
[code]
name=Visual Studio Code
baseurl=https://packages.microsoft.com/yumrepos/vscode
enabled=1
type=rpm-md
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
REPO
cat >/etc/yum.repos.d/brave-browser.repo <<'REPO'
[brave-browser]
name=Brave Browser
baseurl=https://brave-browser-rpm-release.s3.brave.com/x86_64/
enabled=1
type=rpm-md
gpgcheck=1
gpgkey=https://brave-browser-rpm-release.s3.brave.com/brave-core.asc
REPO
readarray -t PKGS_VENDOR < <(jq -r '.all.include.vendor-apps[]' /tmp/files/packages.json)
dnf5 -y --setopt=install_weak_deps=False install "${PKGS_VENDOR[@]}"
rm -f /etc/yum.repos.d/vscode.repo /etc/yum.repos.d/brave-browser.repo
echo "::endgroup::"

echo "::group::base-packages — verification (packages-verify tail)"
rpm -q hyprland-git hyprland-guiutils noctalia-greeter-git greetd \
    xdg-desktop-portal-hyprland xdg-desktop-portal-gtk \
    kitty kitty-terminfo Thunar thunar-archive-plugin \
    jetbrains-mono-fonts-all google-noto-emoji-fonts google-noto-color-emoji-fonts \
    code brave-browser brave-origin neovim emacs-pgtk bazaar ublue-os-just uupd \
    || { echo "  FAIL  one or more base packages missing" >&2; exit 1; }
test -x /usr/bin/noctalia-greeter-session || { echo "  FAIL  noctalia-greeter-session missing" >&2; exit 1; }
grep -qF 'noctalia-greeter-session' /etc/greetd/config.toml || { echo "  FAIL  greetd config does not launch noctalia" >&2; exit 1; }
for b in zstd setpriv gpg jq gcc; do
  command -v "$b" >/dev/null 2>&1 || { echo "  FAIL  build-tool precondition missing: $b" >&2; exit 1; }
done
test ! -f /etc/yum.repos.d/vscode.repo || { echo "  FAIL  vscode.repo survived its window" >&2; exit 1; }
! ls /etc/yum.repos.d/brave-browser* >/dev/null 2>&1 || { echo "  FAIL  brave repo survived its window" >&2; exit 1; }
! grep -l '^enabled=1' /etc/yum.repos.d/_copr:*ublue* 2>/dev/null | grep -q . || { echo "  FAIL  ublue-os/packages copr still enabled" >&2; exit 1; }
grep -l . /etc/yum.repos.d/*aahsnr-work* >/dev/null 2>&1 || { echo "  FAIL  halcyon group repos not staged" >&2; exit 1; }
echo "  OK    base-packages verification passed"
echo "::endgroup::"

/tmp/files/scripts/lib/cleanup.sh
echo "--- base-packages complete ---"