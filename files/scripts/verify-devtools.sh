#!/usr/bin/env bash
# halcyon verify — devtools: the cli-tools COPR set landed and the two
# base-provided tools that the COPR does not build are still present beside
# it. Mutates nothing.
set -uo pipefail

echo "████ verify · devtools ████"

# shellcheck source=files/scripts/lib/verify.sh
source /tmp/files/scripts/lib/verify.sh

echo "::group::verify-devtools"
gate "cli-tools COPR package set" rpm -q asdf atuin bat bat-extras bun cava chafa cliphist direnv dust eza fd-find fzf fzy gnuplot kilo lazygit marksman opencode pandoc pixi ripgrep starship tealdeer texlab topgrade uv
gate "base-provided keepers (not built in the COPR)" rpm -q btop fpaste
gate "binaries on PATH" sh -c 'command -v bat && command -v rg && command -v fzf && command -v uv && command -v starship && command -v lazygit'
gate "repo cleaned" sh -c '! ls /etc/yum.repos.d/ | grep -qi cli-tools'
echo "::endgroup::"

[ "$fail" = 0 ] || {
  echo "::error::devtools-verify failed"
  exit 1
}
echo "--- verify-devtools: all checks passed ---"
