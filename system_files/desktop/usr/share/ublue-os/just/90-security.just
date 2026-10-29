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

# Nix does not set SELinux labels on store paths it creates, so a unit built
# into the store is default_t, which init_t may not read, and `systemctl enable`
# on it fails with "Access denied" (nix-community/home-manager#8438). Every
# rebuild produces a new store path, so this has to be rerun after one.
#
# With no argument, relabels every unit under /etc/systemd/system that resolves
# into the store. An argument may be either such a unit name or a store path --
# the store path matters because `systemctl enable /nix/store/...` is denied
# before any link exists, so there is nothing in /etc to find yet:
#   ujust nix-relabel-unit
#   ujust nix-relabel-unit myservice.service
#   ujust nix-relabel-unit /nix/store/<hash>-<pkg>/lib/systemd/system

# Relabel Nix store paths holding systemd units so systemd can read them
[group("security")]
nix-relabel-unit unit="":
    #!/usr/bin/env bash
    set -euo pipefail
    shopt -s nullglob
    arg="{{ unit }}"
    dirs=()
    if [[ "$arg" == /nix/store/* || "$arg" == /var/nix/store/* ]]; then
        if [[ ! -e "$arg" ]]; then
            echo "no such path: $arg" >&2
            exit 1
        fi
        [[ -d "$arg" ]] && dirs+=("$arg") || dirs+=("$(dirname "$arg")")
    else
        if [[ -n "$arg" ]]; then
            links=("/etc/systemd/system/$arg")
            if [[ ! -e "${links[0]}" ]]; then
                echo "no such unit: ${links[0]} (pass the /nix/store path if it is not enabled yet)" >&2
                exit 1
            fi
        else
            links=(/etc/systemd/system/*.service /etc/systemd/system/*.socket /etc/systemd/system/*.timer)
        fi
        for link in ${links[@]+"${links[@]}"}; do
            target=$(readlink -f "$link" 2>/dev/null) || continue
            [[ "$target" == /nix/store/* ]] || continue
            dirs+=("$(dirname "$target")")
        done
    fi
    if [[ ${#dirs[@]} -eq 0 ]]; then
        echo "nothing to relabel: no unit resolves into /nix/store"
        exit 0
    fi
    mapfile -t dirs < <(printf '%s\n' "${dirs[@]}" | sort -u)
    sudo restorecon -Rv "${dirs[@]}"
    # restorecon is silent when no file context matches, which would leave the
    # path default_t and the unit still unreadable by systemd. Only paths under
    # a store path's lib/systemd/system are covered, so check rather than claim.
    rc=0
    for dir in "${dirs[@]}"; do
        ctx=$(stat -c %C "$dir" | cut -d: -f3)
        if [[ "$ctx" != systemd_unit_file_t ]]; then
            echo "FAILED: $dir is $ctx, not systemd_unit_file_t" >&2
            echo "  only <store path>/lib/systemd/system is labelled; see halcyon_nix_daemon_socket.cil" >&2
            rc=1
        fi
    done
    (( rc == 0 )) || exit 1
    sudo systemctl daemon-reload
    echo "Relabelled ${#dirs[@]} store path(s). Enable the unit again if it failed before."

# Audit: rules live in /etc/audit/rules.d (loaded by audit-rules.service at
# boot); see the README "Auditing" bullet for what they cover.

# Show whether auditing is enabled, locked, and how many events were lost
[group("security")]
audit-status:
    #!/usr/bin/env bash
    set -euo pipefail
    sudo auditctl -s
    echo "Loaded rules: $(sudo auditctl -l | grep -vc '^No rules')"
    [[ -e /etc/audit/rules.d/99-zz-lock.rules ]] && echo "Lock file present: rules become immutable at next load." || true

# Summarise recent audit events, then the failed ones
[group("security")]
audit-report:
    sudo aureport --input-logs --summary --failed

# Make the audit rules immutable (-e 2): they cannot be changed until reboot
[group("security")]
audit-lock:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "-e 2" | sudo tee /etc/audit/rules.d/99-zz-lock.rules >/dev/null
    sudo chmod 0600 /etc/audit/rules.d/99-zz-lock.rules
    sudo augenrules --load
    sudo auditctl -s | grep -E '^enabled'
    echo "Audit rules are locked until the next reboot. Run ujust audit-unlock to stop locking at boot."

# Stop locking the audit rules (a reboot is needed if they are locked now)
[group("security")]
audit-unlock:
    #!/usr/bin/env bash
    set -euo pipefail
    sudo rm -f /etc/audit/rules.d/99-zz-lock.rules
    if sudo auditctl -s | grep -q '^enabled 2'; then
        echo "Rules are locked in the running kernel. Reboot to unlock; the lock file is removed, so the next boot loads them unlocked."
    else
        sudo augenrules --load
        sudo auditctl -s | grep -E '^enabled'
    fi
