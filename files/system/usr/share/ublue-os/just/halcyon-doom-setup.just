# vim: set ft=make :

# Set up Doom Emacs after first login
[group("doom")]
doom-setup:
    #!/usr/bin/bash
    set -euo pipefail

    if [[ -e "$HOME/.config/doom" ]]; then
        echo "~/.config/doom already exists; aborting to avoid clobbering it." >&2
        exit 1
    fi

    echo "Cloning Doom Emacs configuration..."
    git clone git@github.com-halcyon-configs:aahsnr-configs/doom.git "$HOME/.config/doom"
    echo "(doom! :config literate)" > "$HOME/.config/doom/init.el"
    git clone --depth 1 https://github.com/doomemacs/core "$HOME/.config/emacs"

    echo "Installing Doom Emacs..."
    "$HOME/.config/emacs/bin/doom" install
    "$HOME/.config/emacs/bin/doom" sync --gc

    echo
    echo "Doom Emacs is set up. Start it with: emacs"

