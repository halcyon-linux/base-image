# vim: set ft=make :

# User-mode TeX Live package management into ~/texmf
# (system tree is baked at /usr/lib/texlive; PATH via /etc/profile.d/texlive.sh)

# Install a TeX Live package in user mode into ~/texmf
[group("texlive")]
texlive-install package:
    #!/usr/bin/env bash
    set -euo pipefail
    if ! command -v tlmgr >/dev/null 2>&1; then
        [ -f /etc/profile.d/texlive.sh ] && . /etc/profile.d/texlive.sh
    fi
    if command -v tlmgr >/dev/null 2>&1; then
        if [ ! -d "$HOME/texmf" ]; then
            echo "Initializing TeX Live usertree in $HOME/texmf..."
            tlmgr init-usertree
        fi
        echo "Installing TeX Live package '{{package}}' in user mode..."
        tlmgr --usermode install "{{package}}"
        echo "Package '{{package}}' installed successfully into $HOME/texmf."
    else
        echo "tlmgr not found in PATH." >&2
        exit 1
    fi

# Update all user-installed TeX Live packages in ~/texmf
[group("texlive")]
texlive-update:
    #!/usr/bin/env bash
    set -euo pipefail
    if ! command -v tlmgr >/dev/null 2>&1; then
        [ -f /etc/profile.d/texlive.sh ] && . /etc/profile.d/texlive.sh
    fi
    if command -v tlmgr >/dev/null 2>&1; then
        echo "Updating user TeX Live packages in $HOME/texmf..."
        tlmgr --usermode update --all
    else
        echo "tlmgr not found in PATH." >&2
        exit 1
    fi
