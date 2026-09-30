# AGENTS.md — halcyon (base-image)

Guidance for AI coding agents (and humans) working in this repository. This is a
from-scratch BlueBuild project: every claim below was checked against the tree.
A file or directory named here as MISSING is referenced but not yet written —
do not assume its contents.

## 1. What this repo is

`halcyon` builds a Hyprland gaming-desktop OCI image on
`quay.io/fedora/fedora-bootc:44` via the BlueBuild CLI (`bluebuild generate` +
build). `recipes/halcyon.yml` is the build definition: base image, labels, and
the module list in execution order. Shared module groups live in
`recipes/modules/*.yml` and are pulled in with `from-file: modules/<name>.yml`.
Package installs use BlueBuild's `dnf` module with `install-weak-deps: false`;
one-off build logic uses the `script` module (`scripts:` from `files/scripts/`,
or inline `snippets:`); systemd units ship in the `files/system/` overlay and
are enabled by name with the `systemd` module. The nix module's logic follows
[fu5ha/winter](https://github.com/fu5ha/winter) (`recipes/modules/nix.yaml`:
package set, enable order, verify checks); file placement follows this repo's
overlay rule, not winter's sidecar dirs.

## 2. Repository layout (actual)

```
recipes/halcyon.yml       # THE build definition. Module order is load-bearing:
                          #   signing → files (system → /) → files (dnf-libdnf5 →
                          #   /etc/dnf) → removals → install-kernel.sh →
                          #   programming → apps → core → desktop → gaming →
                          #   hardware → ublue-pkgs → terra → devtools → nix →
                          #   built-apps → ujust-system → finish → final-verify →
                          #   bootc-lint (last five MISSING, see §5)
recipes/modules/*.yml     # present: apps, core, desktop, devtools, gaming,
                          #   hardware, nix, programming, removals, terra,
                          #   ublue-pkgs
files/                    # mounted at /tmp/files in every module RUN; never baked in
  system/                 # static overlay — recipe copies files/system/* → /
                          #   etc/profile.d/01-nix-resolve-home-env.sh (mode 755)
                          #   usr/lib/tmpfiles.d/zz-halcyon-nix.conf
                          #   usr/lib/systemd/system/{var-nix.service,nix.mount}
  dnf/vscode.repo         # local .repo consumed by the dnf module (apps)
  dnf-libdnf5/libdnf5.conf.d/99-halcyon-retries.conf  # → /etc/dnf (retries=20)
  scripts/install-kernel.sh  # kernel + NVIDIA userland installer (script module)
AGENTS.md / README.md (template text) / TODO.md / LICENSE / .gitignore
```

NOT in this repo: `Justfile`, `files/packages.json`, `cosign.pub`,
`.containerignore`, `.github/`, `verify/`, `halcyon.env`,
`files/python-packages/`, `files/scripts/lib/`. Do not cite them in plans.

## 3. Module inventory (what each file actually does)

- `signing` (inline in recipe): image signing setup.
- `files` (inline): `system → /` runs first, so overlay files precede every
  package install — an RPM owning the same path would silently overwrite an
  overlaid file (no current collisions). `dnf-libdnf5 → /etc/dnf` second.
- `removals.yml`: `dnf remove` (GNOME/Steam Deck leftovers, firefox, nano…)
  with `auto-remove: true`. Also declares `scripts: guarded-removals.sh` and
  `fonts-cleanup.sh` — both MISSING from `files/scripts/` (validate does not
  check this; the build RUNs will fail until they land).
- `install-kernel.sh` (inline `script`): Stage 02 banner, `set -euo pipefail`,
  `::group::` folds. Kernel + prebuilt modules from COPR
  `catpieleaf/kernel-p03`; NVIDIA userland from negativo17 (repo id
  `fedora-nvidia`); RPM Fusion disabled for its transactions. Three
  negativo17 subpackages (`nvidia-driver-cuda`, `nvidia-kmod-common`,
  `nvidia-settings`) are payload-extracted file-only via `rpm2cpio` — never add
  them to a `dnf install` line. Installs use `tsflags=noscripts`; depmod runs
  here, dracut is deferred to the MISSING finish module.
- `programming.yml`: toolchains (`python3`, `nodejs22`, `gcc-c++`, `cargo`,
  `cmake`, `golang`, `perl`) — single-module schema.
- `apps.yml`: `repos` (local `vscode.repo`, brave `.repo` URL, both GPG keys,
  COPR `aahsnr-work/applications`, `cleanup: true`) then `install` — editors,
  browsers, VPNs, office apps.
- `core.yml`: `group-install custom-environment` (`with-optional: false`) then
  the base package install.
- `desktop.yml`: COPR `aahsnr-work/base-pkgs` (`cleanup: true`), Hyprland +
  Noctalia + greeter stack.
- `gaming.yml`: `nonfree: rpmfusion` (`cleanup: true`), NVIDIA driver globs in
  `exclude:`, Steam/gamescope/mangohud/zenity — single-module schema.
- `hardware.yml`: firmware, audio, 32-bit mesa — single-module schema.
- `ublue-pkgs.yml`: COPR `ublue-os/packages` (`cleanup: true`) — bazaar,
  ublue-os-just/luks/selinux-workarounds/signing, ublue-recipes, uupd.
- `terra.yml`: `terra.repo` URL with `no-gpgchecks: true` (`cleanup: true`);
  first block bootstraps `terra-release-*`, second installs the Terra-only
  leftovers (`bazzite-portal`, `scx-*`, `umu-*`, `bibata-cursor-theme`).
- `devtools.yml`: COPR `aahsnr-work/cli-tools` (`cleanup: true`), CLI tools.
- `nix.yml`: `systemd` enable (`var-nix.service`, `nix.mount`) → `dnf install`
  `nix`, `nix-daemon` → `systemd` enable (`nix-daemon`) → `script` `snippets:`
  inline verify gate (banner, `::group::` fold, six guarded checks, `OK`
  line). Units and config arrive via the `files/system/` overlay, not
  `files/systemd/` (no such dirs — the `systemd` module's auto-copy path is
  unused here). `dnf5` aborts a transaction on one bad name, so never add a
  package name without verifying it first (see §6).

## 4. Conventions

- Every yml carries a `yaml-language-server` schema header: `recipe-v1.json`
  for the recipe, `module-v1.json` for a single module, `module-list-v1.json`
  for a `modules:` list. New groups go in `recipes/modules/` and are referenced
  from `recipes/halcyon.yml` via `- from-file: modules/<name>.yml` at the
  correct position (overlay-dependent content after the `files` entries;
  nothing after `bootc-lint` once it exists).
- `dnf install` always sets `install-weak-deps: false`; every dep that used to
  arrive weakly must be listed explicitly. Third-party `repos` always set
  `cleanup: true`. Local `.repo` files live in `files/dnf/` and are referenced
  by filename.
- `script` `scripts:` names files under `files/scripts/` — the file MUST exist
  (validate won't catch a missing one). Prefer `snippets:` for short inline
  gates. Build scripts start `#!/usr/bin/env bash` + `set -euo pipefail`; gates
  print `FAIL …` to stderr and `exit 1`, and every new gate must be proven
  failable (invert once, confirm exit 1).
- Log style: `████ STAGE nn/13 · <name> · … ████` banners, `::group::` /
  `::endgroup::` folds, `OK` / `FAIL` prefixes.
- Executable bits come from git (`chmod +x` before commit); the profile.d hook
  is mode 0755, everything else 0644.
- Nothing new lands in `/var`, `/usr/local`, `/boot`, or `/usr/etc`. Comments
  explain _why_, not _what_.

## 5. Known gaps (not work — status)

- `built-apps.yml`, `ujust-system.yml`, `finish.yml`, `final-verify.yml`,
  `bootc-lint.yml` are referenced by the recipe but unwritten: full-recipe
  `bluebuild validate` fails until they land. When writing them, keep
  initramfs-destined content before finish and `bootc container lint` last.
- `guarded-removals.sh` + `fonts-cleanup.sh` (referenced by `removals.yml`)
  are unwritten: extend-or-write them before any build.
- `files/system/` currently holds only the four nix files; the broader overlay
  is future work. `README.md` is still template text.
- No `Justfile` or CI: verification is the commands in §6, run by hand.

## 6. Commands

```bash
bluebuild validate recipes/halcyon.yml        # schema + from-file resolution
bluebuild validate -a recipes/halcyon.yml     # all errors (expect the §5 gaps)
bluebuild generate -o /tmp/Containerfile.rendered recipes/halcyon.yml  # inspect RUNs
bash -n files/scripts/*.sh                    # syntax check on build scripts
```

`bluebuild` CLI here is 0.9.37. Full image builds go through `bluebuild build`
(not run in this checkout).

## 7. Checklist before proposing a change

- [ ] `bluebuild validate` shows no NEW errors (the §5 gaps are known).
- [ ] New module file uses the right schema header and is listed in
      `recipes/halcyon.yml` in the correct position.
- [ ] New `script` entries name files that exist under `files/scripts/`;
      `bash -n` is clean.
- [ ] New `dnf install` sets `install-weak-deps: false`; third-party repos set
      `cleanup: true`; no added package name is unverified.
- [ ] Every new gate has been inverted once and confirmed to fail.
- [ ] Nothing new lands in `/var`, `/usr/local`, `/boot`, or `/usr/etc`.
- [ ] `_why_` comments are preserved — they are the design docs.
