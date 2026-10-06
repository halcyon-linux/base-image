#!/usr/bin/env bash
# halcyon build step — unstage the removals-transaction drop-in
# (tsflags=noscripts + media-stack excludepkgs; see erase-noscripts-on.sh).
# _why_: it must never outlive the removals stage — install stages need
# their %post scriptlets and unrestricted package resolution.
# verify-removals.sh and final-verify.sh gate on this file's absence.
set -euo pipefail

CONF=/etc/dnf/libdnf5.conf.d/99-halcyon-erase-noscripts.conf
rm -f "$CONF"
if [ -e "$CONF" ]; then
  echo "FAIL: $CONF still present after removal" >&2
  exit 1
fi
echo "OK: removals drop-in removed"
