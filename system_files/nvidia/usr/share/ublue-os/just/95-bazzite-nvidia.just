# vim: set ft=make :

update-nvidia-runtime ACTION="":
    #!/usr/bin/bash
    set -Eeuo pipefail
    source /usr/lib/ujust/ujust.sh
    get_status_token() {
        local output
        if output="$(/usr/bin/nvidia-flatpak-runtime-sync check 2>&1)"; then
            echo "mismatch"
        elif [[ "$output" == *"already installed"* ]]; then
            echo "upgraded"
        else
            printf '%s\n' "$output" >&2
            return 1
        fi
    }
    OPTION="{{ ACTION }}"
    if [[ "$OPTION" == "help" ]]; then
        echo "Usage: ujust update-nvidia-runtime <option>"
        echo "  <option>: Specify the quick option to skip the prompt"
        echo "  Use 'status' to print the current portal token"
        echo "  Use 'upgrade' to upgrade"
        exit 0
    elif [[ "$OPTION" == "status" ]]; then
        get_status_token
        exit $?
    elif [[ "$OPTION" == "upgrade" ]]; then
        /usr/bin/nvidia-flatpak-runtime-sync sync
    elif [[ -z "$OPTION" ]]; then
        echo "Usage: ujust update-nvidia-runtime <status|upgrade|help>" >&2
        exit 2
    else
        echo "Unknown option: $OPTION" >&2
        exit 2
    fi
