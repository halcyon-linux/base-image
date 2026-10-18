#!/bin/sh
# System-wide environment variables for /etc/profile.d/
# This script is sourced by /etc/profile and must be POSIX-compliant

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
export BROWSER="brave"
export EDITOR="nvim"
export VISUAL="emacsclient -c -a emacs"
export PAGER="bat --paging=always --style=plain"

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

# Export PATH
export PATH
