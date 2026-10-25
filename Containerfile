# Bazzite is a Fedora Atomic system built and deployed as a complete bootable OCI image,
# rather than updated package-by-package on the live host. This recipe builds one Hyprland
# gaming image with the NVIDIA open kernel modules; bootc and rpm-ostree provide staged updates
# and rollback.
# Keep the Containerfile build: the image uses multi-stage akmods inputs, bind mounts,
# and package swaps to build the single published NVIDIA image (alcyone).
# Upstream Fedora release number
ARG FEDORA_VERSION="${FEDORA_VERSION:-44}"

# Full registry URL to the upstream Universal Blue base image
ARG BASE_IMAGE="${BASE_IMAGE:-ghcr.io/ublue-os/base-main:${FEDORA_VERSION}}"
# Kernel modification flavor (ogc = Open Gaming Collective / fsync gaming kernel)
ARG KERNEL_FLAVOR="${KERNEL_FLAVOR:-ogc}"
# Exact kernel version matching the selected akmods images. Resolved by the
# build tooling from the newest published tag; empty skips the version check.
ARG KERNEL_VERSION=""
# Combined akmods tag used across all akmods input stages. The local build
# scripts and CI pass the exact newest complete tag; a bare podman build falls
# back to the upstream floating tag so it still tracks the latest kernel.
ARG AKMODS_TAG="${AKMODS_TAG:-${KERNEL_FLAVOR}-${FEDORA_VERSION}-x86_64}"
# Pull the pre-compiled kernel and akmods rpms for the selected akmods tag
FROM ghcr.io/ublue-os/akmods:${AKMODS_TAG} AS akmods
# Pull the akmods-extra trees (device-specific kmods and their userspace parts;
# only nct6687d is installed, see build_files/kernel/install-kernel-akmods)
FROM ghcr.io/ublue-os/akmods-extra:${AKMODS_TAG} AS akmods-extra
# Pull the NVIDIA open driver rpms matching the pinned kernel
FROM ghcr.io/ublue-os/akmods-nvidia-open:${AKMODS_TAG} AS akmods-nvidia

# Build context helper: isolates build scripts so they can be bind-mounted without polluting image layers
FROM scratch AS ctx
COPY build_files /
COPY packages.json /

################
# BAZZITE BASE
################

FROM ${BASE_IMAGE} AS alcyone
# hadolint shell=bash

# Image name identifier
ARG IMAGE_NAME="${IMAGE_NAME:-alcyone}"
# Image vendor namespace
ARG IMAGE_VENDOR="${IMAGE_VENDOR:-halcyon-linux}"
# Image release branch (stable, testing, unstable)
ARG IMAGE_BRANCH="${IMAGE_BRANCH:-stable}"
# Fedora release number (redeclared in this stage so RUN instructions can use it)
ARG FEDORA_VERSION="${FEDORA_VERSION:-44}"
# Build version tag
ARG VERSION_TAG="${VERSION_TAG}"
# Formatted user-facing version string
ARG VERSION_PRETTY="${VERSION_PRETTY}"
# Kernel version (redeclared so RUN steps can verify against it; empty on local builds)
ARG KERNEL_VERSION

# Keep the shared Bazzite configuration in the image root.
COPY system_files/desktop/ /

# Install the dnf5 retry shim before the first dnf transaction. The kernel
# install runs before repository setup, and upstream metadata can be stale
# immediately after a repo republishes; without the shim that RUN gets no retries.
RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    usr_local=$(readlink -f /usr/local) && \
    mkdir -p "$usr_local/bin" && \
    install -m0755 /ctx/shared/dnf5 "$usr_local/bin/dnf5"

# Install kernel
RUN --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=bind,from=akmods,src=/kernel-rpms,dst=/tmp/kernel-rpms \
    --mount=type=bind,from=akmods-extra,src=/rpms/extra,dst=/tmp/rpms/extra \
    --mount=type=bind,from=akmods-extra,src=/rpms/kmods,dst=/tmp/rpms/kmods-extra \
    --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/kernel/install-kernel-akmods && \
    KERNEL_VERSION="${KERNEL_VERSION}" /ctx/finalization/verify kernel && \
    /ctx/shared/cleanup

# Configure repositories and package version locks used by later build steps.
RUN --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/packages/setup-repositories && \
    /ctx/finalization/verify repos && \
    /ctx/shared/cleanup

# Install the complete CLI COPR package set; its installer manages that repo.
RUN --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/packages/install-cli-tools && \
    /ctx/finalization/verify cli-tools && \
    /ctx/shared/cleanup

# Install the complete Python COPR package set as image utilities.
RUN --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/packages/install-utils && \
    /ctx/finalization/verify utils && \
    /ctx/shared/cleanup

# Remove packages superseded by image tooling.
RUN --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/packages/global-remove && \
    /ctx/finalization/verify removals && \
    /ctx/shared/cleanup

# Install shared gaming, hardware, and system utilities.
RUN --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=tmpfs,dst=/tmp \
    --mount=type=secret,id=GITHUB_TOKEN \
    /ctx/packages/install-common-packages && \
    /ctx/finalization/verify common-packages && \
    /ctx/shared/cleanup

# Install the gaming stack: protonplus, Steam, Lutris, and Winetricks.
RUN --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=tmpfs,dst=/tmp \
    --mount=type=secret,id=GITHUB_TOKEN \
    /ctx/packages/install-gaming-stack && \
    /ctx/finalization/verify gaming && \
    /ctx/shared/cleanup

# Install designated typography and font packages.
RUN --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/packages/install-fonts && \
    /ctx/finalization/verify fonts && \
    /ctx/shared/cleanup

# Install Hyprland desktop environment packages.
RUN --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/packages/install-base-pkgs && \
    /ctx/finalization/verify base-pkgs && \
    /ctx/shared/cleanup

# Install desktop applications and bees deduplication daemon.
RUN --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/packages/install-applications && \
    /ctx/finalization/verify applications && \
    /ctx/shared/cleanup

# Install TeX Live distribution packages.
RUN --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/packages/install-texlive-packages && \
    /ctx/finalization/verify texlive-packages && \
    /ctx/shared/cleanup

# Install Nix package manager and multi-user daemon.
RUN --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/packages/install-nix && \
    /ctx/finalization/verify nix && \
    /ctx/shared/cleanup

# Install ujust-picker from the latest GitHub release.
RUN --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=tmpfs,dst=/tmp \
    --mount=type=secret,id=GITHUB_TOKEN \
    /ctx/packages/install-ujust-picker && \
    /ctx/finalization/verify picker && \
    /ctx/shared/cleanup

# Mount non-removable device partitions automatically under /media/media-automount/ (ublue-os-media-automount-udev).
RUN --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/packages/install-media-automount && \
    /ctx/finalization/verify media && \
    /ctx/shared/cleanup

# Cleanup & Finalize
# Copy final system file overrides into root
COPY system_files/overrides/ /

# Apply shared desktop defaults after packages and overlays are present. The CLI/Python installers
# disable their own COPRs; system policy below disables the remaining build repositories after the
# NVIDIA package transaction. Metadata, initramfs, and account finalization run here and once more
# after the NVIDIA section, so the last pass includes everything.
RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    rm -f /etc/profile.d/toolbox.sh && \
    /ctx/system/configure-desktop-integration && \
    rm -f /usr/lib/systemd/system/service.d/50-keep-warm.conf && \
    /ctx/finalization/verify desktop-integration

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    /ctx/just/import-bazzite-justfiles && \
    /ctx/finalization/verify justfiles

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    /ctx/system/configure-system-services && \
    /ctx/finalization/verify services

# Show the GRUB menu long enough to pick a deployment or edit kernel arguments.
RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    /ctx/system/configure-grub && \
    /ctx/finalization/verify grub

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=secret,id=GITHUB_TOKEN \
    /ctx/packages/install-system-integration-files && \
    /ctx/finalization/verify integration-files

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    /ctx/finalization/image-info && \
    /ctx/finalization/verify image-info

RUN --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/kernel/build-initramfs && \
    /ctx/finalization/verify initramfs

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/finalization/finalize && \
    rm -rf \
        /etc/.pwd.lock \
        /etc/passwd- \
        /etc/group- \
        /etc/shadow- \
        /etc/gshadow- \
        /etc/subuid- \
        /etc/subgid- && \
    /ctx/finalization/verify finalize

#############################
# NVIDIA DRIVER INTEGRATION
#############################

# Add NVIDIA driver packages matched to the kernel artifacts.

# Kernel modification flavor (read by build-initramfs)
ARG KERNEL_FLAVOR="${KERNEL_FLAVOR:-ogc}"

# Fetch NVIDIA driver
# Copy NVIDIA driver configuration files into root.
COPY system_files/nvidia/ /

# Remove everything that doesn't work well with NVIDIA.
RUN --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/nvidia/configure-nvidia && \
    /ctx/finalization/verify nvidia-config && \
    /ctx/shared/cleanup

# Install NVIDIA driver
RUN --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=bind,from=akmods-nvidia,src=/rpms,dst=/tmp/rpms/nvidia \
    --mount=type=tmpfs,dst=/tmp \
    --mount=type=secret,id=GITHUB_TOKEN \
    /ctx/nvidia/install-nvidia-driver && \
    rm -f /usr/share/vulkan/icd.d/nouveau_icd.*.json && \
    /ctx/finalization/verify nvidia && \
    /ctx/shared/cleanup

# Disable the remaining build-only repositories after the final package transaction.
RUN --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=bind,from=ctx,source=/,target=/ctx \
    /ctx/system/configure-system-policy && \
    /ctx/finalization/verify system-policy

# Cleanup & Finalize
RUN --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/nvidia/finalize-nvidia && \
    /ctx/finalization/verify nvidia-finalize

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    /ctx/finalization/image-info && \
    /ctx/finalization/verify image-info

RUN --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/kernel/build-initramfs && \
    /ctx/finalization/verify initramfs

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/finalization/finalize && \
    rm -rf \
        /etc/.pwd.lock \
        /etc/passwd- \
        /etc/group- \
        /etc/shadow- \
        /etc/gshadow- \
        /etc/subuid- \
        /etc/subgid- && \
    /ctx/finalization/verify finalize

# Verify the published image before the final lint gate.
RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    /ctx/finalization/verify final

RUN --mount=type=tmpfs,target=/run --network=none \
    sh -c 'rm -rf "$(readlink -f /usr/local)/bin/dnf5" && rmdir "$(readlink -f /usr/local)/bin" 2>/dev/null; bootc container lint'
