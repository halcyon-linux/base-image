# shellcheck shell=sh
# Nix does not like home being a symlink, use the real path instead.
# Guarded on purpose: never clobber HOME when resolution fails. An unguarded
# `HOME=$(readlink -f "$HOME")` yielded HOME="" the moment readlink was not
# runnable (broken PATH), which poisoned the whole session (prompt ~/…, and
# XDG_* deriving to /.local, /.config). cd -P / pwd -P are builtins, so this
# works even with no usable PATH.
_home_login="${HOME}"
if _real=$(cd -P -- "${HOME:-/}" 2>/dev/null && pwd -P 2>/dev/null) && [ -n "${_real}" ]; then
    HOME="${_real}"
fi
unset _real
export HOME

# Normalize the login PWD to the resolved path too: login(1) may hand the
# shell the logical /home/<user> (straight from passwd) while the prompt
# renders PWD — resolve it so the shell shows /var/home/<user> like bazzite.
# Strictly conditional: only when the shell still sits at the login
# directory, never a cd'ed path.
if [ "${PWD}" = "${_home_login}" ]; then
    PWD="${HOME}"
    export PWD
fi
unset _home_login
