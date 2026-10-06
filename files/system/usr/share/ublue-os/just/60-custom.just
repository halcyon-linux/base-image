# halcyon's own ujust modules — recipes shared with the bazzite base are NOT
# carried here (bazzite's win: `just` hard-errors on duplicate aliases). The
# ublue-os-just RPM ships the justfile's `import?` hook for this path, and
# the ujust-system verify tail gates this list against the recipes beside it.
import "/usr/share/ublue-os/just/halcyon-cleanup.just"
import "/usr/share/ublue-os/just/halcyon-doom-setup.just"
import "/usr/share/ublue-os/just/halcyon-dots.just"
import "/usr/share/ublue-os/just/halcyon-home-manager-setup.just"
import "/usr/share/ublue-os/just/halcyon-rebase.just"
import "/usr/share/ublue-os/just/halcyon-texlive.just"
