#!/usr/bin/env bash
# halcyon verify — chezmoi: the official blue-build module wired the dotfiles
# pipeline (GitHub-release binary, user units, --global enable), and the
# overlay drop-in carries the first-rebase fixes. Mutates nothing.
set -uo pipefail

echo "████ verify · chezmoi ████"

# shellcheck source=files/scripts/lib/verify.sh
source /tmp/files/scripts/lib/verify.sh

echo "::group::verify-chezmoi"
gate "chezmoi binary present" test -x /usr/bin/chezmoi
gate "chezmoi not RPM-managed" sh -c '! rpm -q chezmoi'
gate "init unit shipped" test -f /usr/lib/systemd/user/chezmoi-init.service
gate "update service shipped" test -f /usr/lib/systemd/user/chezmoi-update.service
gate "update timer shipped" test -f /usr/lib/systemd/user/chezmoi-update.timer
gate "first-rebase drop-in shipped" test -f /usr/lib/systemd/user/chezmoi-init.service.d/10-halcyon.conf
gate "drop-in forces the first apply" grep -q -- '--force' /usr/lib/systemd/user/chezmoi-init.service.d/10-halcyon.conf
gate "init wired --global" test -L /etc/systemd/user/default.target.wants/chezmoi-init.service
gate "update timer wired --global" test -L /etc/systemd/user/timers.target.wants/chezmoi-update.timer
echo "::endgroup::"

[ "$fail" = 0 ] || {
  echo "::error::chezmoi-verify failed"
  exit 1
}
echo "--- verify-chezmoi: all checks passed ---"
