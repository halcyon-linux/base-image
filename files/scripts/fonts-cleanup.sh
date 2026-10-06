#!/usr/bin/env bash
# halcyon build step — fonts, safe removal.
# Pass 1 removes base font packages via dnf (proper transactions: file
# triggers, history, cache maintenance); pass 2 is the rpm -e mop-up for
# whatever dnf could not take. Both are reverse-dep-gated: fontconfig, the
# fonts filesystem provides and the dejavu core are protected outright, and
# nothing with a requirer is touched. Pass 1 loops to a fixpoint because
# removing a requirer (default-fonts-other-sans) frees its language deps
# (default-fonts-<lang>) only for the NEXT pass — the old one-shot rpm -e
# loop stranded 42 of them. Fonts later packages pull back in as deps are
# ACCEPTED: the verify scripts do not gate on their absence (user decision).
# Runs in the removals module, BEFORE fonts.yml installs the curated set.
set -uo pipefail

echo "::group::fonts-cleanup — safe font package removal"

PROTECT='^(fontconfig|fonts-filesystem|fontpackages|dejavu-sans-fonts|dejavu-sans-mono-fonts)(-|$)'

has_no_requirer() {
    local reqs
    reqs="$(rpm -q --whatrequires "$1" 2>/dev/null || true)"
    [ -z "${reqs}" ] || echo "${reqs}" | grep -q 'no package requires'
}

echo "--- Pass 1: dnf removal of unrequired font packages ---"
while :; do
    candidates=()
    while read -r pkg; do
        [ -n "${pkg}" ] || continue
        echo "${pkg}" | grep -Eq "${PROTECT}" && continue
        if has_no_requirer "${pkg}"; then
            candidates+=("${pkg}")
        fi
    done < <(rpm -qa --qf '%{NAME}\n' '*fonts*' | sort -u)

    if [ "${#candidates[@]}" -eq 0 ]; then
        echo "  OK    dnf pass reached a fixpoint"
        break
    fi
    echo "  INFO  dnf pass: removing ${#candidates[@]} package(s)"
    if ! dnf5 -y remove "${candidates[@]}"; then
        echo "  NOTE  dnf pass failed — falling back to the rpm -e mop-up"
        break
    fi
done

echo "--- Pass 2: rpm -e mop-up for stragglers ---"
removed=()
kept=()
while read -r pkg; do
    [ -n "${pkg}" ] || continue
    if echo "${pkg}" | grep -Eq "${PROTECT}"; then
        kept+=("${pkg}")
        echo "  KEEP  ${pkg} (protected)"
        continue
    fi
    if has_no_requirer "${pkg}"; then
        if rpm -e --nodeps "${pkg}" 2>/dev/null; then
            removed+=("${pkg}")
            echo "  REMOVED  ${pkg}"
        else
            kept+=("${pkg}")
            echo "  KEEP  ${pkg} (rpm -e failed — non-fatal)"
        fi
    else
        kept+=("${pkg}")
        echo "  KEEP  ${pkg} (required)"
    fi
done < <(rpm -qa --qf '%{NAME}\n' '*fonts*' | sort -u)

echo ""
echo "--- fonts-cleanup summary ---"
echo "  rpm -e mop-up removed: ${#removed[@]} (${removed[*]:-none})"
echo "  rpm -e mop-up kept   : ${#kept[@]}"

echo "--- Rebuilding font cache ---"
if fc-cache -f 2>/dev/null; then
    echo "  OK    font cache rebuilt"
else
    echo "  NOTE  fc-cache failed — non-fatal"
fi

echo "::endgroup::"
exit 0
