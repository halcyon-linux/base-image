#!/usr/bin/env bash
# halcyon verify — core: the utilities the bazzite base does NOT ship are
# installed, plus the base-provided keepers this module intentionally no
# longer re-installs (same-name or terra-name conflicts: see core.yml). The
# curated font set is gated by verify-fonts.sh; base-provided sets (cockpit,
# podman, openssh, plymouth…) are asserted by final-verify.sh instead.
# Mutates nothing.
set -uo pipefail

echo "████ verify · core ████"

fail=0
gate() {
  local desc="$1"
  shift
  if "$@" >/dev/null 2>&1; then echo "  PASS  $desc"; else
    echo "  FAIL  $desc"
    fail=1
  fi
}

echo "::group::verify-core"
gate "core utilities" rpm -q git zsh fastfetch file-roller grim slurp swappy imv zathura brightnessctl cronie fail2ban bleachbit lynis ninja-build pipx pymol transmission-gtk udiskie inotify-tools igt-gpu-tools setools-console setroubleshoot bluez-tools
# dropped from the install list because the base already provides them
# (libinput-utils under the same name; ddcutil as terra-ddcutil, which
# conflicts with Fedora's ddcutil) — assert they stay
gate "base-provided keepers" rpm -q libinput-utils terra-ddcutil
gate "vanilla fastfetch binary on PATH" sh -c 'command -v git && command -v zsh && command -v fastfetch'
# openssh + GUI pinentry: the bazzite base ships openssh; the pinentry-qt
# flavor was removed with the KDE closure and is deliberately not
# reinstalled — the GTK3 pinentry-gnome3 fronts gpg-agent instead (see the
# skel gpg-agent.conf).
gate "openssh clients present" rpm -q openssh-clients
gate "ssh client runs" sh -c 'ssh -V 2>&1 | grep -q OpenSSH'
gate "pinentry-gnome3 present (GTK3 GUI GPG prompts)" rpm -q pinentry-gnome3
gate "skel gpg-agent uses pinentry-gnome3" grep -q "pinentry-program /usr/bin/pinentry-gnome3" /etc/skel/.gnupg/gpg-agent.conf
echo "::endgroup::"

[ "$fail" = 0 ] || {
  echo "::error::core-verify failed"
  exit 1
}
echo "--- verify-core: all checks passed ---"
