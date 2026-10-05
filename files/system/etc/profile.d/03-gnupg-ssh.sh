# halcyon: SSH agent wiring for Hyprland sessions. gnome-keyring's ssh
# component (started by its xdg-autostart entries when the session runs
# through uwsm) exposes the agent at $XDG_RUNTIME_DIR/keyring/ssh; point
# terminals at it whenever it exists so ssh-add/ssh see the same agent the
# GUI world uses. Falls back to the environment's existing value otherwise.
if [ -z "${SSH_AUTH_SOCK:-}" ] && [ -S "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/keyring/ssh" ]; then
    export SSH_AUTH_SOCK="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/keyring/ssh"
fi
