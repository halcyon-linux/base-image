#!/usr/bin/env bash
# halcyon build step — guarded removals + hard verification.
# removals.yml's `dnf remove` block handles the known-installed list (verified
# against the bazzite base inventory); this script sweeps the
# compose-variance leftovers that may or may not be present, guarded by
# reverse-dependency checks so a keeper never cascades. Two passes: blind
# candidate removal first, then reverse-dep-gated cores (IM frameworks and
# session containers) whose libraries other packages may still hold.
set -uo pipefail

echo "::group::guarded-removals — candidate detection"

# compose-variance / expected-absent candidates: remove only what is installed
CANDIDATES=(
    # fedora-bootc-era GNOME stack (absent on the bazzite base, tolerated)
    gnome-classic-session gnome-classic-session-xsession gnome-terminal gnome-console
    gnome-text-editor evince loupe snapshot totem gnome-calculator gnome-calendar
    gnome-characters gnome-clocks gnome-connections gnome-contacts gnome-font-viewer
    gnome-logs gnome-maps gnome-remote-desktop gnome-system-monitor gnome-tour
    gnome-weather gnome-initial-setup gnome-extensions-app gnome-software baobab
    simple-scan yelp malcontent-control gnome-bluetooth gnome-shell gdm mutter
    gnome-session gnome-session-wayland-session gnome-control-center
    gnome-settings-daemon gjs xdg-desktop-portal-gnome ptyxis firefox firefox-langpacks
    # steamdeck / handheld variance
    jupiter-sd-mounting-btrfs jupiter-hw-support-btrfs galileo-mura steamdeck-dsp
    powerbuttond vpower sdgyrodsu steamdeck-backgrounds steamdeck-gnome-presets
    inputplumber steamos-manager-powerstation jupiter-fan-control
    ds-inhibit hhd hhd-ui decky-loader bluebubbles
    waydroid waydroid-nvidia waydroid-nvidia-selinux
    plasma-login-manager
    # input-method application packages (their CORE libraries go through the
    # reverse-dep gate below — gtk/qt may hold ibus-libs/fcitx5-libs)
    ibus ibus-anthy ibus-anthy-python ibus-chewing ibus-gtk3 ibus-gtk4
    ibus-hangul ibus-libpinyin ibus-m17n ibus-panel ibus-setup ibus-typing-booster
    fcitx5 fcitx5-chewing fcitx5-chinese-addons fcitx5-chinese-addons-data
    fcitx5-configtool fcitx5-data fcitx5-gtk fcitx5-gtk3 fcitx5-gtk4 fcitx5-hangul
    fcitx5-libthai fcitx5-lua fcitx5-m17n fcitx5-mozc fcitx5-qt
    fcitx5-qt-libfcitx5qt6widgets fcitx5-qt-libfcitx5qtdbus fcitx5-qt-qt6gui
    fcitx5-qt5 fcitx5-qt6 fcitx5-sayura fcitx5-table-extra fcitx5-unikey
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

# --- DNF removal (pass 1: blind candidates) ---
echo "::group::guarded-removals — dnf5 remove (pass 1)"
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

# --- Reverse-dep gates (pass 2): packages whose libraries other installed
# packages may still hold. Only removed when nothing installed requires them.
echo "::group::guarded-removals — reverse-dep gates"
gated_present=()
for p in sddm cage ibus ibus-libs fcitx5 fcitx5-libs; do
    if rpm -q "$p" >/dev/null 2>&1; then
        reqs="$(dnf5 -q repoquery --installed --whatrequires "$p" 2>/dev/null | grep -Ev "^${p}(-[0-9])?" || true)"
        if [ -n "${reqs}" ]; then
            echo "  GATE  keeping ${p} — required by:"
            echo "${reqs}" | while IFS= read -r req; do echo "          ${req}"; done
        else
            echo "  GATE  removing ${p} — nothing installed requires it"
            gated_present+=("$p")
        fi
    else
        echo "  SKIP  ${p} not installed"
    fi
done
echo "::endgroup::"

if [ "${#gated_present[@]}" -gt 0 ]; then
    echo "::group::guarded-removals — dnf5 remove (pass 2: gated)"
    echo "  INFO  Removing gated package(s): ${gated_present[*]}"
    dnf5 -y remove "${gated_present[@]}" ||
        echo "  WARN  dnf5 remove exited non-zero — hard verification below will catch survivors" >&2
    echo "::endgroup::"
fi

# --- Hard-fail verification ---
echo "::group::guarded-removals — hard-fail verification (must-be-gone)"
echo "--- Packages that must NOT survive ---"
rc=0
# NOTE: fastfetch is deliberately absent here — removals.yml removes the
# Bazzite-bling'd one and core.yml reinstalls vanilla fastfetch afterwards.
MUST_BE_GONE=(
    gnome-shell gdm mutter waydroid firefox inputplumber
    steamos-manager-powerstation steamdeck-gnome-presets jupiter-fan-control
    plasma-login-manager
    # KDE desktop closure
    kwin konsole dolphin plasma-workspace ksshaskpass kwalletmanager5
    # explicitly-removed set (tesseract-libs/-common/-langpack-eng/
    # -tessdata-doc exempt: the protected ffmpeg hard-requires libtesseract)
    signon vlc-libs xdg-desktop-portal-kde rom-properties
    ryzenadj zenergy
    # halcyon desktop replacements / retirements
    greetd noctalia-greeter-git Thunar thunar-archive-plugin
)
for p in "${MUST_BE_GONE[@]}"; do
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
