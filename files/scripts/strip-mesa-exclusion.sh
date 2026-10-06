#!/usr/bin/env bash
# halcyon build step — strip the base's mesa exclusion from dnf config.
#
# _why_: terra-release-mesa (installed in the bazzite base) masks Fedora's
# mesa with a global dnf excludepkgs so Terra's patched build wins on
# Terra-enabled systems. In halcyon it protects NOTHING: terra's repos ship
# disabled and terra's mesa is not installed (the removals cascade orphans
# it with the KDE closure). Meanwhile core.yml must reinstall mesa-libEGL /
# libglvnd-egl / gtk4 / gstreamer1-plugins-base from fedora — impossible
# while excluded ("filtered out by exclude filtering" killed the core
# install on the 2026-10-06 base move). Fedora's mesa is this image's GL
# stack, so strip every excludepkgs line mentioning mesa from the dnf config
# tree. Wired FIRST in removals.yml so every build transaction runs
# exclusion-free.
set -euo pipefail

echo "::group::strip-mesa-exclusion"

shopt -s nullglob
confs=(
  /etc/dnf/dnf5.conf
  /etc/dnf/dnf.conf
  /etc/dnf/libdnf5.conf.d/*.conf
  /usr/share/dnf5/libdnf.conf.d/*.conf
  /etc/yum.repos.d/*.repo
)

stripped=0
for f in "${confs[@]}"; do
  [ -f "${f}" ] || continue
  if grep -Eiq '^[ \t]*excludepkgs[ \t]*=.*mesa' "${f}"; then
    sed -i -E '/^[ \t]*excludepkgs[ \t]*=.*mesa/Id' "${f}"
    echo "  OK    stripped mesa exclusion from ${f}"
    stripped=$((stripped + 1))
  fi
done

if [ "${stripped}" -eq 0 ]; then
  echo "  OK    no mesa exclusion present"
fi

# Gate: the strip must be complete — any surviving mesa exclusion would
# quietly poison a later transaction ("filtered out by exclude filtering").
if grep -rEiq '^[ \t]*excludepkgs[ \t]*=.*mesa' /etc/dnf /usr/share/dnf5 /etc/yum.repos.d 2>/dev/null; then
  echo "  FAIL  mesa exclusion survives the strip" >&2
  exit 1
fi

echo "::endgroup::"
echo "--- strip-mesa-exclusion complete ---"
