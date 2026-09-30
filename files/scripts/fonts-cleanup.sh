#!/usr/bin/env bash
# halcyon Step F — fonts, safe removal (prompt §5.1)
set -uo pipefail

echo "::group::fonts-cleanup — safe font package removal"

PROTECT='^(fontconfig|fonts-filesystem|fontpackages|dejavu-sans-fonts|dejavu-sans-mono-fonts)(-|$)'
removed=()
kept=()
skipped_required=()

echo "--- Scanning installed font packages ---"
total=$(rpm -qa '*fonts*' | wc -l)
echo "  INFO  ${total} font package(s) found"

while read -r pkg; do
    [ -n "${pkg}" ] || continue
    if echo "${pkg}" | grep -Eq "${PROTECT}"; then
        kept+=("${pkg}")
        echo "  KEEP  ${pkg} (protected)"
        continue
    fi
    reqs="$(rpm -q --whatrequires "${pkg}" 2>/dev/null || true)"
    if [ -z "${reqs}" ] || echo "${reqs}" | grep -q 'no package requires'; then
        if rpm -e --nodeps "${pkg}" 2>/dev/null; then
            removed+=("${pkg}")
            echo "  REMOVED  ${pkg}"
        else
            kept+=("${pkg}")
            echo "  KEEP  ${pkg} (rpm -e failed — non-fatal)"
        fi
    else
        skipped_required+=("${pkg}")
        kept+=("${pkg} (required)")
        echo "  KEEP  ${pkg} (required by: $(echo "${reqs}" | grep -v 'no package' | head -n3 | tr '\n' ' '))"
    fi
done < <(rpm -qa --qf '%{NAME}\n' '*fonts*' | sort -u)

echo ""
echo "--- fonts-cleanup summary ---"
echo "  Removed : ${#removed[@]}  (${removed[*]:-none})"
echo "  Kept    : ${#kept[@]}"
echo "    Protected   : $(printf '%s\n' "${kept[@]}" | grep -v '(required)' | grep -v '(rpm -e' | wc -l)"
echo "    Required    : ${#skipped_required[@]}"

echo "--- Rebuilding font cache ---"
if fc-cache -f 2>/dev/null; then
    echo "  OK    font cache rebuilt"
else
    echo "  NOTE  fc-cache failed — non-fatal"
fi

echo "::endgroup::"
exit 0
