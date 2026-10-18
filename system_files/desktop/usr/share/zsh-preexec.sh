# zsh-preexec.sh -- zsh support for bash-preexec-style 'preexec' and 'precmd'
# hook functions.
#
# zsh calls every function listed in the 'preexec_functions' array before each
# interactive command (with the command text as $1) and every function listed in
# the 'precmd_functions' array before each prompt is issued. This file provides
# the same interface that https://github.com/ublue-os/bash-preexec exposes for
# bash, so configs written against bash-preexec keep working when this file is
# sourced in zsh instead.
#
# Usage: source this file late in your .zshrc, then append hook functions:
#   source /usr/share/zsh-preexec.sh
#   preexec_functions+=(my_preexec_function)
#   precmd_functions+=(my_precmd_function)
#
# A function literally named 'preexec' or 'precmd' is also invoked natively by
# zsh when defined, so both bash-preexec definition styles work.

# Only meaningful in zsh; mirrors bash-preexec's bash-only guard. 'return'
# keeps a sourced file from clobbering the caller's status outside a function.
if [[ -z "${ZSH_VERSION:-}" ]]; then
    return 1
fi

# Avoid duplicate inclusion (bash-preexec guards with bash_preexec_imported).
if [[ -n "${zsh_preexec_imported:-}" || -n "${__zp_imported:-}" ]]; then
    return 0
fi
zsh_preexec_imported="defined"
__zp_imported="${zsh_preexec_imported}"

# zsh invokes these arrays natively; declare them so appends work even when
# they were never touched before.
typeset -ga preexec_functions
typeset -ga precmd_functions

# bash-preexec exposes BP_PIPESTATUS alongside $? for hook functions. zsh keeps
# the real $? and $pipestatus, so a refresher placed first in precmd_functions
# updates the compatibility copy before user functions run, and returns the
# original status so later functions still see it in $?.
__bp_last_ret_value="$?"
BP_PIPESTATUS=($pipestatus)

__zp_precmd_refresh() {
    __bp_last_ret_value="$?"
    BP_PIPESTATUS=($pipestatus)
    return "$__bp_last_ret_value"
}

precmd_functions=(__zp_precmd_refresh $precmd_functions)

# bash-preexec installs a DEBUG trap and rewrites PROMPT_COMMAND. That plumbing
# is unnecessary in zsh, where the hook arrays are the native mechanism; these
# no-ops exist only so scripts that call the bash-preexec API directly do not
# fail with "command not found".
__bp_install() { return 0 }
__bp_install_after_session_init() { return 0 }
