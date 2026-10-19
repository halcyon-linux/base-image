# vim: set ft=make :

alias upgrade := update

# Update the system and installed apps all at once
[group("system")]
update:
    #!/usr/bin/bash
    set -Eeuo pipefail
    /usr/bin/uupd-update | jq -r -R 'fromjson? | [(.title, .msg, .description) | select(.)] | join(" ")'

alias changelog := changelogs

# Open the Halcyon image's recent changes.
[group("system")]
changelogs:
    #!/usr/bin/bash
    xdg-open https://github.com/halcyon-linux/base-image/commits/containerfile
