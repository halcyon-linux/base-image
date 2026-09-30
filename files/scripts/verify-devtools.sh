#!/usr/bin/env bash
# halcyon verify — devtools: the CLI tool set landed through the
# halcyon-cli-tools repo window. Mutates nothing.
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
gate "CLI packages" rpm -q asdf atuin bat bat-extras btop bun cava chafa chezmoi cliphist direnv dust eza fd-find fpaste fzf fzy gnuplot kilo lazygit marksman opencode pandoc pixi ripgrep starship tealdeer texlab topgrade uv
gate "binaries on PATH" sh -c 'command -v bat && command -v rg && command -v fzf && command -v uv && command -v starship && command -v lazygit && command -v chezmoi'
gate "repo cleaned" sh -c '! ls /etc/yum.repos.d/ | grep -qi cli-tools'
echo "::endgroup::"

[ "$fail" = 0 ] || {
  echo "::error::devtools-verify failed"
  exit 1
}
echo "--- verify-devtools: all checks passed ---"
