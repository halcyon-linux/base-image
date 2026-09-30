# halcyon custom modules (bazzite-derived + halcyon's own recipes)
# Static overlay file — the ublue-os-just RPM ships the justfile's
# `import?` hook for this path. Keep the list in sync with the recipes
# shipped beside it; the ujust-system verify tail gates that sync.
import "/usr/share/ublue-os/just/80-halcyon.just"
import "/usr/share/ublue-os/just/81-halcyon-fixes.just"
import "/usr/share/ublue-os/just/83-halcyon-audio.just"
import "/usr/share/ublue-os/just/87-halcyon-framegen.just"
import "/usr/share/ublue-os/just/halcyon-cleanup.just"
import "/usr/share/ublue-os/just/halcyon-doom-setup.just"
import "/usr/share/ublue-os/just/halcyon-dots.just"
import "/usr/share/ublue-os/just/halcyon-home-manager-setup.just"
import "/usr/share/ublue-os/just/halcyon-rebase.just"
import "/usr/share/ublue-os/just/halcyon-texlive.just"
