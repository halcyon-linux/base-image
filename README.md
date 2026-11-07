# Halcyon — `alcyone`

Signed, bootc-native Fedora Atomic image for an NVIDIA gaming workstation. Built from a single `Containerfile` on Universal Blue `base-main`, with the OGC gaming kernel, NVIDIA **open** kernel modules, and a Hyprland + Noctalia desktop.

| | |
|---|---|
| **Image** | `ghcr.io/halcyon-linux/alcyone` (`stable`, `latest`, `YYYYMMDD` — same digest) |
| **Base** | `ghcr.io/ublue-os/base-main:44` (Fedora 44, x86_64) |
| **Kernel** | OGC from `ublue-os/akmods`, version-locked |
| **GPU** | NVIDIA open modules (`akmods-nvidia-open`), multilib |
| **Extra kmod** | `nct6687d` only (NCT6687 sensors, MSI Z790-P target) |
| **Desktop** | SDDM + Hyprland + Noctalia |
| **Updates** | bootc / rpm-ostree, `uupd`, greenboot |
| **Signing** | cosign; public key [`cosign.pub`](cosign.pub) |
| **Branch** | `containerfile` (default and release branch) |
| **License** | Apache-2.0 |

## Contents

1. [Before you switch](#before-you-switch)
2. [Install: verify and switch](#install-verify-and-switch)
3. [Using the system](#using-the-system)
4. [Build locally](#build-locally)
5. [CI/CD](#cicd)
6. [Build-time verification gates](#build-time-verification-gates)
7. [Security and supply-chain](#security-and-supply-chain)
8. [Design decisions](#design-decisions)
9. [Repository layout](#repository-layout)
10. [Contributing](#contributing)
11. [Upstream and license](#upstream-and-license)

## Before you switch

Personal, opinionated image. Check first:

- **NVIDIA GPU required.** Open modules support Turing (GTX 16 / RTX 20) and newer only.
- **Dotfiles are opt-in.** Nothing touches `$HOME` unless you run `ujust dotfiles enable`.
- **Signatures are not enforced by default.** Verify before installing; see [Install: verify and switch](#install-verify-and-switch).
- **No installer.** No ISOs or disk images. Install any bootc-capable Fedora Atomic system (Silverblue, Kinoite, Bazzite, Bluefin, …) and switch, or build a disk image with `bootc-image-builder`.

## Install: verify and switch

Run on the Atomic host you are converting. Verify the signature, then pin to the verified digest.

```bash
# 1. Tools
command -v cosign skopeo curl openssl jq
cosign version   # v3.1.3+

# 2. Public key and fingerprint
curl -fsSLO https://raw.githubusercontent.com/halcyon-linux/base-image/containerfile/cosign.pub
openssl pkey -pubin -in cosign.pub -outform DER | sha256sum
# expected: 9410658270bd845ed529f5f2a2f6a1a62bc5c28a49456b6cc4d97d57b1dca240

# 3. Resolve tag to digest
IMAGE=ghcr.io/halcyon-linux/alcyone
DIGEST=$(skopeo inspect --format '{{.Digest}}' docker://$IMAGE:stable)

# 4. Verify signature
cosign verify --key cosign.pub "$IMAGE@$DIGEST"

# 5. Switch and reboot
sudo bootc switch "$IMAGE@$DIGEST"
sudo systemctl reboot
```

You are now pinned to that digest. `bootc upgrade`, `ujust update`, and `uupd` do not move the image until you switch again. To track `:stable`, enforce signature checks first; otherwise re-run steps 3–4 before each switch.

rpm-ostree without bootc: `sudo rpm-ostree rebase ostree-unverified-registry:ghcr.io/halcyon-linux/alcyone:stable` — tag-based, digest not enforced. Prefer bootc.

### Enforce signature checks

`bootc`/`rpm-ostree` accept unsigned images by default. Install the key and add a signature requirement to `/etc/containers/policy.json`:

```bash
sudo install -Dm0644 cosign.pub /etc/pki/containers/halcyon-linux.pub
sudo tee /etc/containers/registries.d/halcyon-linux.yaml >/dev/null <<'EOF'
docker:
  ghcr.io/halcyon-linux:
    use-sigstore-attachments: true
EOF
sudo jq '.transports.docker["ghcr.io/halcyon-linux/alcyone"] = [{
  "type": "sigstoreSigned",
  "keyPath": "/etc/pki/containers/halcyon-linux.pub",
  "signedIdentity": { "type": "matchRepository" }
}]' /etc/containers/policy.json | sudo tee /etc/containers/policy.json >/dev/null
```

## Using the system

Run `ujust` for the full recipe list. Common:

| Recipe | Purpose |
|---|---|
| `update` / `upgrade` | Update OS image and apps via `uupd` |
| `changelogs` | Open recent image changes |
| `dotfiles` | chezmoi menu: `status`, `sync`, `diff`, `edit` |
| `configure-grub`, `regenerate-grub`, `grub-timeout` | GRUB maintenance |
| `configure-snapshots`, `configure-beesd` | Btrfs snapshots and deduplication |
| `tailscale` | Manage Tailscale |
| `update-nvidia-runtime` | Sync NVIDIA Flatpak runtime |
| `aide-init`, `aide-check`, `aide-rebaseline` | AIDE file-integrity baseline |
| `audit-status`, `audit-lock`, `audit-unlock` | Audit state; lock/unlock audit rules |
| `nix-relabel-unit [unit\|store path]` | Relabel Nix store units |

### Installing software

Prefer Homebrew, Flatpak, Nix, Distrobox or containers over layering RPMs. Only the Flathub remote is declared; no Flatpak apps ship.

### Nix

`nix`, `nix-daemon` and `busybox` ship preinstalled (`/nix` bind-mounted from `/var/nix`, multi-user daemon, flakes enabled). Do not use the Determinate installer (dropped OSTree support). Set up Home Manager:

```bash
nix run home-manager/master -- init --switch
```

A systemd unit built into the store needs manual SELinux relabeling after each rebuild:

```bash
ujust nix-relabel-unit myservice.service
```

`nix-daemon.socket` may show failed on the first boot after an update; later boots are clean. Distrobox containers need `--volume /nix:/nix:ro --volume /run/opengl-driver:/run/opengl-driver:ro`.

### Runtime facts

- Root on Btrfs (zstd, `bees` deduplication; `compsize` measures savings).
- Kernel and NVIDIA driver move together on the same akmods tag.
- Steam does not autostart on first login.

### Auditing (auditd)

`auditd` runs with Halcyon rules in `/etc/audit/rules.d/`. Verify with `sudo auditctl -l` (must not be a lone `-a never,task`) and `sudo auditctl -s` (expect `enabled 1`). `ujust audit-status` / `ujust audit-report` summarize state. Add local rules to your own file under `/etc/audit/rules.d/`, not a shipped one. `ujust audit-lock` makes rules immutable until reboot.

### Dotfiles with chezmoi

Opt-in per user: `ujust dotfiles enable` clones [`aahsnr-configs/dotfiles`](https://github.com/aahsnr-configs/dotfiles) and force-applies it to `$HOME` daily. `ujust dotfiles disable` removes the flag; managed files stay. Edit via `chezmoi edit --apply` — the daily timer silently reverts `$HOME` edits not added back. Never add plaintext secrets; use `chezmoi add --encrypt`.

## Build locally

Prerequisites: Linux, `podman`, `just`, `git`, `skopeo`, `jq`, network to `ghcr.io`/Copr/GitHub, free disk.

```bash
just                # list recipes
just build          # build localhost/alcyone-build:44-<git-branch>
just run            # shell in the built image (builds first if missing)
just just-check     # check .just / Justfile formatting
```

`just build` resolves the akmods tag (newest that ships `nct6687d`), cosign-verifies upstream images, then builds with the same digests as CI. Local images are **not rechunked or signed**. `GITHUB_TOKEN` is optional and only sent to GitHub hosts.

Manual:

```bash
AKMODS_TAG=$(just_scripts/resolve-akmods ogc 44 x86_64 nct6687d)
KERNEL_VERSION=${AKMODS_TAG#ogc-44-}
podman build -f Containerfile --target alcyone \
  --build-arg FEDORA_VERSION=44 \
  --build-arg KERNEL_FLAVOR=ogc \
  --build-arg AKMODS_TAG="$AKMODS_TAG" \
  --build-arg KERNEL_VERSION="$KERNEL_VERSION" \
  -t localhost/alcyone:dev .
```

Fast checks:

```bash
bash tests/test-dnf5-retry.sh
for f in build_files/*/* just_scripts/* tests/*.sh; do bash -n "$f"; done
```

## CI/CD

`.github/workflows/build.yml` builds and publishes daily at `40 4 * * *` UTC and on pushes to `containerfile`. Publishing and signing run **only** when `github.ref == refs/heads/containerfile`. Actions pinned to full SHAs; `permissions: {}` at top level. Cleanup (`.github/workflows/clean.yml`) runs Sundays 00:15 UTC, deleting package versions older than 90 days.

Run from terminal:

```bash
gh workflow run build.yml --ref containerfile   # publishes and signs
gh workflow run clean.yml --ref containerfile
gh run list --workflow build.yml --status in_progress
gh run watch <run-id>
gh run cancel <run-id>
```

## Build-time verification gates

`build_files/finalization/verify <stage>` runs after each build stage; `bootc container lint` runs last. 31 stage groups plus `packages`. Asserts required RPMs present, forbidden RPMs absent (Waydroid, fish, greetd, auxiliary zsh plugins, handheld packages, `nerd-fonts`, `pinentry-qt`, `nvidia-gpu-firmware`), kernel matches `KERNEL_VERSION`, build COPRs disabled after use, Flatpak Flathub-only, baked TeX formats exist, `image-ref` starts with `ostree-image-signed:docker://ghcr.io/`.

## Security and supply-chain

- Images signed by digest; publish/sign guarded to the `containerfile` branch; actions pinned to SHAs; `permissions: {}` at top level.
- `cosign.key` / `*.key` git-ignored and excluded from build contexts; signing via Actions secret only.
- Upstream images cosign-verified (`build_files/keys/ublue-os.pub`) and consumed by digest. External files pinned by tag/commit plus sha256 in `build_files/downloads/manifest.tsv`; vendor keys checked against pinned fingerprints; no `--nogpgcheck`.
- `GITHUB_TOKEN` mounted only in the package-free `downloads` stage.
- `auditd` on by default with Halcyon rules. Wazuh deliberately not shipped (installs under `/var/ossec`, wiped by `finalize`).

Open items: `cosign.pub` vs CI `SIGNING_SECRET` unconfirmed (A-002); runtime ujust downloads still mutable (A-008); builds not bit-for-bit reproducible.

## Design decisions

- Podman-only tooling (CI also uses buildah, skopeo, cosign). `docker://` is an OCI transport name only; no Docker Engine.
- One custom image on this branch; `akmods*`, `brew`, `ctx` are inputs.
- SDDM (not greetd); zsh only (no auxiliary zsh plugins). Waydroid deferred; forbidden by `verify`.
- Flatpak: Flathub-only remote, no apps ship.
- TeX Live baked at build time (COPR has no `%post`).
- Dotfiles over HTTPS, pushes over SSH; opt-in per user.

## Repository layout

```
Containerfile   # multi-stage build, target `alcyone`
Justfile        # build / run / list / clean images
packages.json   # package sets, repos, swaps, version locks
cosign.pub      # image signature verification key
AGENTS.md       # guide for AI agents and maintainers
LICENSE         # Apache-2.0
build_files/    # bind-mounted at /ctx during build
  finalization/ # finalize, image-info, verify
  kernel/       # kernel swap, kmods, initramfs
  nvidia/       # NVIDIA configure / install / finalize
  packages/     # one installer per package set + repo setup
  downloads/    # pinned manifest + fetch-pinned
  keys/         # vendored ublue cosign key, Terra RPM key
  shared/       # cleanup, dnf5 retry shim, ghcurl, check-gpg-fingerprints
  system/       # desktop integration, GRUB, services, repo policy
  just/         # imports Bazzite ujust files
just_scripts/   # build-image, resolve-akmods, verify-upstream-images, bump-downloads
system_files/
  desktop/      # shared config: /etc, /usr/lib, /usr/share, /nix
  nvidia/       # NVIDIA-only payload
  overrides/    # copied last, wins on conflict
tests/test-dnf5-retry.sh
.containerignore
.github/        # workflows (build, clean), renovate
```

## Contributing

Read [`AGENTS.md`](AGENTS.md) first. Pushes to `containerfile` touching non-`.md`/`.txt` files build and publish — work on a branch and open a PR. Conventional-commit style (`fix(build): …`, `feat(packages): …`, `docs: …`). Markdown-only pushes do not trigger CI.

## Upstream and license

Based on [Bazzite](https://github.com/ublue-os/bazzite) and [Universal Blue](https://universal-blue.org/). Apache-2.0 (see [`LICENSE`](LICENSE)).

Planned and completed work is tracked in [`TODO.yaml`](TODO.yaml).
