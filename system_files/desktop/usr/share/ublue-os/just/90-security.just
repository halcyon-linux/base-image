# vim: set ft=make :

# File integrity (AIDE): weekly timer, baseline on first boot.
[group("security")]
aide-init:
    sudo systemctl start halcyon-aide-init.service

[group("security")]
aide-check:
    sudo systemctl start halcyon-aide-check.service

[group("security")]
aide-rebaseline:
    #!/usr/bin/env bash
    set -euo pipefail
    sudo rm -f /var/lib/aide/aide.db.gz
    sudo systemctl start halcyon-aide-init.service
    echo "Baseline recreated from the current system state."
