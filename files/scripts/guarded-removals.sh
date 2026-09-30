#!/usr/bin/env bash
# halcyon build step — guarded removals + hard verification.
# removals.yml's `dnf remove` block handles the known-installed list; this
# script sweeps the compose-variance leftovers that may or may not be
# present, guarded by reverse-dependency checks so a keeper never cascades.
set -uo pipefail

echo "::group::guarded-removals — candidate detection"

# compose-variance / expected-absent candidates: remove only what is installed
CANDIDATES=(
    gnome-classic-session gnome-classic-session-xsession gnome-terminal gnome-console
    gnome-text-editor evince loupe snapshot totem gnome-calculator gnome-calendar
    gnome-characters gnome-clocks gnome-connections gnome-contacts gnome-font-viewer
    gnome-logs gnome-maps gnome-remote-desktop gnome-system-monitor gnome-tour
    gnome-weather gnome-initial-setup gnome-extensions-app gnome-software baobab
    simple-scan yelp malcontent-control gnome-bluetooth jupiter-sd-mounting-btrfs
    ds-inhibit plasma-login-manager hhd hhd-ui decky-loader bluebubbles
    gnome-shell-extension-apps-menu gnome-shell-extension-background-logo
    gnome-shell-extension-launch-new-instance gnome-shell-extension-places-menu
    gnome-shell-extension-window-list gnome-shell-extension-workspace-indicator
    mozilla-filesystem
)

present=()
absent=()
for p in "${CANDIDATES[@]}"; do
    if rpm -q "$p" >/dev/null 2>&1; then
        ver=$(rpm -q --qf '%{VERSION}-%{RELEASE}' "$p" 2>/dev/null || echo "?")
        present+=("$p")
        echo "  FOUND  ${p}-${ver}"
    else
        absent+=("$p")
    fi
done

echo ""
echo "  INFO  ${#present[@]} of ${#CANDIDATES[@]} candidates present (${#absent[@]} already absent)"
echo "::endgroup::"

# --- Reverse-dep gates: sddm / cage ---
echo "::group::guarded-removals — reverse-dep gates (sddm, cage)"
for p in sddm cage; do
    if rpm -q "$p" >/dev/null 2>&1; then
        reqs="$(dnf5 -q repoquery --installed --whatrequires "$p" 2>/dev/null | grep -Ev "^${p}(-[0-9])?" || true)"
        if [ -n "${reqs}" ]; then
            echo "  GATE  keeping ${p} — required by:"
            echo "${reqs}" | while IFS= read -r req; do echo "          ${req}"; done
        else
            echo "  GATE  removing ${p} — nothing installed requires it"
            present+=("$p")
        fi
    else
        echo "  SKIP  ${p} not installed"
    fi
done
echo "::endgroup::"

# --- DNF removal ---
echo "::group::guarded-removals — dnf5 remove"
if [ "${#present[@]}" -gt 0 ]; then
    echo "  INFO  Removing ${#present[@]} package(s): ${present[*]}"
    if dnf5 -y remove "${present[@]}"; then
        echo "  OK    dnf5 remove succeeded"
    else
        echo "  WARN  dnf5 remove exited non-zero — hard verification below will catch survivors" >&2
    fi
else
    echo "  SKIP  nothing to remove"
fi
echo "::endgroup::"

# --- Hard-fail verification ---
echo "::group::guarded-removals — hard-fail verification (must-be-gone)"
echo "--- Packages that must NOT survive ---"
rc=0
# NOTE: fastfetch is deliberately absent here — removals.yml removes the
# Bazzite-bling'd one and core.yml reinstalls vanilla fastfetch afterwards.
for p in gnome-shell gdm mutter waydroid firefox inputplumber \
    steamos-manager-powerstation steamdeck-gnome-presets jupiter-fan-control; do
    if rpm -q "$p" >/dev/null 2>&1; then
        ver=$(rpm -q --qf '%{VERSION}-%{RELEASE}' "$p" 2>/dev/null || echo "?")
        echo "  FAIL  ${p}-${ver} still installed after removals" >&2
        rc=1
    else
        echo "  PASS  ${p} — absent (correct)"
    fi
done
echo "::endgroup::"

# NOTE: no keeper check here — this module runs BEFORE anything installs
# steam/bazaar/etc., so an "installed and present" gate can only fail. The
# keeper set is gated at end state by final-verify.sh instead.

exit "${rc}"
