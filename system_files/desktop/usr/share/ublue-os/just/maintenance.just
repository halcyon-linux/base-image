# vim: set ft=make :

# Interactive picker for ujust recipes
[group("utilities")]
pick:
    #!/usr/bin/env bash
    set -euo pipefail
    exec /usr/bin/ujust-picker
# Detects if you are on an unverified official image and rebases you to the signed version.
verify-image:
    #!/usr/bin/bash
    set -euo pipefail

    echo "Checking image verification status..."

    # Define variables
    REF=$(rpm-ostree status --json | jq -r '.deployments[0]["container-image-reference"]' || echo "")
    # FIXED: Added the trailing colon below so it gets removed during replacement
    BAD="ostree-unverified-registry:"
    GOOD="ostree-image-signed:docker://"

    # Logic: Check for Unverified AND Official/Halcyon
    if [[ "$REF" == *"$BAD"* ]] && ([[ "$REF" == *"ghcr.io/ublue-os/"* ]] || [[ "$REF" == *"ghcr.io/halcyon-linux/"* ]]); then
        echo "⚠️  UNVERIFIED OFFICIAL IMAGE DETECTED"
        echo "Current: $REF"

        # String replacement: Remove BAD from REF
        CLEAN_REF=${REF#*$BAD}

        # Build the new target
        TARGET="$GOOD$CLEAN_REF"

        echo ""
        echo "Target:  $TARGET"
        echo ""
        echo "This will rebase your system to the signed image."
        echo "This allows you to receive secure updates."
        echo ""

        # Prompt user
        read -p "Proceed with rebase? [y/N] " -n 1 -r
        echo ""

        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo "Requesting root permission to rebase..."
            pkexec rpm-ostree rebase "$TARGET"
        else
            echo "Cancelled."
        fi
    else
        echo "✅ System is either already verified or a custom user image. No action needed."
    fi
# Add Bazzite Updater to Steam Big Picture as a Non-Steam application

add-updater-to-steam:
    #!/usr/bin/bash
    set -euo pipefail
    if command -v steamos-add-to-steam >/dev/null 2>&1; then
        steamos-add-to-steam /usr/bin/bazzite-updater
    elif [[ -x /usr/bin/steamos-add-to-steam ]]; then
        /usr/bin/steamos-add-to-steam /usr/bin/bazzite-updater
    else
        echo "Error: steamos-add-to-steam is not available on this system." >&2
        exit 1
    fi
