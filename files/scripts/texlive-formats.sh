#!/usr/bin/env bash
# halcyon build step — texlive format baking. The rolling COPR tree ships no
# %post scriptlets (rpm cannot order them after the sibling data groups), so
# the image bakes the format files here, after the dnf transaction.
#
# Step 1: rebuild the kpathsea database. texlive-basic ships an ls-R that
#   indexes only its own members, and kpathsea does not fall back to disk
#   search while an ls-R exists — rm it first (mktexlsr refuses to overwrite
#   a file whose magic header line deviates) or the rebuild silently no-ops
#   and every non-basic input (latex.ltx & co.) stays invisible.
# Step 2: trim the hyphenation declarations. language.dat/def/lua list ~70
#   languages; the pattern files for the pruned language collections are not
#   installed, and fmtutil's latex-family formats abort mid-ini on the first
#   missing loader. Each loader line is kept only if kpsewhich resolves it.
# Step 3: updmap-sys + fmtutil-sys --all (fmtutil.cnf covers the FULL scheme,
#   so formats for trimmed groups like context still fail — tolerance here,
#   enforcement in verify-texlive.sh's artifact gates).
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
CFG="${TL_ROOT}/texmf-dist/tex/generic/config"

# step 1 — filename database from the actual installed tree
rm -f "${TL_ROOT}/texmf-dist/ls-R"
mktexlsr "${TL_ROOT}/texmf-dist" >/dev/null
echo "  OK    texmf-dist ls-R rebuilt ($(wc -l < "${TL_ROOT}/texmf-dist/ls-R") lines)"

# step 2 — hyphenation trims against the installed tree
awk '
  /^[ \t]*%/ || /^[ \t]*$/ { print; next }
  /^=/ { if (miss) print "%[halcyon-trim] " $0; else print; next }
  {
    f=$2; out="";
    cmd="kpsewhich -format=tex " f " 2>/dev/null";
    (cmd) | getline out; close(cmd);
    if (out == "") { print "%[halcyon-trim] " $0; miss=1 } else { print; miss=0 }
  }' "${CFG}/language.dat" > "${CFG}/language.dat.new" \
  && mv "${CFG}/language.dat.new" "${CFG}/language.dat"
awk '
  /\\addlanguage/ {
    n = split($0, p, "{"); f = p[3]; sub(/}.*/, "", f); out = "";
    cmd = "kpsewhich -format=tex " f " 2>/dev/null";
    (cmd) | getline out; close(cmd);
    if (out == "") { print "%[halcyon-trim] " $0; next }
  }
  { print }' "${CFG}/language.def" > "${CFG}/language.def.new" \
  && mv "${CFG}/language.def.new" "${CFG}/language.def"
awk '
  /^[ \t]*\[/ { inb=1; buf=$0; miss=0; next }
  inb {
    buf = buf "\n" $0
    if (match($0, /loader[ \t]*=[ \t]*["'"'"'][^"'"'"']+["'"'"']/)) {
      f = substr($0, RSTART, RLENGTH)
      sub(/^[^"'"'"'""]*["'"'"']/, "", f); sub(/["'"'"']$/, "", f)
      out = ""; cmd = "kpsewhich -format=tex " f " 2>/dev/null"
      (cmd) | getline out; close(cmd)
      if (out == "") miss = 1
    }
    if ($0 ~ /^[ \t]*},?[ \t]*$/) {
      if (miss) { print "--[[ halcyon-trim: pattern file missing"; printf "%s\n", buf; print "]]" }
      else { printf "%s\n", buf }
      buf = ""; inb = 0
    }
    next
  }
  { print }' "${CFG}/language.dat.lua" > "${CFG}/language.dat.lua.new" \
  && mv "${CFG}/language.dat.lua.new" "${CFG}/language.dat.lua"
echo "  OK    hyphenation trimmed ($(grep -c 'halcyon-trim' "${CFG}/language.dat") dat / $(grep -c 'halcyon-trim' "${CFG}/language.def") def / $(grep -c 'halcyon-trim' "${CFG}/language.dat.lua") lua entries disabled)"

# step 3 — font maps and formats
if updmap-sys >/dev/null 2>&1; then
  echo "  OK    updmap-sys"
else
  echo "  WARN  updmap-sys reported failures (trimmed groups) — non-fatal"
fi
if fmtutil-sys --all >/dev/null 2>&1; then
  echo "  OK    fmtutil-sys --all"
else
  echo "  WARN  fmtutil-sys --all reported failures (trimmed groups) — non-fatal"
fi

mktexlsr "${TL_ROOT}/texmf-var" >/dev/null 2>&1 || true
echo "  INFO  formats baked: $(find "${TL_ROOT}/texmf-var/web2c" -name '*.fmt' 2>/dev/null | wc -l)"
echo "::endgroup::"

/tmp/files/scripts/lib/cleanup.sh
