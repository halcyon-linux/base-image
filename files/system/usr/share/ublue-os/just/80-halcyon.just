# vim: set ft=make :
#
# halcyon 80-halcyon.just — curated subset of bazzite 80-bazzite.just
# (upstream: github.com/ublue-os/bazzite, system_files/desktop/shared/
# usr/share/ublue-os/just/80-bazzite.just).
# Dropped: automounting/framework/steamos-automount (ublue media-automount
# not installed), tailscale, configure-amd-hdmi21 + FSR4 recipes (AMD),
# configure-snapshots (snapper), bazzite-cli,
# _toggle-steamdeck-alias (deck), _install-system-flatpaks,
# _disable-ntfs-service (bazzite-only).
# Adapted for bootc: kernel args -> grubby (reads /proc/cmdline),
# ugum choose -> Choose,
# get-logs -> bootc status.

alias toggle-ssh := ssh

# Manage SSH availability on boot. Options: status | enable | disable
[group("network")]
ssh ACTION="":
    #!/usr/bin/bash
    source /usr/lib/ujust/ujust.sh
    SSH_STATE="$(systemctl is-enabled sshd 2>/dev/null || true)"
    get_status_token() {
      if [[ -z "$SSH_STATE" ]]; then
        return 1
      elif [[ "$SSH_STATE" == *enabled* ]]; then
        echo "enable"
      else
        echo "disable"
      fi
    }
    OPTION="{{ ACTION }}"
    if [ "$OPTION" == "status" ]; then
      get_status_token
      exit $?
    fi
    # Get hostname and IP address
    HOSTNAME=$(hostname)
    IP_ADDRESS=$(hostname -I | awk '{print $1}') # First IP address
    # Get current SSH status
    SSH_STATUS="Disabled"
    if [[ "$(get_status_token)" == "enable" ]]; then
      SSH_STATUS="Enabled"
    fi
    if [ "$OPTION" == "help" ]; then
      echo "Usage: ujust ssh <option>"
      echo "  <option>: Specify the option to skip the interactive prompt"
      echo "  Use 'enable' to enable SSH on boot"
      echo "  Use 'disable' to disable SSH on boot"
      exit 0
    elif [ "$OPTION" == "" ]; then
      # Display current status
      echo -e "\n${bold}Hostname:${normal} $HOSTNAME"
      echo -e "${bold}IP Address:${normal} $IP_ADDRESS"
      if [ "$SSH_STATUS" == "Enabled" ]; then
        echo -e "${bold}SSH Availability on Boot:${normal} ${green}$SSH_STATUS${normal}\n"
      else
        echo -e "${bold}SSH Availability on Boot:${normal} ${yellow}$SSH_STATUS${normal}\n"
      fi
      # Prompt user for action
      echo "Choose an option:"
      OPTION=$(Choose "Enable SSH" "Disable SSH" "Exit without saving")
    fi
    case "$OPTION" in
      "Enable SSH"|enable)
        echo "Enabling SSH on boot..."
        sudo systemctl enable --now sshd
        echo -e "SSH is now ${green}Enabled${normal}. You can SSH using:"
        echo -e "${bold}${USER}@${IP_ADDRESS}${normal}"
        echo " "
        ;;
      "Disable SSH"|disable)
        echo "Disabling SSH on boot..."
        sudo systemctl disable --now sshd
        echo -e "SSH is now ${yellow}Disabled${normal}."
        echo " "
        ;;
      "Exit without saving"|*)
        echo "No changes made."
        ;;
    esac

alias toggle-reisub := reisub

# Manage REISUB, useful for force rebooting systems when pageflip timeouts and/or other horrible things happen. Options: status | enable | disable
[group("system")]
reisub ACTION="":
    #!/usr/bin/bash
    set -euo pipefail
    source /usr/lib/ujust/ujust.sh
    FILE="/etc/sysctl.d/90-sysrq.conf"
    get_status_token() {
      if [[ -f "$FILE" ]]; then
        echo "enable"
      else
        echo "disable"
      fi
    }
    CURRENT="Disabled"
    if [[ "$(get_status_token)" == "enable" ]]; then
      CURRENT="Enabled"
    fi
    OPTION="{{ ACTION }}"
    if [[ "$OPTION" == "status" ]]; then
      get_status_token
      exit 0
    fi
    if [[ -z "$OPTION" ]]; then
      echo -e "${bold}REISUB keys:${normal} $CURRENT"
      echo ""
      OPTION="$(Choose "Enable" "Disable" "Exit without saving")"
    fi
    case "$OPTION" in
      Enable|enable)
        echo "kernel.sysrq = 1" | sudo tee "$FILE" > /dev/null
        sudo systemctl restart systemd-sysctl.service
        echo -e "${bold}${green}Enabled${normal}: kernel.sysrq=1"
        ;;
      Disable|disable)
        sudo rm -f "$FILE"
        sudo systemctl restart systemd-sysctl.service
        echo -e "${red}${bold}Disabled${normal}: kernel.sysrq=1 removed"
        ;;
      *)
        echo "${blue}No changes made.${normal}"
        ;;
    esac

# Regenerate GRUB config, useful in dual-boot scenarios where a second operating system isn't listed
[group("system")]
regenerate-grub:
    #!/usr/bin/bash
    source /usr/libexec/bazzite-boot-remount
    remount_boot_rw
    if [ -d /sys/firmware/efi ]; then
      sudo grub2-mkconfig -o /etc/grub2-efi.cfg
    else
      sudo grub2-mkconfig -o /etc/grub2.cfg
    fi
    remount_boot_ro

# Set GRUB menu timeout and regenerate config. Options: no-timeout | instant | 1-second | 3-seconds | 5-seconds | 10-seconds | custom
[group("system")]
grub-timeout ACTION="":
    #!/usr/bin/bash
    set -euo pipefail
    source /usr/libexec/bazzite-boot-remount
    source /usr/lib/ujust/ujust.sh

    GRUB_FILE="/etc/default/grub"
    GRUB_FILE_EXISTED="false"
    GRUB_FILE_BACKUP=""
    BOOT_REMOUNTED="false"

    print_help() {
      echo "Usage: ujust grub-timeout <option>"
      echo "  <option>: Specify the timeout to skip the interactive prompt"
      echo "  Use 'no-timeout' or '-1' to keep the GRUB menu open until the user makes a choice"
      echo "  Use 'instant' or '0' to skip the GRUB menu. Menu appears with Shift being held."
      echo "  Use '1-second', '3-seconds', '5-seconds', or '10-seconds' for common timeouts"
      echo "  Use 'custom' to enter a custom whole number from 0 to 60 seconds"
    }

    confirm_existing_grub_file() {
      local CONFIRM_CHOICE
      clear
      echo "${bold}Existing GRUB File${normal}"
      echo "$GRUB_FILE already exists."
      echo "Only GRUB_TIMEOUT will be changed temporarily."
      echo "The GRUB config will be regenerated, then the original file will be restored."
      echo "The existing file will not be deleted."
      echo ""
      CONFIRM_CHOICE=$(Choose "Continue" "Exit without changes")
      if [[ "$CONFIRM_CHOICE" != "Continue" ]]; then
        echo "No changes made."
        exit 0
      fi
    }

    cleanup() {
      local EXIT_CODE=$?
      if [[ "$GRUB_FILE_EXISTED" == "true" && -n "$GRUB_FILE_BACKUP" && -f "$GRUB_FILE_BACKUP" ]]; then
        echo "Restoring previous $GRUB_FILE..."
        sudo cp -a "$GRUB_FILE_BACKUP" "$GRUB_FILE" || true
        sudo rm -f "$GRUB_FILE_BACKUP"
      else
        echo "Removing temporary $GRUB_FILE..."
        sudo rm -f "$GRUB_FILE" || true
      fi

      if [[ "$BOOT_REMOUNTED" == "true" ]]; then
        remount_boot_ro || true
      fi

      exit "$EXIT_CODE"
    }

    validate_timeout() {
      local TIMEOUT="$1"
      if [[ "$TIMEOUT" =~ ^[0-9]+$ ]] && (( TIMEOUT <= 60 )); then
        return 0
      fi

      return 1
    }

    prompt_custom_timeout() {
      local CUSTOM_TIMEOUT
      while true; do
        read -r -p "Enter GRUB timeout in seconds (0-60): " CUSTOM_TIMEOUT || exit 1
        if validate_timeout "$CUSTOM_TIMEOUT" >/dev/null; then
          TIMEOUT="$CUSTOM_TIMEOUT"
          return 0
        fi

        echo "Please enter a whole number from 0 to 60 seconds." >&2
      done
    }

    set_timeout_from_option() {
      local OPTION_LOWER
      OPTION_LOWER="$(echo "$1" | tr '[:upper:]' '[:lower:]')"

      case "$OPTION_LOWER" in
        "no timeout (-1)"|no-timeout|never|-1)
          TIMEOUT="-1"
          ;;
        "skip menu (0 seconds - menu appears with shift being held)"|instant|0)
          TIMEOUT="0"
          ;;
        "1 second"|1-second|1-seconds|1)
          TIMEOUT="1"
          ;;
        "3 seconds"|3-seconds|3-second|3)
          TIMEOUT="3"
          ;;
        "5 seconds"|5-seconds|5-second|5)
          TIMEOUT="5"
          ;;
        "10 seconds"|10-seconds|10-second|10)
          TIMEOUT="10"
          ;;
        "custom timeout"|custom)
          prompt_custom_timeout
          ;;
        help)
          print_help
          exit 0
          ;;
        "exit without changes"|exit)
          exit 0
          ;;
        *)
          if [[ "$OPTION_LOWER" == "-1" ]]; then
            TIMEOUT="-1"
          elif validate_timeout "$OPTION_LOWER" >/dev/null; then
            TIMEOUT="$OPTION_LOWER"
          else
            echo "Invalid timeout option: $1" >&2
            print_help
            exit 1
          fi
          ;;
      esac
    }

    OPTION="{{ ACTION }}"
    if [[ -z "$OPTION" ]]; then
      echo "${bold}GRUB Timeout${normal}"
      echo "Choose how long GRUB should wait before booting the default entry."
      echo "This will regenerate the GRUB config."
      OPTION=$(Choose "No Timeout (-1)" "Skip Menu (0 seconds - Menu appears with Shift being held)" "1 Second" "3 Seconds" "5 Seconds" "10 Seconds" "Custom Timeout" "Exit without changes")
    fi

    TIMEOUT=""
    set_timeout_from_option "$OPTION"

    if [[ -e "$GRUB_FILE" ]]; then
      confirm_existing_grub_file
    fi

    trap cleanup EXIT

    if sudo test -e "$GRUB_FILE"; then
      GRUB_FILE_EXISTED="true"
      GRUB_FILE_BACKUP="$(mktemp)"
      sudo cp -a "$GRUB_FILE" "$GRUB_FILE_BACKUP"
    fi

    remount_boot_rw
    BOOT_REMOUNTED="true"

    echo "Writing temporary GRUB_TIMEOUT=$TIMEOUT to $GRUB_FILE..."
    if sudo test -e "$GRUB_FILE" && sudo grep -q '^GRUB_TIMEOUT=' "$GRUB_FILE"; then
      sudo sed -i "s/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=$TIMEOUT/" "$GRUB_FILE"
    else
      printf 'GRUB_TIMEOUT=%s\n' "$TIMEOUT" | sudo tee -a "$GRUB_FILE"
    fi

    echo "Regenerating GRUB config..."
    if [ -d /sys/firmware/efi ]; then
      sudo grub2-mkconfig -o /etc/grub2-efi.cfg
    else
      sudo grub2-mkconfig -o /etc/grub2.cfg
    fi

    case "$TIMEOUT" in
      -1)
        echo "GRUB timeout has been set to wait until the user makes a choice in the generated config."
        ;;
      0)
        echo "GRUB timeout has been set to skip the menu. Menu appears with Shift being held."
        ;;
      *)
        echo "GRUB timeout has been set to $TIMEOUT seconds in the generated config."
        ;;
    esac

# Configure grub bootmenu visibility. Pass action 'help' for more info. Options: hide | unhide | show. Pairing: hide = Hide After Successful Boot | unhide = Same except when Dual Booting | show = Always Show Grub
[group("system")]
configure-grub ACTION="":
    #!/usr/bin/bash
    source /usr/libexec/bazzite-boot-remount
    source /usr/lib/ujust/ujust.sh
    # Function to display usage/help with some color
    print_help() {
      echo -e "Usage: ujust configure-grub <option>"
      echo
      echo -e "Where <option> can be:"
      echo -e "  ${bold}${cyan}hide${normal} = GRUB is hidden after a successful boot, even for dual-boot setups."
      echo -e "  ${bold}${yellow}unhide${normal} = GRUB is hidden after a successful boot, but it will show if dual-booting."
      echo -e "  ${bold}${green}show${normal} = GRUB always shows on boot."
      echo
      echo "If <option> is omitted, you will be prompted to choose interactively."
    }
    # Function to get the current GRUB menu_auto_hide setting and explain it
    get_current_setting() {
      local CURRENT_SETTING
      if sudo grub2-editenv - list | grep -q '^menu_auto_hide='; then
        CURRENT_SETTING=$(sudo grub2-editenv - list | awk -F= '/menu_auto_hide/ {print $2}')
      else
        CURRENT_SETTING=""
      fi
      if [ -z "$CURRENT_SETTING" ]; then
        echo "Current GRUB menu_auto_hide setting: ${bold}${red}Not Set (default to 0)${normal}"
        echo "Explanation:"
        echo "  - ${bold}0${normal}: GRUB always shows on boot."
        return 0
      else
        case "$CURRENT_SETTING" in
          0)
            echo "Current GRUB menu_auto_hide setting: ${bold}${green}0 (Always Show)${normal}"
            echo "Explanation:"
            echo "  - ${bold}0${normal}: GRUB always shows on boot."
            ;;
          1)
            echo "Current GRUB menu_auto_hide setting: ${bold}${yellow}1 (Hide After Successful Boot, except when Dual Booting)${normal}"
            echo "Explanation:"
            echo "  - ${bold}1${normal}: GRUB is hidden after a successful boot, but it will show if dual-booting."
            ;;
          2)
            echo "Current GRUB menu_auto_hide setting: ${bold}${cyan}2 (Hide After Successful Boot)${normal}"
            echo "Explanation:"
            echo "  - ${bold}2${normal}: GRUB is hidden after a successful boot, even for dual-boot setups."
            ;;
          *)
            echo "Current GRUB menu_auto_hide setting: ${bold}${red}Unknown${normal}"
            echo "Explanation:"
            echo "  - This setting is unrecognized. Reset it to 0, 1, or 2."
            ;;
        esac
      fi
    }
    # Interactive menu for choosing the new behavior
    interactive_menu() {
      local options=(
        "Hide After Successful Boot (menu_auto_hide=2)"
        "Same except when Dual Booting (menu_auto_hide=1)"
        "Always Show Grub (unset menu_auto_hide)"
        "Exit without changes"
      )
      local choice
      choice=$(Choose "${options[@]}")
      echo "$choice"
    }
    # Function to apply the selected setting
    apply_setting() {
      local selected_option="$1"
      remount_boot_rw
      # Support the interactive strings as well as short commands
      case "$(echo "$selected_option" | tr '[:upper:]' '[:lower:]')" in
        *"(menu_auto_hide=2)"*|hide)
          sudo grub2-editenv - set menu_auto_hide=2
          echo "GRUB menu is now set to ${bold}${cyan}Hide After Successful Boot${normal}."
          ;;
        *"(menu_auto_hide=1)"*|unhide)
          sudo grub2-editenv - set menu_auto_hide=1
          echo "GRUB menu is now set to ${bold}${yellow}Hide After Successful Boot except when Dual Booting${normal}."
          ;;
        *"(unset menu_auto_hide)"*|show)
          sudo grub2-editenv - unset menu_auto_hide
          echo "GRUB menu is now set to ${bold}${green}Always Show${normal}."
          ;;
        *"exit without changes"*|exit)
          echo "${bold}No changes were made. Exiting...${normal}"
          ;;
        help)
          print_help
          ;;
        *)
          echo "${bold}${red}Invalid option selected. No changes were made.${normal}"
          ;;
      esac
      remount_boot_ro
    }
    OPTION="{{ ACTION }}"   # from “configure-grub ACTION=...”
    if [ "$OPTION" == "help" ]; then
      print_help
      exit 0
    fi
    get_current_setting
    echo
    # If no ACTION was passed, go interactive
    if [ -z "$OPTION" ]; then
      NEW_SETTING=$(interactive_menu)
      if [ -n "$NEW_SETTING" ]; then
        apply_setting "$NEW_SETTING"
      else
        echo "${bold}No changes were made.${normal}"
      fi
    else
      apply_setting "$OPTION"
    fi

# Toggle a ramoops config to save panic messages across crashes
[group("system")]
toggle-save-panics ACTION="":
    #!/usr/bin/bash
    source /usr/lib/ujust/ujust.sh

    if [[ -e /etc/modules-load.d/ramoops.conf ]]; then
        STATUS=Enabled
    else
        STATUS=Disabled
    fi

    OPTION="{{ ACTION }}"
    if [ "$OPTION" == "help" ]; then
      echo "Usage: ujust toggle-save-panics <option>"
      echo "  <option>: Specify the option to skip the interactive prompt"
      echo "  Use 'status' to print the current portal status"
      echo "  Use 'enable' to enable ramoops"
      echo "  Use 'disable' to disable ramoops"
      exit 0
    elif [ "$OPTION" == "status" ]; then
      if [ "$STATUS" == "Enabled" ]; then
        echo "enable"
      else
        echo "disable"
      fi
      exit 0
    elif [ "$OPTION" == "" ]; then
      echo Ramoops is a kernel module that will save panic information across a reboot and allow it to be
      echo recovered for debugging.  Panic messages will be written to /var/lib/systemd/pstore.
      echo
      if [ "$STATUS" == "Enabled" ]; then
        echo -e "${bold}ramoops configuration:${normal} ${green}$STATUS${normal}\n"
      else
        echo -e "${bold}ramoops configuration:${normal} ${yellow}$STATUS${normal}\n"
      fi

      OPTION=$(Choose "Enable ramoops" "Disable ramoops" "Exit without saving")
    fi

    case "$OPTION" in
      "Enable ramoops"|enable)
        echo "Enabling ramoops..."
        echo
        echo "kernel.panic = 5" | sudo tee /etc/sysctl.d/99-panic.conf > /dev/null
        echo "options ramoops mem_name=ramoops mem_size=0x10000 record_size=0x4000" | \
          sudo tee /etc/modprobe.d/ramoops.conf > /dev/null
        echo "ramoops" | sudo tee /etc/modules-load.d/ramoops.conf > /dev/null
        # bootc: grubby edits the kernel args in place
        for _ka in "reserve_mem=64K:4096:ramoops" "pstore.backend=ramoops"; do
          [[ "$(cat /proc/cmdline)" == *"$_ka"* ]] || sudo grubby --update-kernel=ALL --args="$_ka"
        done
        ;;
      "Disable ramoops"|disable)
        echo "Disabling ramoops..."
        echo
        sudo rm -f /etc/sysctl.d/99-panic.conf
        sudo rm -f /etc/modprobe.d/ramoops.conf
        sudo rm -f /etc/modules-load.d/ramoops.conf
        sudo grubby --update-kernel=ALL \
          --remove-args="reserve_mem pstore.backend"
        ;;
      "Exit without saving"|*)
        echo "No changes made."
        ;;
    esac

# Add user to "input" group required by certain controller drivers. Options: status | add | remove
[group("hardware")]
add-user-to-input-group ACTION="":
    #!/usr/bin/bash
    get_status_token() {
      if id -nG "$USER" | tr ' ' '\n' | grep -qx "input"; then
        echo "add"
      else
        echo "remove"
      fi
    }
    get_current_status() {
      if [[ "$(get_status_token)" == "add" ]]; then
        echo "Added"
      else
        echo "Not Added"
      fi
    }
    add_user_to_input_group() {
      if ! grep -q "input" /etc/group; then
        sudo bash -c 'grep "input" /lib/group >> /etc/group'
      fi
      sudo usermod -a -G input "$USER"
    }
    remove_user_from_input_group() {
      if grep -q "input" /etc/group; then
        sudo gpasswd -d "$USER" input 2>/dev/null || true
      fi
    }
    OPTION="{{ ACTION }}"
    if [[ "$OPTION" == "help" ]]; then
      echo "Usage: ujust add-user-to-input-group <option>"
      echo "  <option>: Specify the quick option to skip the prompt"
      echo "  Use 'status' to print the current portal token"
      echo "  Use 'add' to add the current user to the input group"
      echo "  Use 'remove' to remove the current user from the input group"
      exit 0
    elif [[ "$OPTION" == "status" ]]; then
      get_status_token
      exit $?
    elif [[ -z "$OPTION" ]]; then
      echo "Current status: $(get_current_status)"
      OPTION=$(Choose "Add" "Remove" "Exit without changes")
      case "$OPTION" in
        "Add")
          add_user_to_input_group
          ;;
        "Remove")
          remove_user_from_input_group
          ;;
        *)
          echo "No changes made."
          ;;
      esac
      exit 0
    elif [[ "$OPTION" == "remove" ]]; then
      remove_user_from_input_group
      exit 0
    fi
    add_user_to_input_group

# Configure watchdog (default: enabled, recovers the system in the event of a malfunction)
[group("system")]
configure-watchdog ACTION="":
    #!/usr/bin/bash
    source /usr/lib/ujust/ujust.sh
    OPTION={{ ACTION }}
    get_status_token() {
      if [[ "$(cat /proc/cmdline)" =~ (nowatchdog|modprobe\.blacklist=(iTCO_wdt|sp5100_tco)) ]]; then
        echo "disable"
      else
        echo "enable"
      fi
    }
    get_current_status() {
      WATCHDOG_STATE="$(cat /proc/cmdline)"
      if [[ "$WATCHDOG_STATE" =~ (nowatchdog|modprobe\.blacklist=(iTCO_wdt|sp5100_tco)) ]]; then
        echo "${yellow}${bold}Disabled${normal}"
      else
        echo "${green}${bold}Enabled${normal}"
      fi
    }
    if [ "$OPTION" == "help" ]; then
      echo "Usage: ujust configure-watchdog <option>"
      echo "  <option>: Specify the quick option to skip the prompt"
      echo "  Use 'enable' to select Enable Watchdog"
      echo "  Use 'disable' to select Disable Watchdog"
      exit 0
    elif [ "$OPTION" == "status" ]; then
      get_status_token
      exit 0
    elif [ "$OPTION" == "" ]; then
      echo "${bold}Watchdog configuration${normal}"
      echo "Having the watchdog enabled will let it recover the system in the event of a malfunction, however"
      echo "disabling the watchdog can give a potential performance improvement due to fewer interrupts"
      echo "Watchdog is $(get_current_status)"
      OPTION=$(Choose "Enable Watchdog" "Disable Watchdog")
    fi
    if [[ "${OPTION,,}" =~ ^enable ]]; then
      CPU_MODEL=$(lscpu --json | jq -r '."lscpu"[7]."data"')
      WATCHDOG_KARGS="--delete-if-present=nowatchdog"
      if [[ "$CPU_MODEL" =~ "Intel" ]]; then
        WATCHDOG_KARGS="$WATCHDOG_KARGS --delete-if-present=modprobe.blacklist=iTCO_wdt"
      elif [[ "$CPU_MODEL" =~ "AMD" ]]; then
        WATCHDOG_KARGS="$WATCHDOG_KARGS --delete-if-present=modprobe.blacklist=sp5100_tco"
      fi
      # bootc: translate the legacy kargs flags to grubby
      for _ka in $WATCHDOG_KARGS; do
        case "$_ka" in
          --append-if-missing=*) sudo grubby --update-kernel=ALL --args="${_ka#--append-if-missing=}" ;;
          --delete-if-present=*)
            _key="${_ka#--delete-if-present=}"; _key="${_key%%=*}"
            sudo grubby --update-kernel=ALL --remove-args="$_key" ;;
        esac
      done
    elif [[ "${OPTION,,}" =~ ^disable ]]; then
      CPU_MODEL=$(lscpu --json | jq -r '."lscpu"[7]."data"')
      WATCHDOG_KARGS="--append-if-missing=nowatchdog"
      if [[ "$CPU_MODEL" =~ "Intel" ]]; then
        WATCHDOG_KARGS="$WATCHDOG_KARGS --append-if-missing=modprobe.blacklist=iTCO_wdt"
      elif [[ "$CPU_MODEL" =~ "AMD" ]]; then
        WATCHDOG_KARGS="$WATCHDOG_KARGS --append-if-missing=modprobe.blacklist=sp5100_tco"
      fi
      # bootc: translate the legacy kargs flags to grubby
      for _ka in $WATCHDOG_KARGS; do
        case "$_ka" in
          --append-if-missing=*) sudo grubby --update-kernel=ALL --args="${_ka#--append-if-missing=}" ;;
          --delete-if-present=*)
            _key="${_ka#--delete-if-present=}"; _key="${_key%%=*}"
            sudo grubby --update-kernel=ALL --remove-args="$_key" ;;
        esac
      done
    fi

# Run a one minute system benchmark
[group("utilities")]
benchmark:
    echo 'Running a 1 minute benchmark ...'
    cd /tmp && stress-ng --matrix 0 -t 1m --times

alias toggle-password-feedback := password-feedback

# Manage password prompt feedback in terminal, where sudo password prompts will display asterisks when enabled. Options: on | off
[group("development")]
password-feedback ACTION="":
    #!/usr/bin/bash
    source /usr/lib/ujust/ujust.sh
    PWFEEDBACK_FILE="/etc/sudoers.d/enable-pwfeedback"
    OPTION={{ ACTION }}
    if [ "$OPTION" = "help" ]; then
      echo "Usage: ujust password-feedback <option>"
      echo "  <option>: Specify the quick option to skip the toggle behavior"
      echo "  Use 'on' to show password asterisks in sudo prompts"
      echo "  Use 'off' to hide password asterisks in sudo prompts"
      exit 0
    elif [ -z "$OPTION" ]; then
      OPTION=$(Choose "Show password asterisks" "Hide password asterisks" "Exit without changes")
      case "$OPTION" in
        "Show password asterisks")
          OPTION="on"
          ;;
        "Hide password asterisks")
          OPTION="off"
          ;;
        *)
          echo "No changes made."
          exit 0
          ;;
      esac
    fi
    if [ "$OPTION" = "on" ]; then
      echo 'Defaults pwfeedback' | sudo tee $PWFEEDBACK_FILE
      echo "enabled, restart terminal to see changes"
    elif [ "$OPTION" = "off" ]; then
      sudo rm -f $PWFEEDBACK_FILE
      echo "disabled pwfeedback. restart your terminal to see changes"
    elif sudo test -f $PWFEEDBACK_FILE; then
      sudo rm -f $PWFEEDBACK_FILE
      echo "disabled pwfeedback. restart your terminal to see changes"
    else
      echo 'Defaults pwfeedback' | sudo tee $PWFEEDBACK_FILE
      echo "enabled, restart terminal to see changes"
    fi

# Manage global Proton DLSS upgrade; updates DLSS DLLs for Proton. Options: enable | disable
[group("gaming")]
global-dlss ACTION="":
    #!/usr/bin/bash
    set -euo pipefail
    source /usr/lib/ujust/ujust.sh
    FILE="$HOME/.config/environment.d/99-proton-dlss.conf"
    CURRENT="Disabled"
    if [[ -f "$FILE" ]]; then
        CURRENT="Enabled"
    fi
    OPTION="{{ ACTION }}"
    if [[ -z "$OPTION" ]]; then
        echo -e "${bold}Global DLSS Upgrade:${normal} $CURRENT"
        echo ""
        echo "Enables Proton to use the latest NVIDIA DLSS runtime/DLLs."
        echo "Automatically fetches and replaces DLSS DLLs."
        echo "Only compatible with Proton GE, Proton EM, or similar forks."
        echo ""
        OPTION="$(Choose "Enable" "Disable" "Exit without saving")"
    fi
    case "$OPTION" in
        Enable|enable)
            mkdir -p "$HOME/.config/environment.d"
            echo "PROTON_DLSS_UPGRADE=1" > "$FILE"
            echo -e "${green}${bold}Enabled${normal}: PROTON_DLSS_UPGRADE=1"
            echo "You may need to restart Steam for changes to take effect."
            ;;
        Disable|disable)
            rm -f "$FILE"
            echo -e "${red}${bold}Disabled${normal}: PROTON_DLSS_UPGRADE removed"
            ;;
        *)
            echo "No changes made."
            ;;
    esac

# get logs for this boot and last boot, cleanly output in terminal as pastebin links, to simplify troubleshooting and issue reporting.
[group("utilities")]
get-logs:
    #!/bin/bash
    set -euo pipefail
    source /usr/lib/ujust/ujust.sh
    echo -e "${red}${bold}Generating and uploading system information and logs for halcyon debugging...${normal}"
    echo " "
    # Upload system status information
    system_information=$({
      echo "bootc status"
      echo "------------"
      bootc status
      echo
      echo "fastfetch"
      echo "---------"
      \fastfetch --config none --logo none --pipe --structure-disabled colors
    } | fpaste 2>/dev/null)
    echo -e "${bold}System Information:${normal} $system_information"
    echo " "
    # Get logs for this boot
    this_boot_logs=$(journalctl -b | fpaste 2>/dev/null)
    echo -e "${bold}Logs This Boot:${normal} $this_boot_logs"
    echo " "
    # Get logs for last boot
    last_boot_logs=$(journalctl -b -1 | fpaste 2>/dev/null)
    echo -e "${bold}Logs Last Boot:${normal} $last_boot_logs"
    echo " "
    # Concatenate all outputs and copy to clipboard
    {
      echo "System Information: $system_information"
      echo "Logs This Boot: $this_boot_logs"
      echo
      echo "Logs Last Boot: $last_boot_logs"
    } | wl-copy
    echo -e "${lightgreen}${bold}Logs and system information have been uploaded, and the links have been copied to your clipboard.\nPlease provide them to Bazzite Support for further help.${normal}"
