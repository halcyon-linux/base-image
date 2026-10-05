#!/usr/bin/env bash
# halcyon build step — grub menu timing.
# The bazzite base hides the GRUB menu with a ~1s timeout; a gaming desktop
# wants a visible menu for picking older deployments / editing kernel args.
# Key-preserving update of /etc/default/grub: the base's GRUB_CMDLINE_*
# entries must survive, so the file is never rewritten wholesale. Fresh
# installs read this at installer grub.cfg generation; already-deployed
# machines regenerate with the shipped `ujust regenerate-grub`.
set -euo pipefail

GRUB_DEFAULT=/etc/default/grub
TIMEOUT=10

echo "::group::grub-config — visible ${TIMEOUT}s menu"
if [ ! -f "${GRUB_DEFAULT}" ]; then
    # absent on the base: write a minimal file (bootc installs regenerate
    # grub.cfg from /etc/default/grub via the standard Fedora machinery)
    cat > "${GRUB_DEFAULT}" <<EOF
GRUB_TIMEOUT=${TIMEOUT}
GRUB_TIMEOUT_STYLE=menu
GRUB_DISTRIBUTOR="halcyon"
EOF
else
    if grep -qE '^GRUB_TIMEOUT=' "${GRUB_DEFAULT}"; then
        sed -i "s/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=${TIMEOUT}/" "${GRUB_DEFAULT}"
    else
        echo "GRUB_TIMEOUT=${TIMEOUT}" >> "${GRUB_DEFAULT}"
    fi
    if grep -qE '^GRUB_TIMEOUT_STYLE=' "${GRUB_DEFAULT}"; then
        sed -i "s/^GRUB_TIMEOUT_STYLE=.*/GRUB_TIMEOUT_STYLE=menu/" "${GRUB_DEFAULT}"
    else
        echo "GRUB_TIMEOUT_STYLE=menu" >> "${GRUB_DEFAULT}"
    fi
fi
echo "  OK    grub timing applied:"
grep -E '^GRUB_TIMEOUT=|^GRUB_TIMEOUT_STYLE=' "${GRUB_DEFAULT}"
echo "::endgroup::"
