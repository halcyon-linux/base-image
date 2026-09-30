#!/usr/bin/env bash
# halcyon verify — apps: the curated application set landed through the
# vscode/brave/halcyon-applications repo window. Mutates nothing.
set -uo pipefail

echo "████ verify · apps ████"

fail=0
gate() {
  local desc="$1"
  shift
  if "$@" >/dev/null 2>&1; then echo "  PASS  $desc"; else
    echo "  FAIL  $desc"
    fail=1
  fi
}

echo "::group::verify-apps"
gate "editor + IDE set" rpm -q code emacs-pgtk neovim obsidian zed antigravity-ide
gate "browsers" rpm -q brave-browser brave-origin zen-browser ferdium
gate "utilities" rpm -q kitty distroshelf bitwarden ticktick zotero onlyoffice-desktopeditors tree-sitter-cli
gate "VPN stack" rpm -q mullvad-vpn private-internet-access proton-vpn-gtk-app proton-vpn-daemon
gate "vscode binary" test -x /usr/bin/code
gate "brave binary" test -x /usr/bin/brave-browser
gate "vendor repos cleaned" sh -c '! ls /etc/yum.repos.d/ | grep -Eqi "vscode|brave|halcyon-applications"'
echo "::endgroup::"

[ "$fail" = 0 ] || {
  echo "::error::apps-verify failed"
  exit 1
}
echo "--- verify-apps: all checks passed ---"
