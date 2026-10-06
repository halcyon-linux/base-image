# halcyon

A lean Hyprland gaming-desktop OCI image built with [BlueBuild](https://blue-build.org)
on `ghcr.io/ublue-os/bazzite-nvidia-open:latest`.

- Hyprland + Noctalia on the Bazzite base (KDE Plasma removed), zsh as the
  default shell, login via getty@tty2 (a display manager — ly — is planned)
- Bazzite's kernel and NVIDIA open driver stack, inherited untouched
- Native gaming stack, no Flatpak: Steam, Lutris and Heroic Launcher install
  as RPMs for maximum Proton/Wine compatibility (RakuOS model), plus
  gamescope, mangohud, gamemode, umu, scx schedulers and the base's
  `bazzite-steam` wrapper
- GNOME file stack instead of KDE's: nautilus + file-roller
- Curated font set (JetBrainsMono, Nerd Fonts, Noto Color Emoji) over a
  dnf-swept base font payload (fonts that other packages pull back as deps
  are fine); GUI GPG prompts via pinentry-gnome3; gnome-keyring SSH
  agent; openssh-clients wired
- GRUB menu visible for 10 seconds (rebasing machines: `ujust regenerate-grub`)
- `ujust` tooling (`ujust --list`), `uupd` system updates, Nix + home-manager ready
- Curated dev tooling; every module is gated by build-time verify scripts

## Install / rebase

> [!WARNING]
> [bootc images are an experimental feature](https://www.fedoraproject.org/wiki/Changes/OstreeNativeContainerStable) — try at your own discretion.

Rebase an existing Fedora atomic system (bootc or rpm-ostree):

```bash
sudo bootc switch ghcr.io/halcyon-linux/halcyon:latest
```

If ghcr.io is slow from your network, the same tags are mirrored to
Docker Hub (`docker.io/halcyon-linux/halcyon`, pushed by the same workflow in
zstd:chunked form for smaller delta pulls):

```bash
sudo bootc switch docker.io/halcyon-linux/halcyon:latest
```

or, on an rpm-ostree system:

```bash
sudo rpm-ostree rebase ostree-unverified-registry:ghcr.io/halcyon-linux/halcyon:latest
```

Reboot to apply. The image ships its own sigstore policy and public key, so
`bootc switch --enforce-container-sigpolicy` verifies the signature baked into
the image (`cosign.pub` at the repo root) from the first update on — from
either registry, both are trusted by the baked policy. A
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
