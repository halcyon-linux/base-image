#!/usr/bin/env bash
# halcyon build step — finalize (repo sweep + end-of-build hygiene).
#
# Belt-and-braces sweep of the repo files THIS recipe stages (the bluebuild
# dnf module's `cleanup: true` already removes each one after its own module,
# repo-leftover-sweep.sh guards per-module leaks). The bazzite base's own
# repo set — fedora, terra, rpmfusion, ublue — is DELIBERATELY untouched:
# the base manages its third-party repos and updates arrive via image
# rebuilds (bootc), so deleting them would break the base's update path.
set -euo pipefail
echo "::group::finalize — staged repo file sweep"
rm -f /etc/yum.repos.d/_copr*:*.repo /etc/yum.repos.d/_copr*.repo \
      /etc/yum.repos.d/applications.repo \
      /etc/yum.repos.d/base-pkgs.repo \
      /etc/yum.repos.d/cli-tools.repo \
      /etc/yum.repos.d/fonts.repo \
      /etc/yum.repos.d/terra-gaming.repo \
      /etc/yum.repos.d/texlive-packages.repo \
      /etc/yum.repos.d/vscode.repo \
      /etc/yum.repos.d/brave-browser*.repo \
      /etc/yum.repos.d/fedora-nvidia.repo
echo "  INFO  remaining repo files (Fedora + bazzite-managed third-party):"
ls /etc/yum.repos.d/
echo "::endgroup::"

echo "::group::finalize — end-of-build hygiene (bazzite finalize pattern)"
dnf5 config-manager setopt keepcache=0
dnf5 config-manager setopt skip_if_unavailable=1
# No /tmp wipe here: bluebuild binds the module runtime into /tmp during this
# very RUN — wiping it fails the module after the scripts succeed, and
# post_build wipes /tmp/* + /var/* after the last module regardless.
# The dnf-log//boot//var-cache trio is lib/cleanup.sh's job.
/tmp/files/scripts/lib/cleanup.sh
rm -rf /var/tmp/* || true
# ublue-os-signing installs its policy.json under /usr/etc/containers — an
# ostree-internal location bootc forbids in container images (the bootc
# etc-usretc lint hard-fails the build on its existence). The ACTIVE policy
# is /etc/containers/policy.json, owned by the signing module; the /usr/etc
# copy is inert.
rm -rf /usr/etc
install -d -m1777 /var/tmp
echo "  INFO  keepcache=0, skip_if_unavailable=1, /tmp + logs + /boot + caches cleared"
echo "::endgroup::"
echo "--- finalize complete ---"
