#!/usr/bin/env bash
# halcyon — end-of-module cleanup. Called at the end of every mutating module
# script so package-manager logs and /boot contents never ship in the layers.
#
# NEVER wipe /tmp here: bluebuild binds the module runtime into /tmp during
# every module RUN (/tmp/files, /tmp/modules, /tmp/scripts) — deleting them
# mid-module kills the wrapper's cwd and fails the module AFTER the script
# has succeeded. bluebuild's post_build wipes /tmp/* + /var/* after the last
# module, so build state under /tmp never ships anyway.
set -eou pipefail
rm -f /var/log/dnf5.log /var/log/dnf5.log.* || true
# find(1) instead of `rm -rf /boot/*` globs: identical end state (empty /boot),
# no dotted-glob edge cases, and shellcheck-clean
find /boot -mindepth 1 -delete 2>/dev/null || true
# drop dnf5's per-repo cached metadata dirs too (the dnf cache is a tmpfs
# cache mount during builds, but be thorough)
rm -rf /var/cache/libdnf5/* || true
