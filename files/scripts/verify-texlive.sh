#!/usr/bin/env bash
# halcyon verify — texlive: the Fedora texlive-collection-* set landed with a
# consistent engine+runfile stack (collection-basic requires the engines).
# Mutates nothing.
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
gate "texlive collections" rpm -q texlive-collection-basic texlive-collection-latex texlive-collection-latexextra texlive-collection-latexrecommended texlive-collection-binextra texlive-collection-luatex texlive-collection-mathscience texlive-collection-publishers
gate "engines installed" rpm -q texlive-base texlive-kpathsea texlive-luatex texlive-pdftex texlive-tex
gate "latex binary" test -x /usr/bin/latex
gate "luatex binary" test -x /usr/bin/luatex
gate "tlmgr binary" test -x /usr/bin/tlmgr
echo "::endgroup::"

[ "$fail" = 0 ] || {
  echo "::error::texlive-verify failed"
  exit 1
}
echo "--- verify-texlive: all checks passed ---"
