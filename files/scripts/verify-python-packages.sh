#!/usr/bin/env bash
# halcyon verify — python-packages: the helper-tool set from COPR
# aahsnr-work/python-packages landed, the binaries resolve on PATH, and the
# staged repo did not leak into /etc. Mutates nothing.
set -uo pipefail

echo "████ verify · python-packages ████"

# shellcheck source=files/scripts/lib/verify.sh
source /tmp/files/scripts/lib/verify.sh

echo "::group::verify-python-packages"
gate "helper tool set" rpm -q dump-to-markdown fconf fe ff fkill fp fssh rmi rmtmp screenshot se
gate "helper binaries on PATH" sh -c 'command -v dump-to-markdown && command -v fconf && command -v fe && command -v ff && command -v fkill && command -v fp && command -v fssh && command -v rmi && command -v rmtmp && command -v screenshot && command -v se'
gate "repo cleaned" test ! -e /etc/yum.repos.d/python-packages.repo
echo "::endgroup::"

[ "$fail" = 0 ] || {
  echo "::error::python-packages-verify failed"
  exit 1
}
echo "--- verify-python-packages: all checks passed ---"
