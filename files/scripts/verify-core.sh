#!/usr/bin/env bash
# halcyon verify — core: the curated font set landed over the swept base
# fonts, and the utilities the bazzite base does NOT ship are installed.
# Base-provided sets (cockpit, podman, openssh, plymouth…) are asserted by
# final-verify.sh instead. Mutates nothing.
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
gate "curated font set" rpm -q google-noto-color-emoji-fonts jetbrains-mono-fonts-all nerd-fonts-jetbrainsmono nerd-fonts-symbols-only nerd-fonts-ubuntu nerd-fonts-ubuntu-mono
gate "nerd font registered with fontconfig" sh -c "fc-list | grep -qi 'JetBrainsMono Nerd Font'"
gate "core utilities" rpm -q git zsh fastfetch file-roller grim slurp swappy imv mpv zathura brightnessctl ddcutil cronie fail2ban bleachbit lynis ninja-build pipx pymol transmission-gtk udiskie inotify-tools intel-gpu-tools libinput-utils setools-console setroubleshoot bluez-tools
gate "vanilla fastfetch binary on PATH" sh -c 'command -v git && command -v zsh && command -v fastfetch'
# openssh + GUI pinentry: the bazzite base ships them; assert the integration
# points that the rest of the image relies on.
gate "openssh clients present" rpm -q openssh-clients
gate "ssh client runs" sh -c 'ssh -V 2>&1 | grep -q OpenSSH'
gate "pinentry-qt present (Wayland-capable GPG prompts)" rpm -q pinentry-qt
gate "skel gpg-agent uses pinentry-qt" grep -q "pinentry-program /usr/bin/pinentry-qt" /etc/skel/.gnupg/gpg-agent.conf
echo "::endgroup::"

[ "$fail" = 0 ] || {
  echo "::error::core-verify failed"
  exit 1
}
echo "--- verify-core: all checks passed ---"
