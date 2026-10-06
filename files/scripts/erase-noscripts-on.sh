#!/usr/bin/env bash
# halcyon build step — stage the removals-transaction drop-in.
#
# _why_: two transaction-scoped settings for the removals stage in one file:
#
# 1. tsflags=noscripts — rpm records EVERY scriptlet failure — including
#    "non-critical" %postun — in the transaction-global scriptError flag and
#    then fails the whole transaction (rpm 6.0+, dnf5 #2507), and erase
#    scriptlets shell out to `systemctl`, which cannot work in a build chroot
#    (akonadi-server's %postun aborted a completed 413-package erase).
#    File-trigger cache maintenance (ldconfig, glib schemas) is unaffected.
#
# 2. excludepkgs — bazzite's gaming/media library stack must REMAIN (user
#    decision), but the auto-remove closure of the KDE sweep orphans and
#    erases it (mesa/libglvnd/gstreamer/pipewire/ffmpeg-libav/libva/codecs
#    all fell in the broken runs — dnf5's remove-time cleanup ignores
#    install reasons). Excluded packages are invisible to the solver, so
#    auto-remove cannot select them. `steam*` is deliberately NOT protected:
#    guarded-removals explicitly removes steamdeck-* candidates and an
#    excluded name would make that transaction fail with "No match"; steam
#    itself is top-level and never orphaned.
#
# erase-noscripts-off.sh removes this drop-in before the first install
# stage; verify-removals.sh and final-verify.sh gate on its absence and on
# the media-stack canaries.
set -euo pipefail

CONF=/etc/dnf/libdnf5.conf.d/99-halcyon-erase-noscripts.conf
cat > "$CONF" <<'EOF'
[main]
# staged by erase-noscripts-on.sh for the removals stage; erased again by
# erase-noscripts-off.sh — must never be active during install stages
tsflags=noscripts
# ffmpeg/libav use lookalike-proof globs: `ffmpeg*` also matches ffmpegthumbs
# (explicitly removed — dnf5 refuses to remove an excluded name) and `libav*`
# matches libavc1394 (firewire).
excludepkgs=mesa-*,libglvnd*,gstreamer1*,pipewire*,wireplumber*,ffmpeg,ffmpeg-*,libavcodec*,libavdevice*,libavfilter*,libavformat*,libavutil*,libswresample*,libswscale*,libva*,libvdpau*,x264*,x265*,dav1d*,svt-*,aom-libs*,intel-mediasdk*,intel-media*,onevpl*,vulkan-*,openh264*,gamescope*,mangohud*,lutris*,scx-*,umu-*
EOF

if ! grep -q '^tsflags=noscripts$' "$CONF" || ! grep -q '^excludepkgs=.*mesa' "$CONF"; then
  echo "FAIL: drop-in content incomplete at $CONF" >&2
  exit 1
fi
echo "OK: removals drop-in staged at $CONF (noscripts + media-stack protection)"
