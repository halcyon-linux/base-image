#!/usr/bin/env bash
# halcyon build step — ujust-system (Stage 08): ujust-fedora companions,
# recipe module registration (the halcyon + vendored modules ship via the
# static overlay; this stage writes 60-custom.just with the import list — the
# bazzite finalize RUN does the same echoes directly into the justfile),
# steam/lutris desktop-entry wiring (bazzite parity), the updater timer,
# service masks, and the global user-unit wiring (pyprland, chezmoi).
# /nix is a bind mount of /var/nix (var-nix.service creates it, nix.mount
# binds it) — enabled here. The gate section is the ujust-verify +
# system-verify tail.
set -euo pipefail

echo "████ STAGE 08/13 · ujust-system · ujust + units + services ████"

echo "::group::ujust-system — ujust-fedora companions"
readarray -t PKGS_UJUST < <(jq -r '.all.include.ujust-fedora[]' /tmp/files/packages.json)
dnf5 -y --setopt=install_weak_deps=False install "${PKGS_UJUST[@]}"
test -x /usr/bin/ujust || { echo "  FAIL  /usr/bin/ujust missing from ublue-os-just" >&2; exit 1; }
test -f /usr/share/ublue-os/justfile || { echo "  FAIL  /usr/share/ublue-os/justfile missing" >&2; exit 1; }
echo "::endgroup::"

echo "::group::ujust-system — register recipe modules"
cat >/usr/share/ublue-os/just/60-custom.just <<'EOF'
# halcyon custom modules (bazzite-derived + halcyon's own recipes)
EOF
for f in 80-halcyon.just 81-halcyon-fixes.just 83-halcyon-audio.just \
    87-halcyon-framegen.just halcyon-cleanup.just halcyon-doom-setup.just \
    halcyon-dots.just halcyon-home-manager-setup.just halcyon-rebase.just \
    halcyon-texlive.just; do
  echo "import \"/usr/share/ublue-os/just/${f}\"" >> /usr/share/ublue-os/just/60-custom.just
done
echo "::endgroup::"

echo "::group::ujust-system — steam/lutris desktop wiring"
sed -i 's@/usr/bin/steam@/usr/bin/bazzite-steam@g' /usr/share/applications/steam.desktop 2>/dev/null || true
sed -i 's@Exec=steam steam://open/bigpicture@Exec=/usr/bin/bazzite-steam-bpm@g' /usr/share/applications/steam.desktop 2>/dev/null || true
mkdir -p /etc/skel/.config/autostart
cp "/usr/share/applications/steam.desktop" "/etc/skel/.config/autostart/steam.desktop" 2>/dev/null || true
sed -i 's@/usr/bin/bazzite-steam %U@/usr/bin/bazzite-steam -silent %U@g' /etc/skel/.config/autostart/steam.desktop 2>/dev/null || true
sed -i 's|^Exec=lutris %U$|Exec=env PROTOCOL_BUFFERS_PYTHON_IMPLEMENTATION=python lutris %U|' /usr/share/applications/net.lutris.Lutris.desktop 2>/dev/null || true
echo "::endgroup::"

echo "::group::ujust-system — units + services"
systemctl enable uupd.timer 2>/dev/null \
    || ln -sf /usr/lib/systemd/system/uupd.timer /usr/lib/systemd/system/timers.target.wants/uupd.timer 2>/dev/null || true
systemctl enable greetd.service getty@tty2.service 2>/dev/null || true
systemctl enable var-nix.service nix.mount 2>/dev/null || true
for u in sddm.service gdm.service bazzite-autologin.service nvidia-persistenced.service nvidia-powerd.service; do
  ln -sf /dev/null /etc/systemd/system/"$u"
done
mkdir -p /etc/systemd/user/default.target.wants /etc/systemd/user/timers.target.wants
ln -sf /usr/lib/systemd/user/pyprland.service /etc/systemd/user/default.target.wants/pyprland.service 2>/dev/null || true
systemctl --global enable chezmoi-init.service chezmoi-update.timer 2>/dev/null \
    || { ln -sf /usr/lib/systemd/user/chezmoi-init.service /etc/systemd/user/default.target.wants/chezmoi-init.service; \
         ln -sf /usr/lib/systemd/user/chezmoi-update.timer /etc/systemd/user/timers.target.wants/chezmoi-update.timer; }
echo "::endgroup::"

echo "::group::ujust-system — verification (ujust + system verify tails)"
test -f /usr/lib/ujust/ujust.sh || { echo "  FAIL  ujust.sh missing" >&2; exit 1; }
test -f /usr/share/ublue-os/just/00-default.just || { echo "  FAIL  00-default.just missing" >&2; exit 1; }
test -f /usr/share/ublue-os/just/80-halcyon.just || { echo "  FAIL  80-halcyon.just missing" >&2; exit 1; }
test -f /usr/share/ublue-os/just/60-custom.just || { echo "  FAIL  60-custom.just missing" >&2; exit 1; }
grep -q 'halcyon-rebase.just' /usr/share/ublue-os/just/60-custom.just || { echo "  FAIL  60-custom.just does not import halcyon-rebase" >&2; exit 1; }
grep -q '80-halcyon.just' /usr/share/ublue-os/just/60-custom.just || { echo "  FAIL  60-custom.just does not import 80-halcyon" >&2; exit 1; }
grep -q '60-custom.just' /usr/share/ublue-os/justfile || { echo "  FAIL  justfile does not import 60-custom" >&2; exit 1; }
rpm -q uupd fzf >/dev/null 2>&1 || { echo "  FAIL  uupd/fzf missing" >&2; exit 1; }
test -f /usr/lib/systemd/system/uupd.timer || { echo "  FAIL  uupd.timer missing" >&2; exit 1; }
ujust --list >/dev/null 2>&1 || { echo "  FAIL  ujust --list fails" >&2; exit 1; }
[ -n "$(ujust --list 2>/dev/null)" ] || { echo "  FAIL  ujust --list empty" >&2; exit 1; }
just --help 2>&1 | grep -q -- --choose || { echo "  FAIL  just lacks --choose" >&2; exit 1; }
for b in grubby ethtool wget hostname fpaste wl-copy zenity jq; do
  command -v "$b" >/dev/null 2>&1 || { echo "  FAIL  ujust companion binary missing: $b" >&2; exit 1; }
done
systemctl is-enabled greetd.service >/dev/null 2>&1 || { echo "  FAIL  greetd not enabled" >&2; exit 1; }
systemctl is-enabled var-nix.service >/dev/null 2>&1 || { echo "  FAIL  var-nix.service not enabled" >&2; exit 1; }
systemctl is-enabled nix.mount >/dev/null 2>&1 || { echo "  FAIL  nix.mount not enabled" >&2; exit 1; }
test -L /etc/systemd/user/default.target.wants/chezmoi-init.service || { echo "  FAIL  chezmoi-init symlink missing" >&2; exit 1; }
test -L /etc/systemd/user/timers.target.wants/chezmoi-update.timer || { echo "  FAIL  chezmoi-update timer symlink missing" >&2; exit 1; }
test -L /etc/systemd/user/default.target.wants/pyprland.service || { echo "  FAIL  pyprland symlink missing" >&2; exit 1; }
test -f /etc/greetd/config.toml || { echo "  FAIL  greetd config missing" >&2; exit 1; }
grep -q pam_gnome_keyring.so /etc/pam.d/greetd || { echo "  FAIL  PAM keyring line missing" >&2; exit 1; }
test -f /usr/lib/tmpfiles.d/noctalia-greeter-state.conf || { echo "  FAIL  greeter state tmpfiles missing" >&2; exit 1; }
test -f /etc/profile.d/00-path-guard.sh || { echo "  FAIL  path guard missing" >&2; exit 1; }
grep -q '/usr/libexec/halcyon-image' /etc/profile.d/image-path.sh || { echo "  FAIL  image-path.sh hook missing" >&2; exit 1; }
env -i PATH= HOME=/root /bin/bash -lc 'command -v grep' >/dev/null 2>&1 || { echo "  FAIL  empty-PATH regression" >&2; exit 1; }
grep -q 'SHELL=/bin/zsh' /etc/default/useradd || { echo "  FAIL  zsh is not the default shell" >&2; exit 1; }
echo "  OK    ujust + system verification passed"
echo "::endgroup::"

/tmp/files/scripts/lib/cleanup.sh
echo "--- ujust-system complete ---"