# Bazzite NVIDIA

This fork currently builds and publishes one image: `bazzfin-nvidia`. It is based on Universal Blue `base-main`, uses the OGC kernel, retains shared Bazzite gaming and system configuration, and installs the NVIDIA open kernel modules (`nvidia-open`).

The image does not currently include a desktop environment or compositor. Hyprland is planned as a later addition.

## Published image

```text
ghcr.io/halcyon-linux/bazzfin-nvidia:stable
```

For an existing bootc or rpm-ostree system, rebase to the image with:

```bash
sudo rpm-ostree rebase ostree-unverified-registry:ghcr.io/halcyon-linux/bazzfin-nvidia:stable
```

## Build locally

The local Just defaults build the published image target:

```bash
just build
```

The Containerfile starts from `base-main`, installs the shared gaming and system packages, then applies NVIDIA driver setup and finalization. The source for those build steps is under `build_files/`.

## Workflows

- `.github/workflows/build.yml` builds and publishes `bazzfin-nvidia` on every push to `main` and on a daily schedule.
- `.github/workflows/clean.yml` removes old versions of that package.

## Upstream references

This project is based on [Bazzite](https://github.com/ublue-os/bazzite) and [Universal Blue](https://universal-blue.org/). The upstream [Bazzite documentation](https://docs.bazzite.gg/) is useful background for shared features, though this fork currently publishes only the image described above.
