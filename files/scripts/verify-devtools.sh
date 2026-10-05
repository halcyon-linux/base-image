#!/usr/bin/env bash
# halcyon verify — devtools: the COPR-window CLI tool set landed; the bazzite
# base's own CLI set is still present beside it. Mutates nothing.
set -uo pipefail

echo "████ verify · devtools ████"

fail=0
gate() {
  local desc="$1"
  shift
  if "$@" >/dev/null 2>&1; then echo "  PASS  $desc"; else
    echo "  FAIL  $desc"
    fail=1
  fi
}

echo "::group::verify-devtools"
gate "COPR-installed CLI packages" rpm -q asdf atuin bun direnv fzy kilo lazygit marksman pixi ripgrep starship tealdeer texlab topgrade uv
gate "base-provided CLI packages still present" rpm -q bat bat-extras btop cava chafa cliphist dust eza fd-find fpaste fzf gnuplot opencode pandoc
gate "binaries on PATH" sh -c 'command -v bat && command -v rg && command -v fzf && command -v uv && command -v starship && command -v lazygit'
gate "repo cleaned" sh -c '! ls /etc/yum.repos.d/ | grep -qi cli-tools'
echo "::endgroup::"

[ "$fail" = 0 ] || {
  echo "::error::devtools-verify failed"
  exit 1
}
echo "--- verify-devtools: all checks passed ---"
