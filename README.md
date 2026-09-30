# halcyon

A lean Hyprland gaming-desktop OCI image built with [BlueBuild](https://blue-build.org)
on `quay.io/fedora/fedora-bootc`.

- Hyprland + Noctalia, greetd with the noctalia greeter, zsh as the default shell
- `catpieleaf/kernel-p03` kernel with prebuilt `nvidia-open` modules and negativo17
  NVIDIA userland (RPM Fusion's NVIDIA chain is excluded)
- Steam/Lutris gaming stack with the vendored `bazzite-steam` wrappers,
  gamescope, mangohud, umu, scx schedulers
- `ujust` tooling (`ujust --list`), `uupd` system updates, Nix + home-manager ready
- Curated dev tooling; every module is gated by build-time verify scripts

## Install / rebase

> [!WARNING]
> [bootc images are an experimental feature](https://www.fedoraproject.org/wiki/Changes/OstreeNativeContainerStable) — try at your own discretion.

Rebase an existing Fedora atomic system (bootc or rpm-ostree):

```bash
sudo bootc switch ghcr.io/halcyon-linux/halcyon:latest
```

or, on an rpm-ostree system:

```bash
sudo rpm-ostree rebase ostree-unverified-registry:ghcr.io/halcyon-linux/halcyon:latest
```

Reboot to apply. The image ships its own sigstore policy and public key, so
`bootc switch --enforce-container-sigpolicy` verifies the signature baked into
the image (`cosign.pub` at the repo root) from the first update on. A
`rebase-to-custom` ujust recipe wraps the same flow.

## Verification

Images are signed with [cosign](https://github.com/sigstore/cosign) in the
legacy attachment format that bootc's client-side policy can verify:

```bash
cosign verify --key cosign.pub ghcr.io/halcyon-linux/halcyon
```

## Build

Builds run in CI via [BlueBuild](https://blue-build.org) (see
`.github/workflows/build.yml`): the recipe is validated, built with the pinned
BlueBuild CLI, verified end-state (`final-verify`) and with
`bootc container lint`, then pushed and signed. Architecture rules and the
per-module verification gates are documented in [AGENTS.md](AGENTS.md).
