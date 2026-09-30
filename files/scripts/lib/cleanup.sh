#!/usr/bin/env bash
# halcyon — end-of-module cleanup (bazzite/bluebuild post-build hygiene
# pattern). Called at the end of every mutating module script so temp files,
# package-manager logs and /boot contents never ship in the image layers.
set -eou pipefail
find /tmp -mindepth 1 -delete 2>/dev/null || true
rm -f /var/log/dnf5.log /var/log/dnf5.log.* || true
# find(1) instead of `rm -rf /boot/*` globs: identical end state (empty /boot),
# no dotted-glob edge cases, and shellcheck-clean
find /boot -mindepth 1 -delete 2>/dev/null || true
# drop dnf5's per-repo cached metadata dirs too (the dnf cache is a tmpfs
# cache mount during builds, but be thorough)
rm -rf /var/cache/libdnf5/* || true
