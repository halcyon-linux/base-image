#!/usr/bin/env bash
# halcyon verify — texlive: the TeX Live collection landed from the
# halcyon-texlive-packages repo and ships the PATH hook that
# halcyon-texlive.just sources. Mutates nothing.
set -uo pipefail

echo "████ verify · texlive ████"

fail=0
gate() {
  local desc="$1"
  shift
  if "$@" >/dev/null 2>&1; then echo "  PASS  $desc"; else
    echo "  FAIL  $desc"
    fail=1
  fi
}

echo "::group::verify-texlive"
gate "texlive collection" rpm -q texlive-basic texlive-latex texlive-latexextra texlive-latexrecommended texlive-binextra texlive-luatex texlive-mathscience texlive-publishers
gate "PATH hook shipped" test -f /etc/profile.d/texlive.sh
gate "repo cleaned" sh -c '! ls /etc/yum.repos.d/ | grep -qi texlive-packages'
echo "::endgroup::"

[ "$fail" = 0 ] || {
  echo "::error::texlive-verify failed"
  exit 1
}
echo "--- verify-texlive: all checks passed ---"
