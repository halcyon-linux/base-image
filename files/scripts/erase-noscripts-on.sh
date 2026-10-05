#!/usr/bin/env bash
# halcyon build step — stage tsflags=noscripts for the removals stage.
#
# _why_: rpm records EVERY scriptlet failure — including "non-critical"
# %postun — in the transaction-global scriptError flag (runScript() in
# rpm's transaction.cc), and rpmtsRun() then returns -1 no matter how
# many elements already completed; dnf5 surfaces that as "Transaction
# failed: Rpm transaction failed." and aborts (rpm 6.0+ behavior, dnf5
# issue #2507). The de-Plasmaing erases ~400 packages whose %preun/%postun
# shell out to `systemctl --global disable ...` — impossible in a build
# chroot (no systemd bus; akonadi-server's %postun exit 2 killed the whole
# 413-package transaction). Erase-side scriptlets are noise in an image
# build, so skip them for this stage only. Cache maintenance (ldconfig,
# glib schemas) runs via rpm FILE TRIGGERS, which NOSCRIPTS does not
# disable. erase-noscripts-off.sh removes the drop-in before any install
# stage, where %post scriptlets do real work.
set -euo pipefail

CONF=/etc/dnf/libdnf5.conf.d/99-halcyon-erase-noscripts.conf
cat > "$CONF" <<'EOF'
[main]
# staged by erase-noscripts-on.sh for the removals stage; erased again by
# erase-noscripts-off.sh — must never be active during install stages
tsflags=noscripts
EOF

if ! grep -q '^tsflags=noscripts$' "$CONF"; then
  echo "FAIL: tsflags=noscripts not staged in $CONF" >&2
  exit 1
fi
echo "OK: tsflags=noscripts staged at $CONF"
