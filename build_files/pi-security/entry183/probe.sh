#!/bin/bash
# Offline image-build candidate; never invoke directly on the host.
set -euo pipefail
umask 077
readonly base=/usr/share/pi-security/entry183
readonly run=/run/pi-entry183-synthetic
fail() { printf 'STOP: %s\n' "$1" >&2; exit 1; }
read_marker() { local value; IFS= read -r value < "$1" && [[ $value == "$2" ]]; }
case ${1:-} in
outer)
    [[ $EUID == 947 && $(/usr/bin/id -g) == 947 && $(/usr/bin/id -G) == 947 ]] || fail identity
    [[ -n ${INVOCATION_ID:-} && -d $run && ! -L $run && -O $run ]] || fail service-context
    [[ $(/usr/bin/stat -c '%a' -- "$run") == 700 ]] || fail runtime-mode
    # Only a new, empty runtime directory is allowed. No recursive cleanup.
    shopt -s nullglob dotglob
    entries=("$run"/*)
    ((${#entries[@]} == 0)) || fail runtime-not-empty
    read_marker "$base/allowed.txt" ALLOWED || fail allowed-positive
    read_marker "$base/nono-denied.txt" NONO_SYNTHETIC || fail nono-denial-positive
    if { : < "$base/systemd-denied.txt"; } 2>/dev/null; then fail systemd-denial; fi
    # Positive fixture contents must also be checked independently before activation.
    printf 'S03=OBSERVED (systemd marker not readable)\n'
    [[ -f /usr/bin/nono && ! -L /usr/bin/nono ]] || fail nono-file
    [[ $(/usr/bin/stat -c '%u:%a' /usr/bin/nono) == 0:755 ]] || fail nono-metadata
    measured=$(/usr/bin/sha256sum /usr/bin/nono)
    [[ ${measured%% *} == dfa2b2730dc77f3f3b529a56444dc094b5768258997821b70b42b1e70474a903 ]] || fail nono-continuity
    /usr/bin/mkdir -m 700 -- "$run/work" "$run/supervisor"
    for sub in config data state cache runtime tmp; do /usr/bin/mkdir -m 700 -- "$run/supervisor/$sub"; done
    # No network, no real user home, no credentials; exact profile, no fallback.
    /usr/bin/env -i PATH=/usr/bin:/bin LC_ALL=C HOME="$run/supervisor" \
      XDG_CONFIG_HOME="$run/supervisor/config" XDG_DATA_HOME="$run/supervisor/data" \
      XDG_STATE_HOME="$run/supervisor/state" XDG_CACHE_HOME="$run/supervisor/cache" \
      XDG_RUNTIME_DIR="$run/supervisor/runtime" TMPDIR="$run/supervisor/tmp" \
      /usr/bin/nono run --profile "$base/nono-profile.json" --block-net --isolate net,ipc,uts -- \
      /usr/bin/bash --noprofile --norc "$base/probe.sh" inner
    read_marker "$run/work/result.txt" SYNTHETIC_OUTPUT || fail output-check
    read_marker "$base/allowed.txt" ALLOWED || fail input-integrity
    read_marker "$base/nono-denied.txt" NONO_SYNTHETIC || fail outside-integrity
    printf 'S01-S07=observations only; independent review required\n'
    ;;
inner)
    read_marker "$base/allowed.txt" ALLOWED || fail inner-positive
    printf 'S04=OBSERVED\n'
    if { : < "$base/nono-denied.txt"; } 2>/dev/null; then fail nono-denial; fi
    printf 'S05=OBSERVED\n'
    if { : >> "$base/allowed.txt"; } 2>/dev/null; then fail input-write; fi
    printf 'S06=OBSERVED\n'
    /usr/bin/bash --noprofile --norc "$base/probe.sh" child
    printf '%s\n' SYNTHETIC_OUTPUT > "$run/work/result.txt"
    printf 'S07=OBSERVED\n'
    ;;
child)
    if { : < "$base/nono-denied.txt"; } 2>/dev/null; then fail child-denial; fi
    ;;
*) fail invalid-mode ;;
esac
