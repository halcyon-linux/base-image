# vim: set ft=make :

# Interactive picker for ujust recipes
[group("utilities")]
pick:
    #!/usr/bin/env bash
    set -euo pipefail

    REPO="ublue-os/bazzite-ujust-picker"
    DEST="$HOME/.local/bin/ujust-picker"

    # Ensure local bin directory exists
    mkdir -p "$(dirname "$DEST")"

    echo "Checking for latest release from GitHub..."
    API_JSON=$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" || true)

    if [[ -z "$API_JSON" ]]; then
        if [[ -f "$DEST" ]]; then
            echo "⚠️  GitHub unreachable. Using existing binary at $DEST"
            clear
            exec "$DEST"
        else
            echo "❌ GitHub unreachable and no local binary found. Falling back to list view."
            just --choose
            exit 0
        fi
    fi

    # Parse latest asset and tag
    ASSET_URL=$(echo "$API_JSON" | jq -r '.assets[] | select(.name | test("x86_64$")) | .browser_download_url')
    TAG_NAME=$(echo "$API_JSON" | jq -r '.tag_name')
    CACHED_TAG_FILE="$DEST.version"

    if [[ -z "$ASSET_URL" ]]; then
        echo "❌ Could not locate x86_64 asset in the latest release."
        exit 1
    fi

    # Check if we already have the latest version
    if [[ -f "$DEST" && -f "$CACHED_TAG_FILE" ]]; then
        CURRENT_TAG=$(<"$CACHED_TAG_FILE")
        if [[ "$CURRENT_TAG" == "$TAG_NAME" ]]; then
            echo "✅ Binary already up to date ($TAG_NAME). Running..."
            clear
            exec "$DEST"
        fi
    fi

    echo "⬇️  Downloading updated binary from release $TAG_NAME"
    curl -L "$ASSET_URL" -o "$DEST"
    chmod +x "$DEST"
    echo "$TAG_NAME" > "$CACHED_TAG_FILE"

    echo "🚀 Running picker..."
    clear
    exec "$DEST"
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

    # Logic: Check for Unverified AND Official
    if [[ "$REF" == *"$BAD"* ]] && [[ "$REF" == *"ghcr.io/ublue-os/"* ]]; then
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
    /usr/bin/steamos-add-to-steam /usr/bin/bazzite-updater
