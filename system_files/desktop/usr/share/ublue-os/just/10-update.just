# vim: set ft=make :

alias upgrade := update

# Update the system and installed apps all at once
[group("system")]
update:
    #!/usr/bin/bash
    set -Eeuo pipefail
    /usr/bin/uupd-update | jq -r -R 'fromjson? | [(.title, .msg, .description) | select(.)] | join(" ")'

# Run topgrade with the image's bootc-aware config (not ~/.config/topgrade.toml)
[group("system")]
topgrade:
    #!/usr/bin/bash
    set -Eeuo pipefail
    exec /usr/bin/topgrade --config /usr/share/ublue-os/topgrade.toml

alias changelog := changelogs

# Open the Halcyon image's recent changes.
[group("system")]
changelogs:
    #!/usr/bin/bash
    xdg-open https://github.com/halcyon-linux/base-image/commits/containerfile
