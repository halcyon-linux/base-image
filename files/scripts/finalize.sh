#!/usr/bin/env bash
# halcyon build step — finalize (repo sweep + end-of-build hygiene).
#
# Mirrors bazzite's finalize: the bluebuild dnf module's `cleanup: true`
# already removes each third-party repo file after its own module — this is
# the belt-and-braces sweep plus the end-of-build hygiene (keepcache=0,
# skip_if_unavailable, /var/tmp recreation, /tmp + log + /boot wipes for the
# bootc lints). The shipped image carries NO third-party repo files — updates
# arrive via image rebuilds (bootc); any repo can be re-enabled at runtime.
# Includes the negativo17 file staged by the overlay (fedora-nvidia.repo).
set -euo pipefail
echo "::group::finalize — third-party repo sweep"
rm -f /etc/yum.repos.d/_copr*:*.repo /etc/yum.repos.d/_copr*.repo \
      /etc/yum.repos.d/halcyon-*.repo \
      /etc/yum.repos.d/ublue-*.repo \
      /etc/yum.repos.d/vscode.repo \
      /etc/yum.repos.d/brave-browser*.repo \
      /etc/yum.repos.d/terra*.repo \
      /etc/yum.repos.d/fedora-nvidia.repo \
      /etc/yum.repos.d/negativo17*.repo \
      /etc/yum.repos.d/rpmfusion-*.repo
echo "  INFO  remaining repo files (Fedora only):"
ls /etc/yum.repos.d/
echo "::endgroup::"

echo "::group::finalize — end-of-build hygiene (bazzite finalize pattern)"
dnf5 config-manager setopt keepcache=0
dnf5 config-manager setopt skip_if_unavailable=1
# No /tmp wipe here: bluebuild binds the module runtime into /tmp during this
# very RUN — wiping it fails the module after the scripts succeed, and
# post_build wipes /tmp/* + /var/* after the last module regardless.
rm -f /var/log/dnf5.log /var/log/dnf5.log.* || true
# find(1) instead of `rm -rf /boot/*` globs: identical end state (empty /boot),
# no dotted-glob edge cases, and shellcheck-clean
find /boot -mindepth 1 -delete 2>/dev/null || true
rm -rf /var/cache/libdnf5/* || true
rm -rf /var/tmp/* || true
install -d -m1777 /var/tmp
echo "  INFO  keepcache=0, skip_if_unavailable=1, /tmp + logs + /boot + caches cleared"
echo "::endgroup::"
echo "--- finalize complete ---"
