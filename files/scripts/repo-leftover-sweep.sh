#!/usr/bin/env bash
# halcyon build step — module-staged repo leftover sweep.
# bluebuild's repos cleanup resolves the files to delete by running
# `dnf repo info` for EVERY repo in parallel; when one of those concurrent
# dnf5 calls races the shared metadata cache ("Failed to download metadata",
# "cannot remove: Directory not empty"), the cleanup list comes back EMPTY
# and the module silently skips removing the repo file it just staged
# (observed: cli-tools.repo leaked and verify-devtools failed). This sweep
# deletes every repo file the recipe stages, wired before each repos-module
# verify gate: at that point later modules have not run yet, so any of
# these files present is a leak of the current module.
set -euo pipefail

echo "::group::repo-leftover-sweep — module-staged repo files"
shopt -s nullglob
leftovers=(
  /etc/yum.repos.d/applications.repo
  /etc/yum.repos.d/base-pkgs.repo
  /etc/yum.repos.d/cli-tools.repo
  /etc/yum.repos.d/texlive-packages.repo
  /etc/yum.repos.d/ublue-os-packages.repo
  /etc/yum.repos.d/vscode.repo
  /etc/yum.repos.d/brave-browser*.repo
)
if (( ${#leftovers[@]} > 0 )); then
  printf '  found  %s\n' "${leftovers[@]##*/}"
  rm -f "${leftovers[@]}"
  echo "  OK    leftover repo files removed"
else
  echo "  OK    no leftover repo files"
fi
echo "::endgroup::"

/tmp/files/scripts/lib/cleanup.sh
