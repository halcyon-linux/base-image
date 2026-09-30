#!/usr/bin/env bash
# halcyon verify — programming: language toolchains landed (installed FIRST
# in the module order so every later module can rely on them). Mutates nothing.
set -uo pipefail

echo "████ verify · programming ████"

fail=0
gate() {
  local desc="$1"
  shift
  if "$@" >/dev/null 2>&1; then echo "  PASS  $desc"; else
    echo "  FAIL  $desc"
    fail=1
  fi
}

echo "::group::verify-programming"
gate "toolchain packages" rpm -q python3 nodejs22 nodejs22-npm perl gcc-c++ cargo cmake golang
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
