# vim: set ft=make :

# Bootstrap Nix Home Manager (standalone) after first login
[group("nix")]
home-manager-setup:
    #!/usr/bin/bash
    set -euo pipefail

    CONFIG_DIR="$HOME/.config/home-manager"

    if [[ -e "${CONFIG_DIR}" ]]; then
        echo "${CONFIG_DIR} already exists; Home Manager looks like it's already set up." >&2
        echo "To update it instead, run: home-manager switch" >&2
        exit 1
    fi

    if ! command -v nix >/dev/null 2>&1; then
        echo "nix not found on PATH; is the nix/nix-daemon module enabled?" >&2
        exit 1
    fi

    echo "Bootstrapping Home Manager via nix run home-manager/master..."
    nix run home-manager/master -- init --switch

    echo
    echo "Home Manager is installed and activated. Future updates:"
    echo "  home-manager switch"

