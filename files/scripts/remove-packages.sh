#!/usr/bin/env bash
# halcyon build step — remove-packages (removals FIRST, main's removals.yml ordering)
#
# Removals run against the PRISTINE base before anything is installed:
# dnf computes the removal set from the full Requires graph (file requires,
# rich deps, per-subpackage edges — Fedora splits units into many subpackages
# so name-level reasoning cannot bound the transaction), and autoremove reads
# install-reason state that is least trustworthy late in a build. On the
# untouched base the blast radius is smallest and any cascade that hits core
# tooling fails the build at the very next dnf call — loud, immediate.
# Everything halcyon needs is (re)installed explicitly by later stages.
#
# HISTORY: this stage used to call four helpers inherited from the Bazzite-fork
# era (guarded-removals, file-footprint, gnome-extensions, fonts-cleanup). On a
# bare fedora-bootc base every target of those scripts is absent, so they were
# ~400 lines of no-op whose comments described an ordering that no longer held.
# The two parts with real value — the sddm/cage reverse-dependency gate and the
# must-not-survive hard-fail — live below.
set -euo pipefail

echo "████ STAGE 01/13 · remove-packages · removals on pristine base ████"
# shellcheck source=files/scripts/lib/packages-lib
source /tmp/files/scripts/lib/packages-lib
packages_validate

echo "::group::remove-packages — proven-present removals (packages.json exclude.all)"
# The removal list lives in packages.json (all.exclude.all) and is resolved
# through rpm -qa first, so entries absent from the base are tolerated
# instead of failing the transaction.
readarray -t REMOVAL_CANDIDATES < <(packages_excludes)
PRESENT=()
if [ "${#REMOVAL_CANDIDATES[@]}" -gt 0 ]; then
  readarray -t PRESENT < <(rpm -qa --qf '%{NAME}\n' "${REMOVAL_CANDIDATES[@]}" 2>/dev/null | sort -u || true)
fi
# NOTE: ${#arr[@]} admits no :-default (bash 'bad substitution') — the
# array is initialized unconditionally above instead.
if [ "${#PRESENT[@]}" -gt 0 ]; then
  echo "  INFO  removing ${#PRESENT[@]} present package(s): ${PRESENT[*]}"
  # --no-autoremove here: the orphan sweep below is the only autoremove
  dnf5 -y remove --no-autoremove "${PRESENT[@]}"
else
  echo "  INFO  nothing from the removal list is installed (clean base)"
fi
echo "::endgroup::"

echo "::group::remove-packages — reverse-dep gated removals (sddm, cage)"
# Display managers the base may pull in transitively. Remove only when
# nothing installed still requires them — halcyon logs in through greetd.
GATED=()
for p in sddm cage; do
  if ! rpm -q "$p" >/dev/null 2>&1; then
    echo "  SKIP  ${p} not installed"
    continue
  fi
  reqs="$(dnf5 -q repoquery --installed --whatrequires "$p" 2>/dev/null | grep -Ev "^${p}(-[0-9])?" || true)"
  if [ -n "${reqs}" ]; then
    echo "  GATE  keeping ${p} — required by:"
    # shellcheck disable=SC2001  # indenting multi-line output, not a substitution
    echo "${reqs}" | sed 's/^/          /'
  else
    echo "  GATE  removing ${p} — nothing installed requires it"
    GATED+=("$p")
  fi
done
if [ "${#GATED[@]}" -gt 0 ]; then
  dnf5 -y remove --no-autoremove "${GATED[@]}"
fi
echo "::endgroup::"

echo "::group::remove-packages — base orphan sweep"
# smallest graph the build will ever see
dnf5 -y autoremove || true
echo "::endgroup::"

echo "::group::remove-packages — hard-fail verification (must-be-gone)"
# A survivor means the removal transaction silently declined and a later stage
# would ship it.
rc=0
for p in gnome-shell gdm mutter nautilus firefox waydroid inputplumber; do
  if rpm -q "$p" >/dev/null 2>&1; then
    ver=$(rpm -q --qf '%{VERSION}-%{RELEASE}' "$p" 2>/dev/null || echo "?")
    echo "  FAIL  ${p}-${ver} still installed after removals" >&2
    rc=1
  else
    echo "  PASS  ${p} — absent (correct)"
  fi
done
echo "::endgroup::"

# NOTE: keeper verification (steam/gamescope/scx/umu/bazaar/lutris/…) lives in
# final-verify — it must gate the FINAL state, and this stage runs before
# anything is installed.
[ "${rc}" = 0 ] || { echo "::error::remove-packages-verify failed" >&2; exit 1; }
/tmp/files/scripts/lib/cleanup.sh
echo "--- remove-packages complete ---"
