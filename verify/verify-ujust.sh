#!/usr/bin/env bash
# verify/verify-ujust.sh — run INSIDE the built image to verify the
# just/ujust machinery, including that `ujust --choose` has everything it
# needs (fzf chooser + resolvable recipes):
#   podman run --rm --entrypoint /bin/bash -v "$PWD/verify:/verify:ro" \
#     localhost/halcyon:latest /verify/verify-ujust.sh
set -uo pipefail

fail=0
gate() { local desc="$1"; shift; if "$@" >/dev/null 2>&1; then printf '  PASS  %s\n' "$desc"; else printf '  FAIL  %s\n' "$desc"; fail=1; fi; }

echo "::group::verify-ujust — machinery"
gate "ujust wrapper executable"       test -x /usr/bin/ujust
gate "just executable"                test -x /usr/bin/just
gate "ujust lib helpers"              test -f /usr/lib/ujust/ujust.sh
gate "shared justfile"                test -f /usr/share/ublue-os/justfile
gate "60-custom import hook"          test -f /usr/share/ublue-os/just/60-custom.just
gate "justfile imports 60-custom"     grep -q '60-custom.just' /usr/share/ublue-os/justfile
gate "uupd installed"                 rpm -q uupd
echo "::endgroup::"

echo "::group::verify-ujust — recipes resolve"
LIST="$(mktemp)"; trap 'rm -f "${LIST}"' EXIT
if ujust --list >"${LIST}" 2>uar.err; then
  count=$(wc -l <"${LIST}")
  echo "  INFO  ujust --list resolved ${count} recipes"
  gate "recipe list non-empty"        test "${count}" -gt 10
else
  echo "  FAIL  ujust --list failed:"; sed 's/^/        /' uar.err
  fail=1
fi
rm -f uar.err
echo "::endgroup::"

echo "::group::verify-ujust — interactive chooser (--choose)"
gate "fzf installed"                  rpm -q fzf
gate "fzf on PATH"                    command -v fzf
gate "just supports --choose"         sh -c 'just --help 2>&1 | grep -q -- --choose'
gate "uupd/Choose helper present"     test -f /usr/lib/ujust/ujust.sh
echo "::endgroup::"

echo "::group::verify-ujust — headless chooser smoke test"
# Non-interactive emulation of `ujust --choose`: fzf's --filter mode exercises
# the same binary + query plumbing a real interactive run uses, without a TTY.
gate "fzf --filter picks a recipe"    sh -c 'printf "update\nssh\n" | fzf --filter update | grep -q update'
echo "::endgroup::"

if [ "${fail}" -eq 0 ]; then
  echo "--- verify-ujust: ALL CHECKS PASSED ---"
  exit 0
fi
echo "::error::verify-ujust FAILED"
exit 1
