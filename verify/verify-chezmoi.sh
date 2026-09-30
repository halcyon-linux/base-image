#!/usr/bin/env bash
# verify/verify-chezmoi.sh — run INSIDE the built image to verify the chezmoi
# integration mirrors the blue-build chezmoi module + main-branch semantics:
#   podman run --rm --entrypoint /bin/bash -v "$PWD/verify:/verify:ro" \
#     localhost/halcyon:latest /verify/verify-chezmoi.sh
set -uo pipefail

fail=0
gate() { local desc="$1"; shift; if "$@" >/dev/null 2>&1; then printf '  PASS  %s\n' "$desc"; else printf '  FAIL  %s\n' "$desc"; fail=1; fi; }

echo "::group::verify-chezmoi — binary"
gate "chezmoi installed"              rpm -q chezmoi
gate "chezmoi answers --version"      chezmoi --version
echo "::endgroup::"

echo "::group::verify-chezmoi — blue-build module unit semantics"
gate "chezmoi-init.service present"   test -f /usr/lib/systemd/user/chezmoi-init.service
gate "chezmoi-update.service present" test -f /usr/lib/systemd/user/chezmoi-update.service
gate "chezmoi-update.timer present"   test -f /usr/lib/systemd/user/chezmoi-update.timer
gate "init skips existing source"     grep -q 'ConditionPathExists=!%h/.local/share/chezmoi/.git/' /usr/lib/systemd/user/chezmoi-init.service
gate "init applies aahsnr-configs"    grep -q 'chezmoi init --apply aahsnr-configs/dotfiles' /usr/lib/systemd/user/chezmoi-init.service
gate "update uses replace policy"     grep -q 'chezmoi update --no-tty --force' /usr/lib/systemd/user/chezmoi-update.service
gate "timer OnBootSec=5m"             grep -q '^OnBootSec=5m' /usr/lib/systemd/user/chezmoi-update.timer
gate "timer OnUnitInactiveSec=1d"     grep -q '^OnUnitInactiveSec=1d' /usr/lib/systemd/user/chezmoi-update.timer
gate "timer gated on existing src"    grep -q 'ConditionPathExists=%h/.local/share/chezmoi' /usr/lib/systemd/user/chezmoi-update.timer
echo "::endgroup::"

echo "::group::verify-chezmoi — global enablement (all-users default)"
gate "init enabled --global"          test -L /etc/systemd/user/default.target.wants/chezmoi-init.service
gate "timer enabled --global"         test -L /etc/systemd/user/timers.target.wants/chezmoi-update.timer
echo "::endgroup::"

if [ "${fail}" -eq 0 ]; then
  echo "--- verify-chezmoi: ALL CHECKS PASSED ---"
  exit 0
fi
echo "::error::verify-chezmoi FAILED"
exit 1
