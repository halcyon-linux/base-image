# vim: set ft=make :

# Reclaim disk space (Nix garbage collection, Flatpak unused runtimes, journal trim)
[group("system")]
halcyon-cleanup:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "=== Cleaning up system and user caches ==="
    if command -v nix-collect-garbage >/dev/null 2>&1; then
        echo "Collecting Nix garbage (deleting old generations)..."
        nix-collect-garbage -d || true
    elif command -v nix >/dev/null 2>&1; then
        # the classic command only materializes once a nix profile exists;
        # the new CLI garbage-collects regardless
        echo "Collecting Nix garbage (nix store gc)..."
        nix store gc || true
    fi
    if command -v flatpak >/dev/null 2>&1; then
        echo "Uninstalling unused Flatpak runtimes..."
        flatpak uninstall --unused -y || true
    fi
    echo "Trimming journald logs (system journal needs privileges)..."
    sudo journalctl --vacuum-time=7d || true
    echo "Cleanup complete!"
