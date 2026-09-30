# shellcheck shell=sh
# halcyon image-path.sh — add helper scripts to PATH for all POSIX login/interactive shells.
#
# Only the halcyon helper scripts directory is added here (the Homebrew
# PATH wiring was retired with the brew stage, 2026-09-29).
case ":${PATH}:" in
  *:/usr/libexec/halcyon-image:*) ;;
  *) export PATH="${PATH}:/usr/libexec/halcyon-image" ;;
esac
