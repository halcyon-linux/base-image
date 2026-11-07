# vim: set ft=make :

alias patch-gmod := fix-gmod

# Patch GMod's 64-bit beta to work properly on Linux (https://github.com/solsticegamestudios/GModPatchTool)
[group("gaming")]
fix-gmod:
    #!/usr/bin/bash
    /usr/bin/gmodpatchtool

# Kills all processes related to wine and proton. This forces it to restart next time you launch the game (you might still have to press STOP in steam to kill the game binary)
[group("gaming")]
fix-proton-hang:
    #!/usr/bin/bash
    PROTONCORE=(pv-bwrap pressure-vessel reaper explorer.exe rpcss.exe plugplay.exe services.exe svchost.exe winedevice.exe wineserver)
    for PROG in "${PROTONCORE[@]}"; do
      killall -q -9 "$PROG" 2>/dev/null || true
    done

# Toggle Bluetooth headset profile mode. If enabled, mic will be disabled on the Bluetooth device preventing the switch to headset profile, which has poor audio quality. Disable to restore mic functionality.
[group("audio")]
toggle-bt-mic ACTION="":
    #!/usr/bin/bash
    source /usr/lib/ujust/ujust.sh
    CONFIG_FILE="/etc/wireplumber/wireplumber.conf.d/51-mitigate-annoying-profile-switch.conf"
    OPTION="{{ ACTION }}"
    # Check current status
    CURRENT_STATE="Disabled"
    if [ -f "$CONFIG_FILE" ]; then
      CURRENT_STATE="Enabled"
    fi

    if [ "$OPTION" == "help" ]; then
      echo "Usage: ujust toggle-bt-mic <option>"
      echo "  <option>: Specify the option to skip the interactive prompt"
      echo "  Use 'status' to print the current portal status"
      echo "  Use 'enable' to disable Bluetooth headset profile switching"
      echo "  Use 'disable' to restore Bluetooth headset profile switching"
      exit 0
    elif [ "$OPTION" == "status" ]; then
      if [ "$CURRENT_STATE" == "Enabled" ]; then
        echo "enable"
      else
        echo "disable"
      fi
      exit 0
    fi

    # Prompt user for action
    if [ "$OPTION" == "" ]; then
      echo "Enable or Disable Bluetooth headset profile mitigation?"
      if [ "$CURRENT_STATE" == "Enabled" ]; then
        echo -e "${bold}Bluetooth headset profile mitigation:${normal} ${green}${CURRENT_STATE}${normal}"
      else
        echo -e "${bold}Bluetooth headset profile mitigation:${normal} ${red}${CURRENT_STATE}${normal}"
      fi
      OPTION=$(ugum choose Enable Disable)
    fi

    if [[ "${OPTION,,}" == "enable" ]]; then
      echo "You chose to enable mitigation. This will disable headset mic functionality."
      echo "Requesting root privileges..."
      sudo mkdir -p "$(dirname "$CONFIG_FILE")"
      echo 'wireplumber.settings = {' | sudo tee "$CONFIG_FILE" > /dev/null
      echo '  bluetooth.autoswitch-to-headset-profile = false' | sudo tee -a "$CONFIG_FILE" > /dev/null
      echo '}' | sudo tee -a "$CONFIG_FILE" > /dev/null
      echo '' | sudo tee -a "$CONFIG_FILE" > /dev/null
      echo 'monitor.bluez.properties = {' | sudo tee -a "$CONFIG_FILE" > /dev/null
      echo '  bluez5.roles = [ a2dp_sink a2dp_source ]' | sudo tee -a "$CONFIG_FILE" > /dev/null
      echo '}' | sudo tee -a "$CONFIG_FILE" > /dev/null
      systemctl --user restart wireplumber
      echo "Mitigation has been ${green}${b}enabled${n}. Headset profile switching is now disabled."
    elif [[ "${OPTION,,}" == "disable" ]]; then
      echo "You chose to disable mitigation. This will restore headset mic functionality."
      echo "Requesting root privileges..."
      if sudo rm -f "$CONFIG_FILE"; then
        systemctl --user restart wireplumber
        echo "Mitigation has been ${red}${b}disabled${n}. Headset profile switching is now allowed."
      else
        echo "Failed to disable mitigation. Ensure you have sufficient permissions."
      fi
    else
      echo "No changes were made."
    fi

# Toggle GPP0 wakeup fix to prevent unwanted system wake-ups, primarily affects Gigabyte motherboards.
[group("hardware")]
toggle-gigabyte-wake-fix:
    #!/usr/bin/bash
    source /usr/lib/ujust/ujust.sh
    SERVICE_FILE="/etc/systemd/system/biosWakeupWorkaround.service"

    if systemctl is-enabled biosWakeupWorkaround.service &>/dev/null; then
      echo "Current status: ${green}${bold}enabled${normal}"
      CHOICE=$(ugum choose "Disable GPP0 wakeup fix" "Exit without changes")
      if [[ "$CHOICE" == "Disable GPP0 wakeup fix" ]]; then
        sudo systemctl disable --now biosWakeupWorkaround.service
        sudo rm -f "$SERVICE_FILE"
        sudo systemctl daemon-reload
        echo "GPP0 wakeup fix ${red}${bold}disabled${normal} and service file removed."
      else
        echo "No changes made."
      fi
    else
      echo "Current status: ${red}${bold}disabled${normal}"
      CHOICE=$(ugum choose "Enable GPP0 wakeup fix" "Exit without changes")
      if [[ "$CHOICE" == "Enable GPP0 wakeup fix" ]]; then
        {
          echo "[Unit]"
          echo "Description=Workaround for Gigabyte BIOS sleep/wakeup bug"
          echo ""
          echo "[Service]"
          echo "Type=oneshot"
          echo 'ExecStart=/bin/sh -c '"'"'if grep GPP0 /proc/acpi/wakeup | grep -q enabled; then echo GPP0 > /proc/acpi/wakeup; fi'"'"
          echo ""
          echo "[Install]"
          echo "WantedBy=multi-user.target"
        } | sudo tee "$SERVICE_FILE" > /dev/null
        sudo systemctl daemon-reload
        sudo systemctl enable --now biosWakeupWorkaround.service
        echo "GPP0 wakeup fix ${green}${bold}enabled${normal}."
      else
        echo "No changes made."
      fi
    fi

# Manage Intel Ethernet fix (Disables ASPM and sets PCIe policy to Performance). Options: status | enable | disable
[group("network")]
manage-intel-ethernet ACTION="":
    #!/usr/bin/env bash
    # 1. Capture current state
    CURRENT_KARGS=$(rpm-ostree kargs)
    get_status_token() {
        if echo "$CURRENT_KARGS" | grep -q "pcie_aspm.policy=performance" && echo "$CURRENT_KARGS" | grep -q "pcie_aspm=off"; then
            echo "enable"
        else
            echo "disable"
        fi
    }
    get_current_status() {
        if [[ "$(get_status_token)" == "enable" ]]; then
            echo "Disable ASPM & Set Performance Policy"
        else
            echo "Defaults"
        fi
    }
    OPTION="{{ ACTION }}"
    if [ "$OPTION" == "help" ]; then
        echo "Usage: ujust manage-intel-ethernet <option>"
        echo "  <option>: Specify the option to skip the interactive prompt"
        echo "  Use 'enable' to apply the Intel Ethernet stability fix"
        echo "  Use 'disable' to restore Intel Ethernet defaults"
        echo "  Use 'status' to print the current fix state"
        exit 0
    elif [ "$OPTION" == "status" ]; then
        get_status_token
        exit 0
    fi
    echo -e "This script manages a stability fix for Intel I225-V and I226-V Ethernet controllers."
    echo -e "It disables PCIe Active State Power Management (ASPM) and sets the PCIe policy to performance to prevent hardware hangs, failed register reads, and total connection drops."
    echo -e "\nCurrent setting: $(get_current_status)\n"
    if [ -z "$OPTION" ]; then
        OPTION=$(gum choose "Disable ASPM & Performance Policy" "Restore Defaults" "Exit without changes")
    fi

    case "$OPTION" in
      "Disable ASPM & Performance Policy"|enable)
        if ! lspci | grep -Ei "I225|I226|I221|I222" > /dev/null; then
             gum style --foreground 196 "Error: No compatible Intel NIC detected."
             exit 0
        fi

        # 2. Only run rpm-ostree if the fix is actually missing
        if echo "$CURRENT_KARGS" | grep -q "pcie_aspm.policy=performance" && echo "$CURRENT_KARGS" | grep -q "pcie_aspm=off"; then
            gum style --foreground 212 "Notice: Fixes are already applied in kargs."
        else
            echo "Applying Intel Ethernet stability fixes..."
            # Added deletion of the old ignored EEE arg and appended the new policy
            rpm-ostree kargs --delete='igc.EEE=0' --append-if-missing='pcie_aspm=off' --append-if-missing='pcie_aspm.policy=performance'
            echo "Done! Please reboot to apply changes."
        fi
        ;;
      "Restore Defaults"|disable)
        if ! echo "$CURRENT_KARGS" | grep -q "pcie_aspm=off"; then
            gum style --foreground 117 "Notice: System is already at defaults."
        else
            echo "Restoring Intel Ethernet defaults..."
            rpm-ostree kargs --delete='igc.EEE=0' --delete='pcie_aspm=off' --delete='pcie_aspm.policy=performance'
            echo "Defaults restored. Please reboot."
        fi
        ;;
      "Exit without changes"|*)
        echo "No changes made."
        ;;
    esac

# Manage PCIe Power Management fix. Options: status | enable | disable
[group("hardware")]
manage-pcie-power ACTION="":
    #!/usr/bin/env bash
    CURRENT_KARGS=$(rpm-ostree kargs)
    get_status_token() {
        if echo "$CURRENT_KARGS" | grep -q "pcie_port_pm=off"; then
            echo "enable"
        else
            echo "disable"
        fi
    }
    get_current_status() {
        if [[ "$(get_status_token)" == "enable" ]]; then
            echo "Disable PCIe Port PM"
        else
            echo "Defaults"
        fi
    }
    OPTION="{{ ACTION }}"
    if [ "$OPTION" == "help" ]; then
        echo "Usage: ujust manage-pcie-power <option>"
        echo "  <option>: Specify the option to skip the interactive prompt"
        echo "  Use 'enable' to disable PCIe Port Power Management"
        echo "  Use 'disable' to restore PCIe Port Power Management defaults"
        echo "  Use 'status' to print the current fix state"
        exit 0
    elif [ "$OPTION" == "status" ]; then
        get_status_token
        exit 0
    fi
    echo -e "This script manages PCIe Port Power Management for maximum hardware stability."
    echo -e "Disabling PCIe Port Power Management prevents the PCIe bus from entering low-power states that can cause micro-stuttering in games, latency spikes for NVMe drives, or wake-from-sleep issues on modern AMD Ryzen systems."
    echo -e "Recommended for users seeking the lowest possible system latency."
    echo -e "\nCurrent setting: $(get_current_status)\n"
    if [ -z "$OPTION" ]; then
        OPTION=$(gum choose "Disable PCIe Port PM" "Restore Defaults" "Exit without changes")
    fi

    case "$OPTION" in
      "Disable PCIe Port PM"|enable)
        if echo "$CURRENT_KARGS" | grep -q "pcie_port_pm=off"; then
            gum style --foreground 212 "Notice: PCIe Port PM fix is already applied."
        else
            echo "Disabling PCIe Port Power Management..."
            rpm-ostree kargs --append-if-missing='pcie_port_pm=off'
            echo "Done! Please reboot to apply changes."
        fi
        ;;
      "Restore Defaults"|disable)
        if ! echo "$CURRENT_KARGS" | grep -q "pcie_port_pm=off"; then
            gum style --foreground 117 "Notice: System is already at defaults."
        else
            echo "Restoring PCIe Port Power Management defaults..."
            rpm-ostree kargs --delete='pcie_port_pm=off'
            echo "Defaults restored. Please reboot."
        fi
        ;;
      "Exit without changes"|*)
        echo "No changes made."
        ;;
    esac
