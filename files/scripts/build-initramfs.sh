#!/usr/bin/env bash
# halcyon build step — build-initramfs (LAST: plymouth + nvidia hooks baked in)
# Must run after 10-packages (plymouth, dracut helpers), 60-branding (the
# halcyon theme plymouthd.conf selection) and the 02-kernel payload extract
# (99-nvidia.conf add_drivers + 60-nvidia.rules) so the initrd bakes in the
# splash theme and the NVIDIA driver hooks. rakuos-base generates its
# initramfs last for exactly this reason.
set -euo pipefail
echo "::group::build-initramfs — depmod + dracut for the p03 kernel"
KVER="$(rpm -q --qf '%{VERSION}-%{RELEASE}.%{ARCH}' kernel-p03)"
echo "  INFO  generating initramfs for ${KVER}"

# regen module deps in case anything landed after the kernel stage
depmod "${KVER}"

export DRACUT_NO_XATTR=1
dracut --no-hostonly --kver "${KVER}" --reproducible --zstd -v \
  --add ostree -f "/usr/lib/modules/${KVER}/initramfs.img" > /dev/null
chmod 0600 "/usr/lib/modules/${KVER}/initramfs.img"
echo "  INFO  initramfs: $(du -h "/usr/lib/modules/${KVER}/initramfs.img" | cut -f1)"
echo "::endgroup::"
