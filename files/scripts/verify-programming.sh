#!/usr/bin/env bash
# halcyon verify — programming: the toolchains the bazzite base lacks landed
# (installed FIRST in the module order so every later module can rely on
# them). python3/perl/gcc are base-provided and PATH-asserted here. Mutates
# nothing.
set -uo pipefail

echo "████ verify · programming ████"

# shellcheck source=files/scripts/lib/verify.sh
source /tmp/files/scripts/lib/verify.sh

echo "::group::verify-programming"
gate "installed toolchains" rpm -q nodejs22 nodejs22-npm cargo cmake golang
gate "base toolchains" rpm -q python3 perl gcc gcc-c++
gate "python3 on PATH" command -v python3
gate "node on PATH" command -v node
gate "gcc/g++ on PATH" sh -c 'command -v gcc && command -v g++'
gate "cargo on PATH" command -v cargo
gate "cmake on PATH" command -v cmake
gate "go on PATH" command -v go
gate "perl on PATH" command -v perl
echo "::endgroup::"

[ "$fail" = 0 ] || {
  echo "::error::programming-verify failed"
  exit 1
}
echo "--- verify-programming: all checks passed ---"
