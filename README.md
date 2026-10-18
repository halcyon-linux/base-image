# Halcyon — alcyone

**alcyone** is one of the two Halcyon images. It is the DE-free, Containerfile-built
variant: based on Universal Blue `base-main`, using the OGC kernel, retaining shared
Bazzite gaming and system configuration, and installing the NVIDIA open kernel
modules (`nvidia-open`). The sibling image, **ceyx**, is the BlueBuild-built variant
(see the `bluebuild` branch) and ships a Hyprland desktop.

alcyone does not currently include a desktop environment or compositor. Hyprland is
planned as a later addition.

## Halcyon family

| Image      | Built with   | Desktop             | Rebase target                                          |
| ---------- | ------------ | ------------------- | ------------------------------------------------------ |
| `alcyone`  | Containerfile | none (DE-free)      | `ghcr.io/halcyon-linux/alcyone:stable`                 |
| `ceyx`     | BlueBuild    | Hyprland + Noctalia | `ghcr.io/halcyon-linux/ceyx:latest`                    |

Both images report `NAME="Halcyon"` in `/etc/os-release`; `VARIANT_ID` distinguishes
them (`alcyone` or `ceyx`).

## Published image

```text
ghcr.io/halcyon-linux/alcyone:stable
```

For an existing bootc or rpm-ostree system, rebase to the image with:

```bash
sudo rpm-ostree rebase ostree-unverified-registry:ghcr.io/halcyon-linux/alcyone:stable
```

## Build locally

The local Just defaults build the published image target:

```bash
just build
```

The Containerfile starts from `base-main`, installs the shared gaming and system packages, then applies NVIDIA driver setup and finalization. The source for those build steps is under `build_files/`.

## Workflows

- `.github/workflows/build.yml` builds and publishes `alcyone` on every push to `main` and on a daily schedule.
- `.github/workflows/clean.yml` removes old versions of that package.

## Upstream references

This project is based on [Bazzite](https://github.com/ublue-os/bazzite) and [Universal Blue](https://universal-blue.org/). The upstream [Bazzite documentation](https://docs.bazzite.gg/) is useful background for shared features, though this fork currently publishes only the image described above.
