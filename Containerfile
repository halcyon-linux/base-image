# Bazzite is a Fedora Atomic system built and deployed as a complete bootable OCI image,
# rather than updated package-by-package on the live host. This recipe builds one DE-free
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
# Exact kernel version matching pre-built akmods images
ARG KERNEL_VERSION="${KERNEL_VERSION:-7.2.7-ogc1.1.fc${FEDORA_VERSION}}"

# Pull the pre-compiled kernel and akmods rpms for the pinned kernel version
FROM ghcr.io/ublue-os/akmods:${KERNEL_FLAVOR}-${FEDORA_VERSION}-${KERNEL_VERSION} AS akmods
# Pull the akmods-extra trees (device-specific kmods and their userspace parts;
# only nct6687d is installed, see build_files/install-kernel-akmods)
FROM ghcr.io/ublue-os/akmods-extra:${KERNEL_FLAVOR}-${FEDORA_VERSION}-${KERNEL_VERSION} AS akmods-extra
# Pull the NVIDIA open driver rpms matching the pinned kernel
FROM ghcr.io/ublue-os/akmods-nvidia-open:${KERNEL_FLAVOR}-${FEDORA_VERSION}-${KERNEL_VERSION} AS akmods-nvidia
# Pull the pre-packaged Homebrew standalone root (digest-pinned)
FROM ghcr.io/ublue-os/brew:latest@sha256:5bdf54dc7c21c22db29df6550e3711788719c5123549ea6dc5645d5af47795e3 AS brew

# Build context helper: isolates build scripts so they can be bind-mounted without polluting image layers
FROM scratch AS ctx
COPY build_files /

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

# Use the standalone files exposed by the Homebrew image's /system_files tree.
COPY --from=brew /system_files/ /tmp/brew_files/
RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    /ctx/packages/install-brew-files

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

# Install the patched gaming stack and its supporting codecs.
RUN --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/packages/install-gaming-stack && \
    /ctx/shared/cleanup

# Remove packages superseded by image tooling.
RUN --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/packages/global-remove && \
    /ctx/shared/cleanup

# Install shared gaming, hardware, and system utilities.
RUN --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=tmpfs,dst=/tmp \
    --mount=type=secret,id=GITHUB_TOKEN \
    /ctx/packages/install-common-packages && \
    /ctx/shared/cleanup

# Install Steam, Lutris, gaming middleware, and Winetricks.
RUN --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=tmpfs,dst=/tmp \
    --mount=type=secret,id=GITHUB_TOKEN \
    /ctx/packages/install-steam-lutris && \
    /ctx/finalization/verify packages && \
    /ctx/shared/cleanup

# Install ujust-picker from the latest GitHub release.
RUN --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=tmpfs,dst=/tmp \
    --mount=type=secret,id=GITHUB_TOKEN \
    /ctx/packages/install-ujust-picker && \
    /ctx/shared/cleanup

# Mount non-removable device partitions automatically under /media/media-automount/ (ublue-os-media-automount-udev).
RUN --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/packages/install-media-automount && \
    /ctx/shared/cleanup

# Cleanup & Finalize
# Copy final system file overrides into root
COPY system_files/overrides/ /

# This pass applies shared defaults after packages and overlays are present, disables build-only
# repositories, and configures the services shipped in the image. Metadata, initramfs, and account
# finalization run here and once more after the NVIDIA section, so the last pass includes everything.
RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    rm -f /etc/profile.d/toolbox.sh && \
    /ctx/system/configure-desktop-integration && \
    rm -f /usr/lib/systemd/system/service.d/50-keep-warm.conf

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    /ctx/just/import-bazzite-justfiles

RUN --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=bind,from=ctx,source=/,target=/ctx \
    /ctx/system/configure-system-policy

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    /ctx/system/configure-system-services

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=secret,id=GITHUB_TOKEN \
    /ctx/packages/install-system-integration-files

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    /ctx/finalization/image-info

RUN --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/kernel/build-initramfs

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
        /etc/subgid-

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

# Cleanup & Finalize
RUN --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/nvidia/finalize-nvidia

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    /ctx/finalization/image-info

RUN --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/kernel/build-initramfs

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
        /etc/subgid-

# Verify the published image before the final lint gate.
RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    /ctx/finalization/verify final

RUN --mount=type=tmpfs,target=/run --network=none bootc container lint
