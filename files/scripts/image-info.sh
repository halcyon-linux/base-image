#!/usr/bin/env bash
# halcyon build step — image-info: write /usr/share/ublue-os/image-info.json,
# which the vendored bazzite-steam{,-firstrun} wrappers and 83-halcyon-audio
# read (without it they degrade). The `signing` module — first in the recipe —
# already owns policy.json + registries.d from the staged cosign.pub.
set -euo pipefail

IMAGE_NAME=halcyon
IMAGE_VENDOR=halcyon-linux
IMAGE_REF="ostree-image-signed:docker://ghcr.io/${IMAGE_VENDOR}/${IMAGE_NAME}"
FEDORA_VERSION="$(rpm -E %fedora)"

install -d -m0755 /usr/share/ublue-os
cat >/usr/share/ublue-os/image-info.json <<EOF
{
  "image-name": "${IMAGE_NAME}",
  "image-vendor": "${IMAGE_VENDOR}",
  "image-ref": "${IMAGE_REF}",
  "image-tag": "latest",
  "base-image-name": "fedora-bootc",
  "fedora-version": "${FEDORA_VERSION}"
}
EOF
chmod 0644 /usr/share/ublue-os/image-info.json

# --- verification ---
fail=0
gate() {
  local desc="$1"
  shift
  if "$@" >/dev/null 2>&1; then echo "  PASS  $desc"; else
    echo "  FAIL  $desc"
    fail=1
  fi
}

echo "::group::image-info-verify"
gate "image-info.json present" test -s /usr/share/ublue-os/image-info.json
gate "image-info.json valid JSON" jq -e . /usr/share/ublue-os/image-info.json
gate "image-ref baked" grep -q '"image-ref"' /usr/share/ublue-os/image-info.json
echo "::endgroup::"

[ "$fail" = 0 ] || {
  echo "::error::image-info-verify failed"
  exit 1
}
echo "--- image-info complete ---"
