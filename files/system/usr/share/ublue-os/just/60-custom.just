# halcyon's own ujust modules. Recipes that also exist in the bazzite base
# are NOT carried here — bazzite's versions win, and `just` hard-errors on
# duplicate aliases (ujust --list died on toggle-ssh & co. before the
# dedupe). Static overlay file — the ublue-os-just RPM ships the justfile's
# `import?` hook for this path. Keep the list in sync with the recipes
# shipped beside it; the ujust-system verify tail gates that sync.
import "/usr/share/ublue-os/just/halcyon-cleanup.just"
import "/usr/share/ublue-os/just/halcyon-doom-setup.just"
import "/usr/share/ublue-os/just/halcyon-dots.just"
import "/usr/share/ublue-os/just/halcyon-home-manager-setup.just"
import "/usr/share/ublue-os/just/halcyon-rebase.just"
import "/usr/share/ublue-os/just/halcyon-texlive.just"
