# shellcheck shell=sh
# Show the MOTD banner in bash and zsh login shells.
if [ -z "$USERMOTDSOURCED" ]; then
  USERMOTDSOURCED="Y"
  case $- in
  *i*) ;;
  *) return 0 ;;
  esac
  if test -t 1 && test -d "$HOME"; then
    if test -x "/usr/bin/ublue-motd"; then
      /usr/bin/ublue-motd
    elif test -s "/etc/user-motd"; then
      cat /etc/user-motd
    fi
  fi
fi
