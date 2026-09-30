#!/usr/bin/env bash
# halcyon verify — terra: the Terra-only leftovers landed and the terra repo
# window was closed (both blocks run with repos cleanup). Mutates nothing.
set -uo pipefail

echo "████ verify · terra ████"

fail=0
gate() {
  local desc="$1"
  shift
  if "$@" >/dev/null 2>&1; then echo "  PASS  $desc"; else
    echo "  FAIL  $desc"
    fail=1
  fi
}

echo "::group::verify-terra"
gate "terra release bootstrap" rpm -q terra-release-extras terra-release-mesa terra-release-multimedia
gate "terra leftovers" rpm -q bazzite-portal scx-scheds scx-tools umu-launcher umu-wrapper bibata-cursor-theme
gate "terra repo cleaned" sh -c '! ls /etc/yum.repos.d/ | grep -qi terra'
echo "::endgroup::"

[ "$fail" = 0 ] || {
  echo "::error::terra-verify failed"
  exit 1
}
echo "--- verify-terra: all checks passed ---"
