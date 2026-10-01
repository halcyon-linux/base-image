# AGENTS.md — halcyon (base-image)

Guidance for AI coding agents (and humans) working in this repository. This is a
from-scratch BlueBuild project: every claim below was checked against the tree.

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
[fu5ha/winter](https://github.com/fu5ha/winter) (`recipes/modules/nix.yml`:
package set, enable order); file placement follows this repo's
overlay rule, not winter's sidecar dirs.

## 2. Repository layout (actual)

```
recipes/halcyon.yml       # THE build definition. Module order is load-bearing:
                          #   signing → files (system → /) → files (dnf-libdnf5 →
                          #   /etc/dnf) → removals → install-kernel.sh →
                          #   programming → core → gaming → hardware →
                          #   ublue-pkgs → terra → desktop → devtools → nix →
                          #   texlive → apps → ujust → finish → final-verify →
                          #   bootc-lint (bootc-lint must stay last)
recipes/modules/*.yml     # present: apps, core, desktop, devtools, gaming,
                          #   hardware, nix, programming, removals, terra,
                          #   texlive, ublue-pkgs, ujust
files/                    # mounted at /tmp/files in every module RUN; never baked in
  system/                 # static overlay — recipe copies files/system/* → /
                          #   etc/default/useradd (SHELL=zsh)
                          #   etc/greetd/config.toml (launches
                          #     /usr/bin/noctalia-greeter-session)
                          #   etc/pam.d/greetd (gnome-keyring auto-unlock)
                          #   etc/yum.repos.d/fedora-nvidia.repo (staged
                          #     enabled=0 — install-kernel.sh's preflight needs
                          #     the repo id to exist; it enables in-window;
                          #     finalize.sh deletes the file before shipping)
                          #   etc/profile.d/00-path-guard.sh,
                          #     01-nix-resolve-home-env.sh, 02-custom-environment.sh,
                          #     image-path.sh (mode 755; run in that order —
                          #     path guard first, image PATH hook last)
                          #   usr/bin/bazzite-steam{,-bpm,-brand,-firstrun}
                          #     (vendored bazzite Steam wrappers; steam.desktop's
                          #     Exec is rewritten to bazzite-steam/-bpm)
                          #   usr/libexec/bazzite-boot-remount (sourced by the
                          #     kargs recipes in 80-halcyon.just)
                          #   usr/libexec/halcyon-image/{encrypt-repo,git-setup,
                          #     hyprtheme,nuke-nvim} (mode 755; exposed on PATH
                          #     by image-path.sh)
                          #   usr/lib/systemd/system/{var-nix.service,nix.mount}
                          #   usr/lib/systemd/user/pyprland.service (+ .d/
                          #     10-halcyon-condition.conf), chezmoi-init.service,
                          #     chezmoi-update.{service,timer} — their RPMs do
                          #     NOT ship these units, so the overlay does
                          #   usr/lib/tmpfiles.d/{zz-halcyon-nix,
                          #     noctalia-greeter-state}.conf
                          #   usr/share/ublue-os/just/{60-custom.just,*.just} —
                          #     the 10 halcyon ujust modules plus the static
                          #     import list registering them (the ublue-os-just
                          #     RPM ships the justfile's `import?` hook)
  dnf/*.repo              # local .repo files consumed by the dnf module (vendor +
                          #   the scoped COPR repos, see §4)
  dnf-libdnf5/libdnf5.conf.d/99-halcyon-retries.conf  # → /etc/dnf (retries=20)
  scripts/install-kernel.sh    # kernel + NVIDIA userland installer + its gates
  scripts/ujust-system.sh      # Stage 08: ujust gates + steam/lutris wiring +
                               #   ujust/system verify tail
  scripts/guarded-removals.sh  # compose-variance sweep + must-be-gone gates
  scripts/fonts-cleanup.sh     # reverse-dep-gated base font sweep
  scripts/terra-repo-sweep.sh  # deletes the repo files terra-release-* ships
                               #   (repos.cleanup can't remove RPM-owned files)
  scripts/image-info.sh        # writes /usr/share/ublue-os/image-info.json
  scripts/finalize.sh          # third-party repo sweep + end-of-build hygiene
  scripts/final-verify.sh      # Stage 10 no-cache cross-cutting backstop
  scripts/verify-<module>.sh   # per-module gates (12 files, one per dnf
                               #   module; wired as trailing script blocks)
  scripts/lib/cleanup.sh       # end-of-module hygiene; every MUTATING stage
                               #   script ends by calling it (verify scripts
                               #   and final-verify mutate nothing — they don't)

cosign.pub                 # repo-root public key — the bluebuild CLI stages it
                           #   to /etc/pki/containers/halcyon.pub BEFORE any
                           #   module; the `signing` module hard-fails without
                           #   it. CI signs with the SIGNING_SECRET secret.
.containerignore           # keeps .github, docs and .bluebuild-scripts_* out
                           #   of the build context
.github/                   # CI (no Justfile — steps are inlined):
                           #   workflows/build.yml (schedule/push/PR/dispatch;
                           #     PUBLISH_BRANCH=main; ubuntu-24.04; COPR wait
                           #     loop; pinned CLI ghcr.io/blue-build/cli:
                           #     v0.9.37-installer; generate + podman build;
                           #     census; tags; cosign 2.6.5 legacy-format
                           #     sign+verify via SIGNING_SECRET)
                           #   workflows/lint.yml (validate + bash -n +
                           #     shellcheck + repo audit; actionlint 1.7.12)
                           #   workflows/clean.yml (weekly GHCR prune, 90d)
                           #   workflows/semantic-pr.yml (PR-title check)
                           #   renovate.json5 (config:best-practices — digest-
                           #     pins every action; tracks the bluebuild CLI
                           #     pin via a regex customManager; automerges
                           #     pin PRs; leaves the actionlint tag alone)
                           #   log-helpers.sh, CODEOWNERS, PR template
AGENTS.md / README.md (template text) / TODO.md / LICENSE / .gitignore
```

NOT in this repo: `Justfile`, `files/packages.json`, `verify/`, `halcyon.env`,
`files/python-packages/`. Package installs go through the `dnf` module
(never a package catalog — do not reintroduce one); CI steps are inlined in
the workflows (no Justfile).

## 3. Module inventory (what each file actually does)

- `signing` (inline in recipe): image signing setup.
- `files` (inline): `system → /` runs first, so overlay files precede every
  package install. A regular (non-config) file at an RPM-owned path would be
  silently overwritten by the RPM; a `%config(noreplace)` path (greetd,
  `pam.d/greetd`, `default/useradd`) KEEPS the overlaid file and the RPM's
  copy lands as `.rpmnew` — verified 2026-09-30 against `greetd` on
  `fedora-bootc:44`. `dnf-libdnf5 → /etc/dnf` second.
- `removals.yml`: `dnf remove` (GNOME/Steam Deck leftovers, firefox, nano…)
  with `auto-remove: true` → `guarded-removals.sh` (compose-variance
  candidates removed only-if-present, sddm/cage reverse-dep gates,
  must-be-gone hard-fail loop) → `fonts-cleanup.sh` (reverse-dep-gated base
  font sweep; the curated font set installs later in core.yml) →
  `verify-removals.sh`. Keepers are NOT gated here — nothing is installed
  yet this early; `final-verify.sh` owns the keeper set at end state.
- `install-kernel.sh` (inline `script`): Stage 02 banner, `set -euo pipefail`,
  `::group::` folds. Kernel + prebuilt modules from COPR
  `catpieleaf/kernel-p03`; NVIDIA userland from negativo17 (repo id
  `fedora-nvidia`); RPM Fusion disabled for its transactions. Three
  negativo17 subpackages (`nvidia-driver-cuda`, `nvidia-kmod-common`,
  `nvidia-settings`) are payload-extracted file-only via `rpm2cpio` — never add
  them to a `dnf install` line. Installs use `tsflags=noscripts`; depmod runs
  here, dracut is deferred to the finish module.
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
  leftovers (`bazzite-portal`, `scx-*`, `umu-*`, `bibata-cursor-theme`);
  then `terra-repo-sweep.sh` — the `terra-release-*` RPMs ship five enabled
  repo files of their own (`cleanup: true` only removes module-staged files),
  which would otherwise shadow Fedora for every later dnf transaction.
- `devtools.yml`: COPR `aahsnr-work/cli-tools` (`cleanup: true`), CLI tools.
- `nix.yml`: `systemd` enable (`var-nix.service`, `nix.mount`) → `dnf install`
  `nix`, `nix-daemon` → `systemd` enable (`nix-daemon`). Units and config
  arrive via the `files/system/` overlay, not `files/systemd/` (no such
  dirs — the `systemd` module's auto-copy path is unused here). `dnf5`
  aborts a transaction on one bad name, so never add a package name without
  verifying it first (see §6).
- `texlive.yml`: Fedora's own texlive (`install-weak-deps: false`) — the
  `texlive-collection-*` set mirrors the 12 groups the COPR
  `aahsnr-work/texlive-packages` was meant to provide. That COPR is UNUSED
  here by design: its groups are texmf-dist-only data monoliths that cannot
  coexist with Fedora's engines (`texlive-luatex`/`xetex` collide by name,
  and the engines hard-require Fedora component data that file-conflicts
  with the COPR tree) — unusable until the splitter is redesigned.
- `ujust.yml`: `dnf` install of the ujust-fedora companions (`glow`,
  `grubby`, `stress-ng`; `just` self-contained, also in core.yml; `jq` is a
  verify-gate requirement) → `systemd` module (declarative unit state,
  replaces the old script's systemctl/ln logic): `system.enabled` =
  `uupd.timer`, `greetd.service`, `getty@tty2.service`; `system.masked` =
  sddm/gdm/bazzite-autologin/nvidia-persistenced/nvidia-powerd (masking
  needs no unit file); `user.enabled` = pyprland + chezmoi units (`--global`
  → symlinks under `/etc/systemd/user/*.wants/`) → `script`
  `ujust-system.sh` (Stage 08): only what no module covers — the ujust
  presence gates, steam/lutris desktop-entry patching (bazzite parity), and
  the ujust+system verify tail (`ujust --list`, companion-binary sweep, a
  60-custom.just ↔ shipped-recipes completeness gate, gate-checked overlay
  configs), ending with `lib/cleanup.sh`. The 10 modules are registered by
  the static overlay file `60-custom.just` (the `ublue-os-just` RPM ships
  the justfile's `import?` hook for it); `var-nix.service`/`nix.mount`
  remain in nix.yml.
- `finish.yml`: `os-release` module (NAME/`PRETTY_NAME`/HOME_URL →
  /etc/os-release) → `script` `[image-info.sh, finalize.sh]` → `initramfs`
  module LAST. `image-info.sh` writes `/usr/share/ublue-os/image-info.json`
  (bazzite-steam reads it); `finalize.sh` sweeps every third-party repo file
  (incl. the overlay-staged `fedora-nvidia.repo`) and runs the end-of-build
  hygiene. The `initramfs` module regenerates the initrd for every kernel in
  `/usr/lib/modules` (`--no-hostonly --reproducible --add ostree`, 0600).
- `final-verify.yml`: `type: script`, **`no-cache: true`**, `final-verify.sh`
  — the end-state backstop: 12 kernel/NVIDIA gates (incl. the initramfs.img
  the finish module just built and the modinfo-vs-rpm version match), gaming
  keeper set, the only-Fedora-repos-remain gate, identity files
  (os-release/image-info.json/texlive engines), chezmoi wiring, and the
  package census baked to `/usr/share/halcyon/package-count`.
- `bootc-lint.yml`: `type: containerfile`, **`no-cache: true`**, hermetic
  `RUN --mount=type=tmpfs,target=/run --network=none bootc container lint` —
  always the last module.
- Per-module verify scripts (`verify-<module>.sh`, wired as a trailing
  `type: script` block in every module yml): `rpm -q`/binary/config gates
  for that module's payload, `gate()` fail-latcher, `::error::<module>-verify
  failed` + exit 1. Deliberately CACHEABLE — no `no-cache` — because a
  no-cache gate per module would bust every downstream layer on each build;
  `final-verify` + `bootc-lint` are the no-cache backstop. They mutate
  nothing, so they do not call `lib/cleanup.sh`.

## 4. Conventions

- Every yml carries a `yaml-language-server` schema header: `recipe-v1.json`
  for the recipe, `module-v1.json` for a single module, `module-list-v1.json`
  for a `modules:` list. New groups go in `recipes/modules/` and are referenced
  from `recipes/halcyon.yml` via `- from-file: modules/<name>.yml` at the
  correct position (overlay-dependent content after the `files` entries;
  nothing after `bootc-lint` once it exists).
- `dnf install` always sets `install-weak-deps: false`; every dep that used to
  arrive weakly must be listed explicitly. Third-party `repos` always set
  `cleanup: true`, which removes the repo files at the END of the same module
  RUN — so a repos block and the install that consumes it must live in ONE
  dnf module. Local `.repo` files live in `files/dnf/` and are referenced by
  filename; the COPR ones pair `priority=1` with `includepkgs=<curated set>`
  (sources of truth: `~/Git/halcyon/copr`): priority alone would make dnf5
  prefer the COPR for every dependency name it builds, and the allowlist
  confines it to exactly the packages the consuming module installs.
- Declarative first: do with bluebuild modules (`files`, `dnf`, `systemd`)
  whatever a module can express; the `script` module is only for what no
  module covers (verify gates, foreign-file patching like steam.desktop).
  The `systemd` module's `user.enabled` maps to `systemctl --global enable`
  (symlinks under `/etc/systemd/user/<target>.wants/`), `masked` works on
  units that aren't installed, and enabling a missing unit aborts the build.
- `script` `scripts:` names files under `files/scripts/` — the file MUST exist
  (validate won't catch a missing one). Prefer `snippets:` for short inline
  gates. Build scripts start `#!/usr/bin/env bash` + `set -euo pipefail`; gates
  print `FAIL …` to stderr and `exit 1`, and every new gate must be proven
  failable (invert once, confirm exit 1).
- Log style: `████ STAGE nn/13 · <name> · … ████` banners, `::group::` /
  `::endgroup::` folds, `OK` / `FAIL` prefixes.
- Executable bits come from git (`chmod +x` before commit): build scripts
  (`files/scripts/*.sh`, `lib/`), the `usr/bin` + `usr/libexec` wrappers and
  the profile.d hooks are 0755; units, justfiles, configs and tmpfiles are
  0644.
- Nothing new lands in `/var`, `/usr/local`, `/boot`, or `/usr/etc`. Comments
  explain _why_, not _what_.

## 5. Known gaps (not work — status)

- Every module referenced by the recipe exists — `bluebuild validate -a` is
  expected to be CLEAN.
- CI prerequisites (repo side done): the `SIGNING_SECRET` GitHub secret must
  hold the cosign private key matching the repo-root `cosign.pub`, and the
  Renovate GitHub App must be installed on the repo — without the secret the
  publish-gated sign/verify steps fail on the publish branch.
- `files/system/` still misses the wider-overlay extras: wallpaper/plymouth
  theme assets and `etc/issue`/`motd`. `README.md` is still template text.
- Runner is pinned `ubuntu-24.04` with `remove-unwanted-software@v9`;
  `ubuntu-latest` migrates to 26.04 between 2026-10-19 and 2026-11-19 —
  when migrating, switch to `ubuntu-26.04` + `jlumbroso/free-disk-space`
  (v9 is incompatible with 26.04).

## 6. Commands

```bash
bluebuild validate recipes/halcyon.yml        # schema + from-file resolution (must be clean)
bluebuild validate -a recipes/halcyon.yml     # all errors, not just the first
bluebuild generate -o /tmp/Containerfile.rendered recipes/halcyon.yml  # inspect RUNs
bash -n files/scripts/*.sh files/scripts/lib/*.sh   # syntax check on build scripts
shellcheck --shell=bash -x files/scripts/*.sh files/scripts/lib/*.sh
docker run --rm -v "$PWD:/repo" --workdir /repo rhysd/actionlint:1.7.12 -shellcheck= -pyflakes=
```

`bluebuild` CLI here is 0.9.37 (pinned in both workflows; renovate tracks
the pin). Full image builds go through CI (`.github/workflows/build.yml`):
generate + `podman build` locally is possible but NOT run in this checkout —
respect the no-local-build rule.

## 7. Checklist before proposing a change

- [ ] `bluebuild validate` is clean (no known gaps remain).
- [ ] New module file uses the right schema header and is listed in
      `recipes/halcyon.yml` in the correct position.
- [ ] New `script` entries name files that exist under `files/scripts/`;
      `bash -n` and `shellcheck -x` are clean.
- [ ] New install module ships a `verify-<module>.sh` companion wired as a
      trailing script block; every new gate has been inverted once and
      confirmed to fail (no-cache backstop: `final-verify`/`bootc-lint`).
- [ ] New `dnf install` sets `install-weak-deps: false`; third-party repos set
      `cleanup: true`; no added package name is unverified.
- [ ] Nothing new lands in `/var`, `/usr/local`, `/boot`, or `/usr/etc`.
- [ ] Workflow changes: no `ubuntu-latest`, no branch pins on `uses:`, the
      bluebuild CLI pin / cosign 2.6.5 legacy flags / `PUBLISH_BRANCH: main`
      gate stay intact, and `actionlint` passes.
- [ ] `_why_` comments are preserved — they are the design docs.
