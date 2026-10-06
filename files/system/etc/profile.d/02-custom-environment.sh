#!/usr/bin/env bash

# XDG Base Directory Specification
export XDG_BIN_HOME="${HOME}/.local/bin"
export XDG_CACHE_HOME="${HOME}/.cache"
export XDG_CONFIG_HOME="${HOME}/.config"
export XDG_DATA_HOME="${HOME}/.local/share"
export XDG_STATE_HOME="${HOME}/.local/state"

# Backup Directory
export BACKUP_DIR="${HOME}/backup"

# Default Applications
export TERMINAL="kitty"
export BROWSER="brave-browser" # Brave RPM ships /usr/bin/brave-browser, not brave
export EDITOR="nvim"
export VISUAL="emacsclient -c -a emacs"
# bat is an RPM (modules/devtools.yml); fall back to less if it is ever absent
if command -v bat >/dev/null 2>&1; then
  export PAGER="bat --paging=always --style=plain"
else
  export PAGER="less"
fi

# Prepend "$1" to $PATH when not already in.
# This function API is accessible to scripts in /etc/profile.d
pathprepend() {
  case ":$PATH:" in
  *:"$1":*) ;;
  *)
    PATH="$1${PATH:+:$PATH}"
    ;;
  esac
}

# Prepend custom directories to PATH (in reverse order of priority)
# Last prepended = highest priority
pathprepend "${HOME}/.npm-global/bin"
pathprepend "${HOME}/.config/emacs/bin"
pathprepend "${HOME}/.local/bin"
pathprepend "${HOME}/.cache/.bun/bin"
pathprepend "${HOME}/.bun/bin"
pathprepend "${HOME}/go/bin"
pathprepend "${HOME}/.cargo/bin"
pathprepend "${HOME}/bin"

# Nix & Home-Manager User Profiles
pathprepend "/nix/var/nix/profiles/default/bin"
pathprepend "${HOME}/.nix-profile/bin"

# System dirs are guaranteed by 00-path-guard.sh (sorted first), which runs
# before this file and keeps user-space dirs in front of the system dirs.

# Export PATH
export PATH
