# vim: set ft=make :

# Configure beesd for BTRFS filesystems
[group("system")]
configure-beesd ACTION="":
    #!/usr/bin/bash
    source /usr/lib/ujust/ujust.sh

    # Constants for bees hash table sizing
    readonly MIN_FS_TB=1
    readonly MAX_FS_TB=4
    readonly HASH_SIZE_MB_PER_TB=512

    remove_beesd_config() {
        local uuid="$1"
        echo "Removing configuration..."
        sudo systemctl disable --now "beesd@${uuid}.timer"
        sudo systemctl stop "beesd@${uuid}.service" 2>/dev/null || true
        sudo rm "/etc/bees/${uuid}.conf"
        sudo rm -f "/etc/systemd/system/beesd@${uuid}.service.d/override.conf"
        sudo rmdir "/etc/systemd/system/beesd@${uuid}.service.d" 2>/dev/null || true
        echo "Configuration removed and timer disabled."

        echo "Cleaning leftover data"
        fs_root=$(findmnt --source UUID="$uuid" -o TARGET,OPTIONS | grep "subvolid=5" | awk '{print $1}')
        is_manual_mount=false
        if [[ -z "$fs_root" ]]; then
            fs_root="/run/bees/mnt/${uuid}"
            sudo mkdir -p "$fs_root"
            if ! sudo mount -o subvolid=5 UUID="$uuid" "$fs_root"; then
                fs_root=""
            else
                is_manual_mount=true
            fi
        fi

        if [[ -n "$fs_root" ]]; then
            beeshome_id=$(sudo btrfs subvolume list "$fs_root" -t | grep "\.beeshome" | awk '{print $1}')
            if [[ -n "$beeshome_id" ]]; then
                echo "Found .beeshome subvolume with ID: $beeshome_id"
                sudo btrfs subvolume delete -i "$beeshome_id" "$fs_root"
                echo "Deleted .beeshome subvolume"
            else
                echo "No .beeshome subvolume found"
            fi

            if [[ "$is_manual_mount" == true ]]; then
                sudo umount "$fs_root"
                sleep 1
                # Device might still be busy
                # Not critical if this fails
                sudo rmdir "$fs_root" >/dev/null 2>&1
            fi
        fi

        sudo systemctl daemon-reload
    }

    while true; do
        # Get btrfs filesystem info
        mapfile -t raw_btrfs_output < <(sudo lsblk --fs --list --noheadings --output "NAME,UUID,SIZE" --filter 'FSTYPE == "btrfs"' --bytes)

        if [[ ${#raw_btrfs_output[@]} -eq 0 ]]; then
          echo "No BTRFS filesystems found."
          exit 0
        fi

        # Check for existing configurations
        unset configured_uuids
        declare -A configured_uuids
        if [[ -d "/etc/bees" ]]; then
            for config in /etc/bees/*.conf; do
                if [[ -f "$config" ]]; then
                    filename=$(basename "$config" .conf)
                    configured_uuids["$filename"]=1
                fi
            done
        fi

        # Create menu options and size map
        menu_options=()
        unset filesystem_size_map
        declare -A filesystem_size_map
        for line in "${raw_btrfs_output[@]}"; do
            read -r name uuid size_bytes <<< "$line"
            # Convert bytes to human readable for display
            size_human=$(numfmt --to=iec-i --suffix=B "$size_bytes")
            filesystem_size_map["$uuid"]="$size_bytes"

            if [[ -n "${configured_uuids[$uuid]}" ]]; then
                menu_options+=("$name $uuid $size_human (Configured)")
            else
                menu_options+=("$name $uuid $size_human")
            fi
        done
        menu_options+=("Exit")

        echo "Select a BTRFS filesystem:"
        CHOICE=$(ugum choose "${menu_options[@]}")

        if [[ "$CHOICE" == "Exit" ]] || [[ -z "$CHOICE" ]]; then
            exit 0
        fi

        UUID=$(echo "$CHOICE" | awk '{print $2}')
        SIZE_BYTES="${filesystem_size_map[$UUID]}"

        if [[ -f "/etc/bees/${UUID}.conf" ]]; then
            echo "Configuration already exists for UUID: ${UUID}"
            ACTION=$(ugum choose "Remove configuration" "Reinstall/Overwrite" "Back")
        else
            ACTION=$(ugum choose "Create configuration" "Back")
        fi

        case "$ACTION" in
            "Remove configuration")
                remove_beesd_config "$UUID"
                continue
                ;;
            "Back")
                continue
                ;;
            "")
                exit 0
                ;;
        esac

        # Round up to nearest TB by adding 0.5TB-->B and flooring
        size_tb=$(((SIZE_BYTES + 500000000000) / 1000**4))
        # Clamp filesystem size between min/max for hash table calculation
        # Avoid eating too much memory when bees starts
        size_tb=$(($size_tb < $MIN_FS_TB ? $MIN_FS_TB : $size_tb))
        size_tb=$(($size_tb > $MAX_FS_TB ? $MAX_FS_TB : $size_tb))
        # Bees Hash Table Sizing
        # Size MUST be multiple of 128KB
        # DB_SIZE=$((1024*1024*1024)) # 1G in bytes
        db_size=$((size_tb * $HASH_SIZE_MB_PER_TB * 1024**2))
        # Convert db_size from bytes to MB for memory threshold
        mem_thresh_mb=$((db_size / 1024**2))

        sudo mkdir -p /etc/bees
        sudo cp /usr/etc/bees/beesd.conf.sample "/etc/bees/${UUID}.conf"
        # https://github.com/Zygo/bees/blob/master/docs/options.md#load-management-options
        sudo sed -i "s/^UUID=.*/UUID=${UUID}/" "/etc/bees/${UUID}.conf"
        sudo sed -i "s/# DB_SIZE=.*/DB_SIZE=${db_size}/" "/etc/bees/${UUID}.conf"
        sudo sed -i "s/# OPTIONS=.*/OPTIONS=\"--strip-paths --no-timestamps --thread-factor 0.125 --thread-min 1 --throttle-factor 100\"/" "/etc/bees/${UUID}.conf"
        echo "Created /etc/bees/${UUID}.conf with DB_SIZE=${db_size} bytes"

        # Only start the service if enough memory is free
        # Per service as hash table size may differ in each configuration
        sudo mkdir -p "/etc/systemd/system/beesd@${UUID}.service.d"
        {
            echo "[Service]"
            echo "ExecCondition=/bin/sh -c \"test \$(free -m | awk '/^Mem:/ {print \$7}') -gt ${mem_thresh_mb}\""
        } | sudo tee "/etc/systemd/system/beesd@${UUID}.service.d/override.conf" > /dev/null

        sudo systemctl daemon-reload
        sudo systemctl enable --now "beesd@${UUID}.timer"
    done
# vim: set ft=make :

# Manage input remapper feature on non-desktop images. Options: status | enable | disable
restore-input-remapper ACTION="":
    #!/usr/bin/bash
    source /usr/lib/ujust/ujust.sh
    DESKTOP_FILE="$HOME/.local/share/applications/input-remapper-gtk.desktop"
    AUTOSTART_FILE="$HOME/.config/autostart/input-remapper-autoload.desktop"
    get_status_token() {
        if systemctl is-enabled --quiet input-remapper.service && [[ -f "$DESKTOP_FILE" ]]; then
            echo "enable"
        else
            echo "disable"
        fi
    }
    get_current_status() {
        if [[ "$(get_status_token)" == "enable" ]]; then
            echo "Enabled"
        else
            echo "Disabled"
        fi
    }
    enable_input_remapper() {
        systemctl enable --now input-remapper.service
        mkdir -p "$HOME/.local/share/applications" "$HOME/.config/autostart"
        cp /usr/share/applications/input-remapper-gtk.desktop "$DESKTOP_FILE"
        sed -i '/NoDisplay=true/d' "$DESKTOP_FILE"
        if [[ -f /etc/xdg/autostart/input-remapper-autoload.desktop ]]; then
            cp /etc/xdg/autostart/input-remapper-autoload.desktop "$AUTOSTART_FILE"
            sed -i '/Hidden=true/d' "$AUTOSTART_FILE"
        fi
        echo "Input Remapper has been enabled."
    }
    disable_input_remapper() {
        systemctl disable --now input-remapper.service
        rm -f "$DESKTOP_FILE" "$AUTOSTART_FILE"
        echo "Input Remapper has been disabled."
    }
    OPTION="{{ ACTION }}"
    if [[ "$OPTION" == "help" ]]; then
        echo "Usage: ujust restore-input-remapper <option>"
        echo "  <option>: Specify the quick option to skip the prompt"
        echo "  Use 'status' to print the current portal token"
        echo "  Use 'enable' to enable Input Remapper"
        echo "  Use 'disable' to disable Input Remapper"
        exit 0
    elif [[ "$OPTION" == "status" ]]; then
        get_status_token
        exit 0
    elif [[ "$OPTION" == "enable" ]]; then
        enable_input_remapper
        exit 0
    elif [[ "$OPTION" == "disable" ]]; then
        disable_input_remapper
        exit 0
    elif [[ -z "$OPTION" ]]; then
        current_status=$(get_current_status)
        echo "${bold}Input Remapper${normal}"
        echo "Current status: $current_status"
        OPTION=$(ugum choose "Enable" "Disable" "Exit without changes")
        case "$OPTION" in
            "Enable")
                enable_input_remapper
                ;;
            "Disable")
                disable_input_remapper
                ;;
            *)
                echo "No changes made."
                ;;
        esac
        exit 0
    fi
# vim: set ft=make :
