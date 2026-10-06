#!/usr/bin/env bash
# halcyon build step — strip the mesa exclusion from bazzite's repo config.
#
# _why_: bazzite's own build runs `config-manager setopt "*fedora*".exclude=
# "mesa-* kernel-core-* …"` — the exclusion lands as `exclude=` lines INSIDE
# /etc/yum.repos.d/fedora*.repo (repo-scoped, dnf4-compat key — NOT
# excludepkgs), plus equivalents on the staging and negativo17 repos. It
# masks Fedora mesa so the base's negativo/terra mesa wins. In halcyon the
# media stack stays installed (protect-media-stack.sh), but any transaction
# that ever needs a mesa INSTALL (e.g. an i686 variant) would die with
# "filtered out by exclude filtering" — so remove ONLY the mesa tokens from
# every exclude value, keeping bazzite's kernel/steam/noopenh264/scx
# protection intact.
set -euo pipefail

echo "::group::strip-mesa-exclusion"

shopt -s nullglob
confs=(
  /etc/yum.repos.d/*.repo
  /etc/dnf/dnf5.conf
  /etc/dnf/dnf.conf
  /etc/dnf/libdnf5.conf.d/*.conf
  /etc/dnf/repos.override.d/*
  /usr/share/dnf5/libdnf.conf.d/*.conf
)

stripped=0
for f in "${confs[@]}"; do
  [ -f "${f}" ] || continue
  if grep -Eiq '^[ \t]*exclude[a-z]*[ \t]*=.*mesa' "${f}"; then
    # drop every whitespace-delimited token containing "mesa" from exclude
    # values; keep the key and all other tokens
    sed -i -E '/^[ \t]*exclude[a-z]*[ \t]*=/ s/(=[ \t]*|[ \t])[^ \t]*mesa[^ \t]*/\1/ig' "${f}"
    echo "  OK    stripped mesa tokens from ${f}"
    stripped=$((stripped + 1))
  fi
done

if [ "${stripped}" -eq 0 ]; then
  echo "  OK    no mesa exclusion present"
fi

# Gate: the strip must be complete — a surviving exclusion quietly poisons
# any later transaction with "filtered out by exclude filtering".
if grep -rEiq '^[ \t]*exclude[a-z]*[ \t]*=.*mesa' /etc/dnf /usr/share/dnf5 /etc/yum.repos.d 2>/dev/null; then
  echo "  FAIL  mesa exclusion survives the strip" >&2
  exit 1
fi

echo "::endgroup::"
echo "--- strip-mesa-exclusion complete ---"
