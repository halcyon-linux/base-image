#!/usr/bin/env bash
# halcyon build step — terra repo sweep.
# `repos.cleanup` only removes the repo file the dnf module itself staged;
# the terra-release-* packages ship five enabled repo files of their own
# (terra{,-extras,-mesa,-multimedia,-nvidia}.repo) that survive the module.
# A third-party repo exists only inside the module that consumes it — left
# in place they would shadow Fedora for every later dnf transaction.
# finalize.sh keeps the end-of-build backstop for the shipped image.
set -euo pipefail

echo "::group::terra-repo-sweep — RPM-shipped terra repo files"
shopt -s nullglob
repo_files=(/etc/yum.repos.d/terra*.repo)
if (( ${#repo_files[@]} > 0 )); then
  printf '  found  %s\n' "${repo_files[@]##*/}"
  rm -f "${repo_files[@]}"
  echo "  OK    terra repo files removed"
else
  echo "  OK    no terra repo files present"
fi
echo "::endgroup::"

/tmp/files/scripts/lib/cleanup.sh
