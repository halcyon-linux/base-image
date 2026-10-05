#!/usr/bin/env bash
# halcyon verify — fonts: the curated set landed over the base fonts swept in
# the removals module, and the staged fonts.repo did not leak into /etc. The
# dejavu-sans return (noctalia-git hard dep) is deliberately not gated here —
# the sweep keep-regex owns it. Mutates nothing.
set -uo pipefail

echo "████ verify · fonts ████"

fail=0
gate() {
  local desc="$1"
  shift
  if "$@" >/dev/null 2>&1; then echo "  PASS  $desc"; else
    echo "  FAIL  $desc"
    fail=1
  fi
}

echo "::group::verify-fonts"
gate "curated font set" rpm -q google-noto-color-emoji-fonts jetbrains-mono-fonts-all nerd-fonts-jetbrainsmono nerd-fonts-symbols-only nerd-fonts-ubuntu nerd-fonts-ubuntu-mono
gate "nerd font registered with fontconfig" sh -c "fc-list | grep -qi 'JetBrainsMono Nerd Font'"
gate "fonts.repo leftover absent" test ! -e /etc/yum.repos.d/fonts.repo
echo "::endgroup::"

[ "$fail" = 0 ] || {
  echo "::error::fonts-verify failed"
  exit 1
}
echo "--- verify-fonts: all checks passed ---"
