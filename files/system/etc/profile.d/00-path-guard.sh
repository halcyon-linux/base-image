# shellcheck shell=sh
# Fail-safe: guarantee the system bin dirs are on PATH before any other
# profile.d script runs an external command. Uses only shell builtins, so it
# cannot itself be defeated by a broken PATH. Everything downstream (nix HOME
# resolution, XDG derivation, nix/texlive PATH hooks) depends on this.
case ":${PATH}:" in
  *:/usr/bin:*) ;;
  *) PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin${PATH:+:${PATH}}" ;;
esac
export PATH
