#!/usr/bin/env bash
# halcyon build step — ujust-system (Stage 08): ujust presence gates,
# steam/lutris desktop-entry wiring (bazzite parity), and the ujust-verify +
# system-verify tail.
#
# Declarative work is owned by bluebuild modules, not this script:
#   - the 10 ujust modules are registered by the static overlay file
#     60-custom.just (files module; the ublue-os-just RPM ships the
#     justfile's `import?` hook for it);
#   - unit enables/masks (uupd.timer, greetd, getty@tty2, the sddm/gdm/
#     autologin/nvidia masks, the pyprland + chezmoi global user units)
#     belong to the systemd module in modules/ujust.yml;
#   - /nix unit enablement lives in modules/nix.yml.
# The ujust-fedora companions (glow, grubby, stress-ng) install via the
# module's dnf block — this repo has no packages.json catalog.
set -euo pipefail

echo "████ STAGE 08/13 · ujust-system · gates + desktop wiring ████"

echo "::group::ujust-system — ujust presence"
test -x /usr/bin/ujust || { echo "  FAIL  /usr/bin/ujust missing from ublue-os-just" >&2; exit 1; }
test -f /usr/share/ublue-os/justfile || { echo "  FAIL  /usr/share/ublue-os/justfile missing" >&2; exit 1; }
echo "::endgroup::"

echo "::group::ujust-system — steam/lutris desktop wiring"
sed -i 's@/usr/bin/steam@/usr/bin/bazzite-steam@g' /usr/share/applications/steam.desktop 2>/dev/null || true
sed -i 's@Exec=steam steam://open/bigpicture@Exec=/usr/bin/bazzite-steam-bpm@g' /usr/share/applications/steam.desktop 2>/dev/null || true
mkdir -p /etc/skel/.config/autostart
cp "/usr/share/applications/steam.desktop" "/etc/skel/.config/autostart/steam.desktop" 2>/dev/null || true
sed -i 's@/usr/bin/bazzite-steam %U@/usr/bin/bazzite-steam -silent %U@g' /etc/skel/.config/autostart/steam.desktop 2>/dev/null || true
sed -i 's|^Exec=lutris %U$|Exec=env PROTOCOL_BUFFERS_PYTHON_IMPLEMENTATION=python lutris %U|' /usr/share/applications/net.lutris.Lutris.desktop 2>/dev/null || true
echo "::endgroup::"

echo "::group::ujust-system — verification (ujust + system verify tails)"
test -f /usr/lib/ujust/ujust.sh || { echo "  FAIL  ujust.sh missing" >&2; exit 1; }
test -f /usr/share/ublue-os/just/00-default.just || { echo "  FAIL  00-default.just missing" >&2; exit 1; }
test -f /usr/share/ublue-os/just/60-custom.just || { echo "  FAIL  60-custom.just missing" >&2; exit 1; }
test -f /usr/share/ublue-os/just/80-halcyon.just || { echo "  FAIL  80-halcyon.just missing" >&2; exit 1; }
grep -q '80-halcyon.just' /usr/share/ublue-os/just/60-custom.just || { echo "  FAIL  60-custom.just does not import 80-halcyon" >&2; exit 1; }
# The import list is a static overlay file — gate it against the shipped
# recipes so the list can never silently drift out of sync.
for f in /usr/share/ublue-os/just/*.just; do
  base=$(basename "$f")
  [ "$base" = "60-custom.just" ] && continue
  grep -qF "\"/usr/share/ublue-os/just/${base}\"" /usr/share/ublue-os/just/60-custom.just ||
    { echo "  FAIL  60-custom.just does not import ${base}" >&2; exit 1; }
done
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
