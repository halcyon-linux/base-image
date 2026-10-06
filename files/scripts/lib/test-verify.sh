#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=files/scripts/lib/verify.sh
source "$(dirname "${BASH_SOURCE[0]}")/verify.sh"

[[ "$fail" == 0 ]]
tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT
gate 'works' true > "$tmp"
IFS= read -r out < "$tmp"
[[ "$out" == '  PASS  works' && "$fail" == 0 ]]
gate 'fails' false > "$tmp"
IFS= read -r out < "$tmp"
[[ "$out" == '  FAIL  fails' && "$fail" == 1 ]]
