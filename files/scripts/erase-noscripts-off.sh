#!/usr/bin/env bash
# halcyon build step — unstage the removals-stage tsflags=noscripts drop-in.
# _why_: see erase-noscripts-on.sh. The drop-in must never outlive the
# removals stage: install stages need their %post scriptlets. verify-removals.sh
# and final-verify.sh gate on this file's absence so a leaked drop-in can never
# silently strip scriptlets from a package install.
set -euo pipefail

CONF=/etc/dnf/libdnf5.conf.d/99-halcyon-erase-noscripts.conf
rm -f "$CONF"
if [ -e "$CONF" ]; then
  echo "FAIL: $CONF still present after removal" >&2
  exit 1
fi
echo "OK: tsflags=noscripts drop-in removed"
