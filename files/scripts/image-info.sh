#!/usr/bin/env bash
# halcyon build step — image-info (os-release identity + plymouth theme
# assets + sigstore policy). PRETTY_NAME reflects the actual base
# (a sanctioned divergence from main's "halcyon (Bazzite fork)");
# HOME_URL matches main.
#
# build-plymouth-assets and branding-verify were absorbed into this script in
# the 2026-09-29 one-file-per-stage consolidation (same RUN, same order:
# os-release → plymouth assets → image-info.json/sigstore → branding gates).
set -euo pipefail

echo "████ STAGE 09/13 · finish · image-info + build-initramfs + finalize ████"

# Build the real Plymouth theme assets from the baked astronaut wallpaper.
# The two-step plugin degrades to solid colors when files are missing, which
# is why the theme used to render blank; this generates everything it loads:
#   background.png          — wallpaper, cropped 1920x1080, darkened + blurred
#   throbber-0001..0030.png — 30 rotating-arc spinner frames (128px, alpha)
#   entry.png etc.          — password-entry widgets copied from the stock
#                             spinner theme (plymouth-theme-spinner is a core.yml
#                             install); without them the password box is invisible
# Then selects the theme via /etc/plymouth/plymouthd.conf (written directly —
# `plymouth-set-default-theme` would also try to rebuild the initrd, which is
# Stage 12 build-initramfs' job in this build).
build_plymouth_assets() {
  THEME_DIR=/usr/share/plymouth/themes/halcyon
  WALLPAPER=/usr/share/backgrounds/halcyon/astronaut.png
  SPINNER=/usr/share/plymouth/themes/spinner
  FRAMES=30

  echo "::group::build-plymouth-assets — inputs"
  for f in "${WALLPAPER}" "${THEME_DIR}/theme.plymouth"; do
    if [ ! -f "${f}" ]; then
      echo "  FAIL  ${f} missing" >&2
      echo "::endgroup::"
      exit 1
    fi
  done
  if ! command -v magick >/dev/null 2>&1; then
    echo "  FAIL  ImageMagick (magick) not available — core.yml must install it first" >&2
    echo "::endgroup::"
    exit 1
  fi
  echo "  OK    inputs present (wallpaper + theme.plymouth + magick)"
  echo "::endgroup::"

  echo "::group::build-plymouth-assets — background.png"
  magick "${WALLPAPER}" \
    -resize 1920x1080^ -gravity center -extent 1920x1080 \
    -modulate 55,65 -gaussian-blur 0x5 -depth 8 \
    "${THEME_DIR}/background.png"
  echo "  OK    background.png generated ($(du -h "${THEME_DIR}/background.png" | cut -f1))"
  echo "::endgroup::"

  echo "::group::build-plymouth-assets — throbber frames (${FRAMES})"
  for i in $(seq 0 $((FRAMES - 1))); do
    start=$((i * 360 / FRAMES))
    end=$((start + 130))
    frame=$(printf 'throbber-%04d.png' $((i + 1)))
    magick -size 128x128 xc:none \
      -stroke 'srgb(122,150,255)' -strokewidth 9 \
      -draw "arc 14,14 114,114 ${start},${end}" -depth 8 \
      "${THEME_DIR}/${frame}"
  done
  throbber_count=$(find "${THEME_DIR}" -name 'throbber-*.png' | wc -l)
  if [ "${throbber_count}" -ne "${FRAMES}" ]; then
    echo "  FAIL  expected ${FRAMES} throbber frames, found ${throbber_count}" >&2
    echo "::endgroup::"
    exit 1
  fi
  echo "  OK    ${throbber_count} throbber frames generated"
  echo "::endgroup::"

  echo "::group::build-plymouth-assets — entry widgets from stock spinner theme"
  copied=0
  for f in entry.png entry-nolock.png lock.png keyboard.png bullet.png capslock.png; do
    if [ -f "${SPINNER}/${f}" ]; then
      cp "${SPINNER}/${f}" "${THEME_DIR}/${f}"
      copied=$((copied + 1))
    fi
  done
  if [ "${copied}" -eq 0 ]; then
    echo "  WARN  no spinner entry widgets found at ${SPINNER} — password box may render blank" >&2
  else
    echo "  OK    ${copied} entry widget(s) copied from the stock spinner theme"
  fi
  echo "::endgroup::"

  echo "::group::build-plymouth-assets — select theme"
  install -d /etc/plymouth
  cat >/etc/plymouth/plymouthd.conf <<'EOF'
# Created by image-info's build_plymouth_assets (build time). The initramfs
# stage regenerates the initrd after this, so the theme is active at boot.
[Daemon]
Theme=halcyon
EOF
  echo "  OK    /etc/plymouth/plymouthd.conf → Theme=halcyon"
  echo "::endgroup::"

  echo "--- build-plymouth-assets complete ---"
}

echo "::group::image-info — os-release identity"
sed -i 's|^NAME=.*|NAME=halcyon|; s|^PRETTY_NAME=.*|PRETTY_NAME="halcyon (Fedora bootc)"|' /usr/lib/os-release
if grep -q '^HOME_URL=' /usr/lib/os-release; then
  sed -i 's|^HOME_URL=.*|HOME_URL=https://github.com/aahsnr-work/halcyon|' /usr/lib/os-release
else
  echo 'HOME_URL=https://github.com/aahsnr-work/halcyon' >> /usr/lib/os-release
fi
echo "::endgroup::"

# plymouth theme assets are generated from the baked astronaut wallpaper
# (emits its own ::group:: folds)
build_plymouth_assets

echo "::group::image-info — image-info.json + sigstore policy assets"
# bazzite-steam / bazzite-steam-firstrun / 83-halcyon-audio read this file
install -d /usr/share/ublue-os
cat >/usr/share/ublue-os/image-info.json <<EOF
{ "image-name": "halcyon",
  "image-vendor": "aahsnr-work",
  "image-ref": "ostree-image-signed:docker://ghcr.io/aahsnr-work/halcyon",
  "image-tag": "latest",
  "base-image-name": "fedora-bootc",
  "fedora-version": "$(rpm -E %fedora)" }
EOF
chmod 0644 /usr/share/ublue-os/image-info.json

# Signed-rebase support: ship the cosign public key plus a sigstore policy
# entry so `bootc switch --enforce-container-sigpolicy ostree-image-signed:...`
# verifies out of the box.
#
# The key goes in /etc/pki/containers, NOT /usr/etc: /usr/etc is bootc's
# client-side view of the default /etc, must not be populated by images, and is
# checked by `bootc container lint`.
# The Key RUN in the generated Containerfile (stage-keys -> stage of the
# repo-root cosign.pub) already baked /etc/pki/containers/halcyon.pub before
# any module ran; verify it byte-matches the repo key instead of reinstalling.
if ! cmp -s /etc/pki/containers/halcyon.pub /tmp/files/cosign.pub; then
  echo "  FAIL  /etc/pki/containers/halcyon.pub differs from the repo cosign.pub (bluebuild stage-keys mismatch)" >&2
  exit 1
fi
install -d /etc/containers/registries.d
cat >/etc/containers/registries.d/halcyon.yaml <<'YAML'
docker:
  ghcr.io/aahsnr-work/halcyon:
    use-sigstore-attachments: true
YAML
# policy.json: require our sigstore signature for our image path, accept
# everything else (the bootc default).
#
# signedIdentity matchRepository is REQUIRED: cosign signs by digest
# (repo@sha256:...) so the signed identity is the repository, but bootc pulls by
# tag (repo:latest). The default matcher wants an exact identity match for
# tag-referenced images and would reject the signature.
cat >/etc/containers/policy.json <<'POLICY'
{
    "default": [{"type": "insecureAcceptAnything"}],
    "transports": {
        "docker": {
            "ghcr.io/aahsnr-work/halcyon": [
                {
                    "type": "sigstoreSigned",
                    "keyPath": "/etc/pki/containers/halcyon.pub",
                    "signedIdentity": {"type": "matchRepository"}
                }
            ]
        }
    }
}
POLICY
echo "  OK    image-info.json + halcyon.pub + policy.json + registries.d written"
echo "::endgroup::"

# --- verification (absorbed from branding-verify in the 2026-09-29
# one-file-per-stage consolidation; same RUN, gate-fail semantics unchanged:
# any FAIL sets fail=1 and the script exits 1 with a ::error:: annotation).
fail=0
gate() { local desc="$1"; shift; if "$@" >/dev/null 2>&1; then echo "  PASS  $desc"; else echo "  FAIL  $desc"; fail=1; fi; }

echo "::group::branding-verify — os-release + plymouth"
gate "os-release NAME=halcyon"           grep -q '^NAME=halcyon' /usr/lib/os-release
gate "os-release PRETTY_NAME"            grep -q '^PRETTY_NAME="halcyon' /usr/lib/os-release
gate "os-release HOME_URL"               grep -q '^HOME_URL=https://github.com/aahsnr-work/halcyon' /usr/lib/os-release
gate "image-info.json present"           test -s /usr/share/ublue-os/image-info.json
gate "sigstore pubkey shipped"           test -s /etc/pki/containers/halcyon.pub
gate "no /usr/etc tree created"          sh -c '! test -e /usr/etc'
gate "sigstore policy entry"             grep -q '"type": "sigstoreSigned"' /etc/containers/policy.json
gate "policy keyPath matches shipped key" grep -q '"keyPath": "/etc/pki/containers/halcyon.pub"' /etc/containers/policy.json
gate "policy matches signatures by repo" grep -q '"type": "matchRepository"' /etc/containers/policy.json
gate "registries.d sigstore attachments" grep -q 'use-sigstore-attachments: true' /etc/containers/registries.d/halcyon.yaml
gate "plymouth theme selected"           grep -q 'Theme=halcyon' /etc/plymouth/plymouthd.conf
gate "plymouth theme file"               test -f /usr/share/plymouth/themes/halcyon/theme.plymouth
gate "plymouth background asset"         test -f /usr/share/plymouth/themes/halcyon/background.png
gate "plymouth throbber frames"          sh -c 'ls /usr/share/plymouth/themes/halcyon/throbber-*.png >/dev/null 2>&1'
gate "wallpaper baked"                   test -f /usr/share/backgrounds/halcyon/astronaut.png
echo "::endgroup::"

[ "$fail" = 0 ] || { echo "::error::branding-verify failed"; exit 1; }
echo "--- branding-verify: all checks passed ---"
