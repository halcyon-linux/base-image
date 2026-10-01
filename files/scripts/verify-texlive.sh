#!/usr/bin/env bash
# halcyon verify — texlive: the rolling COPR stack (data groups + engine
# bundle) landed under the self-contained /usr/lib/texlive root, the PATH
# hook shipped, kpathsea resolves the tree, and the core formats baked.
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

shopt -s nullglob
tl_roots=(/usr/lib/texlive/*/)
shopt -u nullglob
TL_ROOT=""
if [ "${#tl_roots[@]}" -gt 0 ]; then
  TL_ROOT="${tl_roots[${#tl_roots[@]}-1]}"
fi

echo "::group::verify-texlive"
gate "engine bundle" rpm -q texlive-bin
gate "texlive groups" rpm -q texlive-basic texlive-latex texlive-latexextra texlive-latexrecommended texlive-binextra texlive-luatex texlive-mathscience texlive-publishers
gate "tree layout" test -d "${TL_ROOT}/bin/x86_64-linux" && test -d "${TL_ROOT}/texmf-dist/web2c"
gate "PATH hook shipped" test -x /etc/profile.d/texlive.sh
gate "TEXMFDIST resolves into tree" test "$(env -i HOME=/root "${TL_ROOT}/bin/x86_64-linux/kpsewhich" -var-value=TEXMFDIST)" = "${TL_ROOT}texmf-dist"
gate "pdflatex format baked" test -s "${TL_ROOT}/texmf-var/web2c/pdftex/pdflatex.fmt"
gate "lualatex format baked" test -s "${TL_ROOT}/texmf-var/web2c/luatex/lualatex.fmt"
gate "repo cleaned" sh -c '! ls /etc/yum.repos.d/ | grep -qi texlive-packages'
echo "::endgroup::"

[ "$fail" = 0 ] || {
  echo "::error::texlive-verify failed"
  exit 1
}
echo "--- verify-texlive: all checks passed ---"
