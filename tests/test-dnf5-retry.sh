#!/usr/bin/env bash
# Self-check for build_files/shared/dnf5. Executes the retry shim's two behaviors
# with a fake dnf5 backend: succeed-after-transient-failures, and give-up-after
# max-retries. Run directly: bash tests/test-dnf5-retry.sh
set -euo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
shim="$here/../build_files/shared/dnf5"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
failures=0

not_ok() {
    printf 'FAIL: %s\n' "$*"
    failures=$((failures + 1))
}

if [[ ! -f "$shim" ]]; then
    not_ok "shim not found: $shim"
    exit 1
fi
# shellcheck source=/dev/null
source "$shim"

# Transient failure x2, then success. Attempts 1-2 emit stdout junk that must
# never leak into the reported output (callers capture stdout, e.g. $(dnf5 ...)).
cat >"$tmp/fake_transient" <<'EOF'
#!/usr/bin/env bash
attempts=$(( $(<"$COUNT_FILE") + 1 ))
echo "$attempts" >"$COUNT_FILE"
if (( attempts < 3 )); then
    echo "junk from attempt $attempts"
    echo "repos broken" >&2
    exit 1
fi
echo payload
EOF
chmod +x "$tmp/fake_transient"

# count=3 total: two retries then success
count1="$tmp/count1"; : >"$count1"
err1="$tmp/err1"
out1=$(DNF5_BIN="$tmp/fake_transient" DNF5_RETRY_SLEEP=0 COUNT_FILE="$count1" dnf5_retry install foo 2>"$err1")
[[ $out1 == payload ]] || not_ok "transient success stdout: got '$out1'"
[[ $(<"$count1") == 3 ]] || not_ok "transient success took $(<"$count1") attempts, expected 3"
grep -q 'repos broken' "$err1" || not_ok "transient failure stderr not surfaced"

# Permanent failure: initial attempt + 5 retries = 6 attempts, nonzero exit,
# and the backend's stderr reaches the caller.
cat >"$tmp/fake_permanent" <<'EOF'
#!/usr/bin/env bash
attempts=$(( $(<"$COUNT_FILE") + 1 ))
echo "$attempts" >"$COUNT_FILE"
echo "permanent boom" >&2
exit 1
EOF
chmod +x "$tmp/fake_permanent"

count2="$tmp/count2"; : >"$count2"
err2="$tmp/err2"
if DNF5_BIN="$tmp/fake_permanent" DNF5_RETRY_SLEEP=0 COUNT_FILE="$count2" dnf5_retry versionlock add bar 2>"$err2" >/dev/null; then
    not_ok "permanent failure returned success"
else
    status=$?
    ((status != 0)) || not_ok "permanent failure exited $status"
    [[ $(<"$count2") == 6 ]] || not_ok "gave up after $(<"$count2") attempts, expected 6"
    grep -q 'permanent boom' "$err2" || not_ok "final stderr not surfaced to caller"
    grep -q 'retry' "$err2" || not_ok "retry notices absent from log"
fi

if ((failures)); then
    printf 'FAILED: %d assertion(s)\n' "$failures"
    exit 1
fi
printf 'ok: dnf5 retry shim (3 tests)\n'
