#!/usr/bin/env bash
# halcyon build step — ujust-system (Stage 08): ujust presence gates and the
# ujust+system verify tail. Everything declarative is owned by bluebuild
# modules: the ujust modules register via the static 60-custom.just overlay
# file, unit enable/mask state lives in the systemd block of
# modules/ujust.yml, /nix units in modules/nix.yml, dotfiles units in
# modules/chezmoi.yml, and grubby lands in the module's dnf block. The
# steam/lutris desktop-entry wiring ships in the bazzite base itself.
set -euo pipefail

echo "████ STAGE 08/13 · ujust-system · gates + system verify ████"

echo "::group::ujust-system — ujust presence"
test -x /usr/bin/ujust || {
  echo "  FAIL  /usr/bin/ujust missing from ublue-os-just" >&2
  exit 1
}
test -f /usr/share/ublue-os/justfile || {
  echo "  FAIL  /usr/share/ublue-os/justfile missing" >&2
  exit 1
}
echo "::endgroup::"

echo "::group::ujust-system — base desktop wiring (no-op gates)"
# The bazzite base ships bazzite-steam and the patched steam.desktop; gate
# them instead of re-patching (the old vendored wrappers are gone).
test -x /usr/bin/bazzite-steam || {
  echo "  FAIL  /usr/bin/bazzite-steam missing from the base" >&2
  exit 1
}
grep -q 'bazzite-steam' /usr/share/applications/steam.desktop || {
  echo "  FAIL  steam.desktop is not wired to bazzite-steam" >&2
  exit 1
}
echo "::endgroup::"

echo "::group::ujust-system — verification (ujust + system verify tails)"
test -f /usr/lib/ujust/ujust.sh || {
  echo "  FAIL  ujust.sh missing" >&2
  exit 1
}
test -f /usr/share/ublue-os/just/00-default.just || {
  echo "  FAIL  00-default.just missing" >&2
  exit 1
}
test -f /usr/share/ublue-os/just/60-custom.just || {
  echo "  FAIL  60-custom.just missing" >&2
  exit 1
}
test -f /usr/share/ublue-os/just/80-halcyon.just || {
  echo "  FAIL  80-halcyon.just missing" >&2
  exit 1
}
grep -q '80-halcyon.just' /usr/share/ublue-os/just/60-custom.just || {
  echo "  FAIL  60-custom.just does not import 80-halcyon" >&2
  exit 1
}
# The import list is a static overlay file — gate it against the OVERLAY's
# recipes (via the /tmp/files mount) so the list can never silently drift
# out of sync. RPM-owned recipes (00-default.just) stay OUT of the loop:
# the ublue-os-just spec generates the main justfile with an import line
# for every recipe it ships, so a re-import from 60-custom.just would
# duplicate them.
for f in /tmp/files/system/usr/share/ublue-os/just/*.just; do
  base=$(basename "$f")
  [ "$base" = "60-custom.just" ] && continue
  grep -qF "\"/usr/share/ublue-os/just/${base}\"" /usr/share/ublue-os/just/60-custom.just ||
    {
      echo "  FAIL  60-custom.just does not import ${base}" >&2
      exit 1
    }
done
grep -q '60-custom.just' /usr/share/ublue-os/justfile || {
  echo "  FAIL  justfile does not import 60-custom" >&2
  exit 1
}
rpm -q uupd fzf >/dev/null 2>&1 || {
  echo "  FAIL  uupd/fzf missing" >&2
  exit 1
}
test -f /usr/lib/systemd/system/uupd.timer || {
  echo "  FAIL  uupd.timer missing" >&2
  exit 1
}
ujust --list >/dev/null 2>&1 || {
  echo "  FAIL  ujust --list fails" >&2
  exit 1
}
[ -n "$(ujust --list 2>/dev/null)" ] || {
  echo "  FAIL  ujust --list empty" >&2
  exit 1
}
just --help 2>&1 | grep -q -- --choose || {
  echo "  FAIL  just lacks --choose" >&2
  exit 1
}
for b in grubby ethtool wget hostname fpaste wl-copy zenity jq; do
  command -v "$b" >/dev/null 2>&1 || {
    echo "  FAIL  ujust companion binary missing: $b" >&2
    exit 1
  }
done
# Login path: greetd is retired — getty@tty2 hosts the manual Hyprland start
# (ly is planned but not landed).
rpm -q greetd >/dev/null 2>&1 && {
  echo "  FAIL  greetd still installed — removals stage missed it" >&2
  exit 1
}
systemctl is-enabled getty@tty2.service >/dev/null 2>&1 || {
  echo "  FAIL  getty@tty2.service not enabled" >&2
  exit 1
}
systemctl is-enabled uupd.timer >/dev/null 2>&1 || {
  echo "  FAIL  uupd.timer not enabled" >&2
  exit 1
}
systemctl is-enabled var-nix.service >/dev/null 2>&1 || {
  echo "  FAIL  var-nix.service not enabled" >&2
  exit 1
}
systemctl is-enabled nix.mount >/dev/null 2>&1 || {
  echo "  FAIL  nix.mount not enabled" >&2
  exit 1
}
test -L /etc/systemd/user/graphical-session.target.wants/pyprland.service || {
  echo "  FAIL  pyprland symlink missing" >&2
  exit 1
}
test -f /etc/profile.d/00-path-guard.sh || {
  echo "  FAIL  path guard missing" >&2
  exit 1
}
grep -q '/usr/libexec/halcyon-image' /etc/profile.d/image-path.sh || {
  echo "  FAIL  image-path.sh hook missing" >&2
  exit 1
}
env -i PATH= HOME=/root /bin/bash -lc 'command -v grep' >/dev/null 2>&1 || {
  echo "  FAIL  empty-PATH regression" >&2
  exit 1
}
grep -q 'SHELL=/bin/zsh' /etc/default/useradd || {
  echo "  FAIL  zsh is not the default shell" >&2
  exit 1
}
echo "  OK    ujust + system verification passed"
echo "::endgroup::"

/tmp/files/scripts/lib/cleanup.sh
echo "--- ujust-system complete ---"
