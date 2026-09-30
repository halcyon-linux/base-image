#!/usr/bin/env bash
# halcyon Step C — guarded removals + hard verification (prompt §5.1)
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
        reqs="$(dnf -q repoquery --installed --whatrequires "$p" 2>/dev/null | grep -Ev "^${p}(-[0-9])?" || true)"
        if [ -n "${reqs}" ]; then
            echo "  GATE  keeping ${p} — required by:"
            echo "${reqs}" | sed 's/^/          /'
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
echo "::group::guarded-removals — dnf remove"
if [ "${#present[@]}" -gt 0 ]; then
    echo "  INFO  Removing ${#present[@]} package(s): ${present[*]}"
    if dnf -y remove "${present[@]}"; then
        echo "  OK    dnf remove succeeded"
    else
        echo "  WARN  dnf remove exited non-zero — hard verification below will catch survivors" >&2
    fi
else
    echo "  SKIP  nothing to remove"
fi
echo "::endgroup::"

# --- Hard-fail verification (constraint 14) ---
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

echo "::group::guarded-removals — hard-fail verification (keepers)"
echo "--- Packages that must survive ---"
for p in bazaar bazzite-portal steam terra-gamescope umu-launcher lutris \
    scx-scheds scx-tools usbip xwiimote-ng input-remapper; do
    if rpm -q "$p" >/dev/null 2>&1; then
        ver=$(rpm -q --qf '%{VERSION}-%{RELEASE}' "$p" 2>/dev/null || echo "?")
        echo "  PASS  ${p}-${ver} present (keeper)"
    else
        echo "  FAIL  keeper ${p} missing after removals — cascade regression?" >&2
        rc=1
    fi
done
echo "::endgroup::"

# --- Soft checks (known stable-channel base variance, NOTES.md §5) ---
echo "::group::guarded-removals — soft checks (base-image variance)"
echo "--- Packages expected absent on stable channel (non-fatal) ---"
for p in steamos-manager gamescope-session-ogui-steam gamemode; do
    if rpm -q "$p" >/dev/null 2>&1; then
        ver=$(rpm -q --qf '%{VERSION}-%{RELEASE}' "$p" 2>/dev/null || echo "?")
        echo "  PRESENT  ${p}-${ver} (unexpected but non-fatal — check NOTES.md §5)"
    else
        echo "  OK    ${p} absent (expected stable-channel variance)"
    fi
done

if [ -f /usr/bin/distroshelf-helper ]; then
    echo "  OK    /usr/bin/distroshelf-helper present (kept)"
else
    echo "  WARN  /usr/bin/distroshelf-helper absent — stable-channel base variance (NOTES.md §5)"
fi
echo "::endgroup::"

exit "${rc}"
