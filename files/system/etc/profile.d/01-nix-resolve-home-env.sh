# shellcheck shell=sh
# Nix does not like home being a symlink, use the real path instead.
# Guarded on purpose: never clobber HOME when resolution fails. An unguarded
# `HOME=$(readlink -f "$HOME")` yielded HOME="" the moment readlink was not
# runnable (broken PATH), which poisoned the whole session (prompt ~/…, and
# XDG_* deriving to /.local, /.config). cd -P / pwd -P are builtins, so this
# works even with no usable PATH.
if _real=$(cd -P -- "${HOME:-/}" 2>/dev/null && pwd -P 2>/dev/null) && [ -n "${_real}" ]; then
    HOME="${_real}"
fi
unset _real
export HOME
