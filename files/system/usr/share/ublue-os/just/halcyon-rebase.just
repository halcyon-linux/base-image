# vim: set ft=make :

# Rebase the current system to the published halcyon image
# (README: Install / rebase — unsigned first, signed tag after reboot).
# registry= accepts the docker.io mirror (same tags, second push in
# build.yml) when ghcr.io is slow:
#   ujust rebase-to-custom latest docker.io/halcyon-linux/halcyon
[group("system")]
rebase-to-custom tag="latest" registry="ghcr.io/halcyon-linux/halcyon":
    #!/usr/bin/env bash
    set -euo pipefail
    IMAGE="{{registry}}:{{tag}}"
    echo "Rebasing system to ${IMAGE}..."
    if command -v bootc >/dev/null 2>&1; then
        sudo bootc switch "${IMAGE}"
    elif command -v rpm-ostree >/dev/null 2>&1; then
        sudo rpm-ostree rebase "ostree-unverified-registry:${IMAGE}"
    else
        echo "Neither bootc nor rpm-ostree was detected on this system." >&2
        exit 1
    fi
    echo "Rebase prepared successfully!"
    echo "Reboot into the new deployment:  systemctl reboot"
    echo "After reboot, switch to the signed tag (README: Install / rebase):"
    echo "  sudo bootc switch --enforce-container-sigpolicy ostree-image-signed:docker://{{registry}}:{{tag}}"
    echo "  (the image ships /etc/pki/containers/halcyon.pub + a sigstore policy entry — verification is enforced by policy.json)"
