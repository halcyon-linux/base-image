# vim: set ft=make :

# Round-trip edits to the dotfiles repo cloned by the chezmoi module at
# ~/.local/share/chezmoi (https://github.com/aahsnr-configs/dotfiles — remote
# uses the github.com-halcyon-configs SSH host alias created by git-setup)

# Flip the dotfiles origin to SSH (needed after a fresh HTTPS-only clone)
[group("dotfiles")]
dots-ssh:
    #!/usr/bin/env bash
    set -euo pipefail
    DOTS_DIR="${DOTS_DIR:-$(chezmoi source-path)}"
    cd "${DOTS_DIR}"
    git remote set-url origin git@github.com-halcyon-configs:aahsnr-configs/dotfiles.git
    git remote -v

# Stage, commit and push all dotfiles changes
[group("dotfiles")]
dots-push msg="updated":
    #!/usr/bin/env bash
    set -euo pipefail
    DOTS_DIR="${DOTS_DIR:-$(chezmoi source-path)}"
    cd "${DOTS_DIR}"
    git add -A
    git commit -m "{{msg}}"
    git push origin main
    echo "Dotfiles pushed: {{msg}}"

# Show dotfiles branch/status and the last few commits
[group("dotfiles")]
dots-status:
    #!/usr/bin/env bash
    set -euo pipefail
    DOTS_DIR="${DOTS_DIR:-$(chezmoi source-path)}"
    cd "${DOTS_DIR}"
    git status -sb
    echo
    git log --oneline -5
