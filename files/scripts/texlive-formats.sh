#!/usr/bin/env bash
# halcyon build step — texlive format baking. The rolling COPR tree ships no
# %post scriptlets (rpm cannot order them after the sibling data groups), so
# the image bakes the format files here, after the dnf transaction:
# updmap-sys (font maps), fmtutil-sys --all (formats), then mktexlsr over the
# generated texmf-var. fmtutil.cnf covers the FULL scheme, so formats for
# groups the image trims (context, language packs) are expected to fail —
# tolerance here, enforcement in verify-texlive.sh (the core .fmt artifacts).
set -euo pipefail

echo "::group::texlive-formats — bake format files"
shopt -s nullglob
tl_roots=(/usr/lib/texlive/*/)
shopt -u nullglob
TL_ROOT=""
if [ "${#tl_roots[@]}" -gt 0 ]; then
  TL_ROOT="${tl_roots[${#tl_roots[@]}-1]}"
fi
if [ -z "${TL_ROOT}" ] || [ ! -d "${TL_ROOT}/bin/x86_64-linux" ]; then
  echo "  FAIL  no texlive tree under /usr/lib/texlive" >&2
  exit 1
fi
echo "  INFO  root: ${TL_ROOT}"
export PATH="${TL_ROOT}/bin/x86_64-linux:${PATH}"

# font maps; missing maps from trimmed groups are expected, keep going
if updmap-sys >/dev/null 2>&1; then
  echo "  OK    updmap-sys"
else
  echo "  WARN  updmap-sys reported failures (trimmed groups) — non-fatal"
fi

# formats; same tolerance, artifact gates follow in verify-texlive.sh
if fmtutil-sys --all >/dev/null 2>&1; then
  echo "  OK    fmtutil-sys --all"
else
  echo "  WARN  fmtutil-sys --all reported failures (trimmed groups) — non-fatal"
fi

mktexlsr "${TL_ROOT}/texmf-var" >/dev/null 2>&1 || true
echo "  INFO  formats baked: $(find "${TL_ROOT}/texmf-var/web2c" -name '*.fmt' 2>/dev/null | wc -l)"
echo "::endgroup::"

/tmp/files/scripts/lib/cleanup.sh
