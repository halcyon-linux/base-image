# AGENTS.md

Operating guide for AI agents and human maintainers of **Halcyon `alcyone`** (`halcyon-linux/base-image`, branch `containerfile`). Read this before changing anything. User-facing documentation lives in [`README.md`](README.md), which is the single documentation source; the former `AUDIT.md`, `TODO.md` and `CHEZMOI.md` were consolidated into it. If you find those files in an older checkout, treat the README as authoritative.

## 1. Project context

| Fact | Value |
| --- | --- |
| What it is | A bootc / Fedora Atomic OCI image, built by one `Containerfile` (target `alcyone`) |
| Published as | `ghcr.io/halcyon-linux/alcyone` with tags `stable`, `latest`, `YYYYMMDD` |
| Base | `ghcr.io/ublue-os/base-main:44` |
| Kernel | OGC kernel from prebuilt `ublue-os/akmods*` images; only `nct6687d` from akmods-extra |
| GPU | NVIDIA **open** modules (`akmods-nvidia-open`) |
| Desktop | SDDM + Hyprland (git) + Noctalia, installed from the `aahsnr-work/base-pkgs` COPR |
| Signing | cosign key; public key `cosign.pub`; private key only in the `SIGNING_SECRET` Actions secret |
| Default and release branch | `containerfile` (pushes build **and publish**) |
| Language mix | Bash, Containerfile, systemd units, config files, `.just` recipes, static assets |
| Tests | No application unit tests. Safety net: `build_files/finalization/verify`, `bootc container lint`, `tests/test-dnf5-retry.sh` |
| Sibling image | `ceyx` (BlueBuild, `bluebuild` branch); not built from this branch |

**When sources disagree, trust in this order:** executable code and `verify` assertions → workflows → `Containerfile` comments → README → everything else. If you find a mismatch, fix the documentation (or flag it) rather than the code, unless the code is demonstrably wrong. Comments and section headers inside scripts can be stale.

## 2. Hard rules (do not violate)

1. **Treat `containerfile` as production.** Never push to it, force-push it, or trigger a publish without explicit human approval. Work on a branch and propose a pull request.
2. **Never handle secrets.** Do not create, print, commit or paste `cosign.key`, `*.key`, `SIGNING_SECRET` or `GITHUB_TOKEN`. Keep `cosign.key` and `*.key` in `.gitignore`, `.containerignore` and `.dockerignore`.
3. **Do not weaken signing or publishing.** Keep the `github.ref == refs/heads/containerfile` guard on **both** the push and the sign steps. Keep actions pinned to full commit SHAs (never version tags). Keep `permissions: {}` at top level with job-level grants only.
4. **Signing flags are a contract.** CI signs with `--new-bundle-format=false --use-signing-config=false`, producing legacy `.sig` signatures. If you change them, update the README verification section in the same change.
5. **Key rotation is atomic.** Replace `cosign.pub`, the `SIGNING_SECRET` secret and the README fingerprint (`openssl pkey -pubin -in cosign.pub -outform DER | sha256sum`) together. The human owner performs the secret change.
6. **Do not hardcode a kernel version.** The kernel comes from `just_scripts/resolve-akmods` (newest tag whose akmods-extra ships `nct6687d`). Do not add other akmods-extra kmods without an explicit decision.
7. **Keep the Fedora release in sync** in three places: `Containerfile` (`FEDORA_VERSION`), `.github/workflows/build.yml` (`FEDORA_VERSION`) and `Justfile` (`latest`). Changing it also affects the akmods tag prefix (`ogc-<fedora>-…`) and the `cicpoffs-fc<N>.rpm` asset name.
8. **Do not reintroduce deliberate removals** without updating `verify` and stating the rationale. Enforced by `verify`: Waydroid, fish, greetd, `zsh-autosuggestions`, `zsh-syntax-highlighting`, `nerd-fonts` (Terra), Steam Deck/handheld packages, `pinentry-qt`, `nvidia-gpu-firmware`, `gamemode`. Intended but **not** enforced by `verify`: `cockpit-ws` and any bundled Flatpak apps (only the Flatpak provisioning machinery and non-Flathub remotes are checked).
9. **Persistent static content belongs under `/usr`.** `/etc` is for defaults only. Nothing static under `/var` (`finalize` strips it).
10. **Do not claim success you did not observe.** Say what you ran and what you could not run. Never state "the build passes" without a build or CI run.
11. **No destructive host operations.** Do not run `bootc`, `rpm-ostree` or `podman system reset`, and do not deploy to a real machine, as part of a code change.
12. **No new external download without a pinning plan** (see §6.6).

## 3. Repository map

| Path | Role | Notes |
| --- | --- | --- |
| `Containerfile` | Orchestrates all stages | Order-sensitive; ends with `bootc container lint` |
| `build_files/finalization/verify` | All build-time assertions (29 groups) | Update with every package, repo, unit or policy change |
| `build_files/finalization/{image-info,finalize}` | Branding, `image-ref`, account relocation, `/var` cleanup | `image-ref` must start with `ostree-image-signed:docker://ghcr.io/` |
| `build_files/kernel/` | Kernel swap, kmod install, initramfs | The `05-rpmostree.install` / `50-dracut.install` shims are temporary |
| `build_files/nvidia/` | NVIDIA config, install, finalize | Runs after the main finalize; initramfs is rebuilt afterwards |
| `build_files/packages/` | One installer per package set, repo setup, TeX Live format baking | Pattern in §6.2 |
| `build_files/system/` | Desktop integration, GRUB, services, repo policy | `configure-system-policy` disables build-only repos |
| `build_files/shared/` | `cleanup`, `dnf5` retry shim, `dnf5-setopt`, `ghcurl` | The `dnf5` shim is build-only and is a sourced function library |
| `build_files/just/` | Imports Bazzite `.just` files into the composed justfile | |
| `just_scripts/` | Local helpers used by `Justfile` | Only `alcyone` (or `containerfile`) is accepted as a target |
| `system_files/desktop/` | Shared payload copied to `/` early | systemd units, sysctl, ujust recipes, polkit, configs |
| `system_files/nvidia/` | NVIDIA-only payload | modprobe, udev, ujust, nvidia services |
| `system_files/overrides/` | Copied **after** packages | Use only for intentional overrides |
| `tests/test-dnf5-retry.sh` | Self-test of the retry shim | Runs in CI |
| `.github/workflows/{build,clean}.yml` | Build/publish/sign; weekly cleanup | Production-impacting |
| `.github/{renovate.json5,pull.yml}` | Dependency and upstream-sync config | |
| `.containerignore`, `.dockerignore` | Build-context exclusions | Keep identical; they exclude `.git`, `.github`, `*.key` |
| `cosign.pub` | Signature verification key | See rules 4–5 |

## 4. Build workflows

### 4.1 Local

```bash
just                  # list recipes
just build            # resolve akmods tag, then podman build → localhost/alcyone-build:44-<branch>
just run              # shell in the built image
just list-images      # localhost/alcyone*-build
just clean-images
just just-check       # formatting check for *.just and Justfile
bash tests/test-dnf5-retry.sh
for f in build_files/*/* just_scripts/* tests/*.sh; do bash -n "$f"; done
```

- Needs `podman`, `just`, `git`, `skopeo`, `jq` and network access. Overrides: `CONTAINER_MGR`, `KERNEL_FLAVOR`, `REQUIRED_KMOD`, `AKMODS_TAG`, `KERNEL_VERSION`.
- Local builds are unsigned and not rechunked. `just build` does not forward `GITHUB_TOKEN`, so `ghcurl` makes unauthenticated GitHub requests and may hit rate limits. A manual `podman build --secret id=GITHUB_TOKEN,env=GITHUB_TOKEN …` forwards it (see README).
- If tools are unavailable in your environment (no podman, no network), say so and limit yourself to static checks: `bash -n`, `shellcheck` if present, and reading the call graph.

### 4.2 CI (`build.yml`)

Triggers: daily 04:40 UTC, push to `containerfile` (except `**.md` and `**.txt`), manual dispatch.
Flow: `just` syntax check → shim test → `resolve-akmods` → `buildah build --target alcyone` → labels → rechunk (`rpm-ostree compose build-chunked-oci --bootc --max-layers 127`) → push `:stable` → copy `:latest` and `:YYYYMMDD` by digest → cosign sign by digest. Timeout 90 minutes.

### 4.3 Cleanup (`clean.yml`)

Sundays 00:15 UTC: remove versions older than 90 days; keep 7 tagged and 7 untagged; delete orphans. Treat changes here as production-impacting.

### 4.4 Docs-only changes

`**.md` and `**.txt` pushes **do not trigger CI**. Never put executable or build-relevant content in `.md` or `.txt` files, and do not rely on CI to validate documentation.

## 5. Build contract (read before editing scripts)

- `build_files/` is bind-mounted at `/ctx`. Scripts are invoked as `/ctx/<dir>/<script>`; they never persist in layers.
- Scripts begin with a strict-mode `set` line (most use `set -Eeuo pipefail`; the kernel and finalization scripts use `set -eoux pipefail`). All tracked scripts are mode `100755`; keep it that way. Static configuration must **not** be executable. Indentation is 4 spaces, no tabs.
- Package-installing `RUN` steps in the `Containerfile` follow this shape:

```dockerfile
RUN --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/packages/<installer> && \
    /ctx/finalization/verify <stage> && \
    /ctx/shared/cleanup
```

- `/ctx/shared/ghcurl` is called by `install-common-packages`, `install-gaming-stack`, `install-system-integration-files` and `install-ujust-picker`. Any `RUN` whose script calls it must mount `--mount=type=secret,id=GITHUB_TOKEN`. The NVIDIA driver step also mounts the secret although its own script does not call `ghcurl`; leave that mount in place.
- Use `dnf5` (the retry shim is first on `PATH` during the build). The shim is deleted before `bootc container lint`; never let it ship.
- Follow the existing install options: `--setopt=install_weak_deps=False --setopt='*.skip_if_unavailable=False'`.
- Order matters: kernel → repos → COPR sets → removals → common/gaming → … → overrides → system config → finalize → NVIDIA → system policy → NVIDIA finalize → image-info/initramfs/finalize again → `verify final` → lint. Do not reorder without tracing dependencies (§8).

## 6. Change playbooks

### 6.1 Add or remove an RPM
1. Add or remove it in the owning script under `build_files/packages/` (choose the set that matches its source repo).
2. Update the matching `verify_*` function: `require_rpms` for additions, `forbid_rpms` for deliberate removals.
3. If a unit, ujust recipe or policy consumes it, trace and update those (§8).
4. Prefer an existing COPR set over adding a repo.

### 6.2 Add a COPR-backed package set
Follow the existing pattern (for example `install-fonts`):
1. A `copr_enabled` flag plus an `EXIT` trap that disables the COPR.
2. `dnf5 -y copr enable`, set `priority=1`, install with `--setopt='*terra*'.priority=10`, then disable.
3. Assert the repo is `disabled` in `dnf5 repo list --all` and `enabled=0` in its `.repo` file, then `rpm -q` every package.
4. Add a `Containerfile` `RUN`, a new `verify` group (register it in **both** the group whitelist `case` at the top and the dispatch `case` at the bottom), and `require_repos_disabled` for the COPR.

### 6.3 Add a vendor repository
Write the `.repo` file inside the installer, install with strict priority and weak deps off, disable immediately, and add the repo id to the `repositories` list in `build_files/system/configure-system-policy` so the shipped image has it disabled. Add `verify` checks.

### 6.4 Add or change a systemd unit
Place it under `system_files/desktop/usr/lib/systemd/{system,user}/` (never `/etc`). Confirm the binary it runs is installed before enablement. Enable it in `build_files/system/configure-system-services` (`system_services`, `global_services` for user units, or `disabled_services`). Assert enablement, and absence of obsolete units, in `verify_services` / `verify_final`. User units meant for human users only follow the existing `ConditionUser=!@system` / `ConditionUser=!sddm` guards.

### 6.5 Add or change a ujust recipe
Put it in an existing `.just` file under `system_files/{desktop,nvidia}/usr/share/ublue-os/just/`, or add a new file and import it from `build_files/just/import-bazzite-justfiles` (NVIDIA recipes are appended by `nvidia/finalize-nvidia`). Check that `yafti.yml` buttons still point at existing recipes. Run `just just-check`.

### 6.6 Add an external download
Use `/ctx/shared/ghcurl`. Prefer a pinned release or commit and a checksum or signature check where upstream publishes one. Record attribution with `setfattr -n user.component` as existing scripts do, and mount `GITHUB_TOKEN` in that `RUN`. Existing mutable downloads (GitHub `latest` releases, winetricks and bash-preexec from `master`, the Distrobox template from `main`) are known debt (audit item A-008); do not add more.

### 6.7 Change the kernel, akmods or NVIDIA path
Touch `just_scripts/resolve-akmods`, `build_files/kernel/*`, `build_files/nvidia/*` and `verify_kernel` / `verify_nvidia*` together. Keep the three akmods images on the same tag, keep the versionlocks, and keep the initramfs rebuilt after NVIDIA installs.

### 6.8 Bump Fedora
Update the three version locations (rule 7). Confirm the base image tag, akmods tags, Terra and COPR availability, and the `cicpoffs` asset name, then do a full local build.

### 6.9 Change CI
Pin any new action to a full SHA with a version comment. Preserve ref guards, `permissions`, concurrency semantics and secret scoping. Never print secrets in logs.

### 6.10 Change `system_files/`
`desktop/` is copied early and `overrides/` late. If a package ships the same path, `overrides/` wins; use it deliberately. Do not add static files under `/var`.

### 6.11 Edit documentation
Update `README.md` when behavior, commands, tags, signing or workflows change, and this file when rules or playbooks change. Keep the verification fingerprint, tag list and workflow triggers accurate.

## 7. Verification (`verify`) rules

- `verify <stage>` runs immediately after the stage it checks; do not defer an assertion to `final` when a stage check fits.
- Positive checks: required RPMs, binaries, enabled units, repo states. Negative checks: forbidden RPMs, forbidden files or units, absent autostart entries.
- A new group must be added to the whitelist `case` near the top **and** the dispatch `case` at the bottom, and called from the `Containerfile` (the `packages` group is the one existing group not invoked there).
- Prefer `fail` over warnings for invariants the image depends on.

## 8. Cross-file dependency map

| Concern | Change together |
| --- | --- |
| Fedora release | `Containerfile`, `build.yml`, `Justfile`, akmods tag prefix, `cicpoffs` asset |
| Kernel identity | `Containerfile` ARGs, `build.yml`, `resolve-akmods`, `install-kernel-akmods`, `verify_kernel` |
| Repositories | `setup-repositories`, `configure-system-policy`, `verify_repos`, installers |
| Package set | Installer script, `verify_*`, any unit, recipe or policy consumer |
| Services | Unit file, `configure-system-services`, `finalize-nvidia`, `verify_services` / `verify_final` |
| ujust recipes | `*.just`, `import-bazzite-justfiles`, `finalize-nvidia`, `yafti.yml`, `verify_justfiles` |
| NVIDIA | `system_files/nvidia/`, `configure-nvidia`, `install-nvidia-driver`, `finalize-nvidia`, `verify_nvidia*` |
| Image identity | `image-info`, workflow labels and tags, `Containerfile` ARGs, README, `verify_image_info` |
| Signing | `build.yml` sign step, `cosign.pub`, README verification section, `SIGNING_SECRET` |
| Flatpak policy | `flathub.flatpakrepo`, `verify` (Flathub-only remotes, no provisioning machinery) |
| chezmoi | `chezmoi-init` / `chezmoi-update` units, `configure-system-services`, `10-halcyon-github.conf`, `verify` HTTPS and `pushInsteadOf` policy, README chezmoi section |

## 9. Pre-merge checklist

- [ ] Work is on a branch; nothing pushed directly to `containerfile`.
- [ ] No secrets, keys or tokens in the diff (review `git diff`; search for `PRIVATE KEY`).
- [ ] `bash -n` passes on every changed script; mode stays `100755` for scripts.
- [ ] `bash tests/test-dnf5-retry.sh` passes if the shim changed.
- [ ] `just just-check` passes if `.just` files or the `Justfile` changed.
- [ ] `Containerfile` `RUN` shape preserved (cache, ctx and tmpfs mounts, `verify`, `cleanup`, `GITHUB_TOKEN` only where needed).
- [ ] `verify` updated for every package, repo, unit or policy change; new groups registered in both `case` blocks.
- [ ] Build-only repositories are still disabled in the shipped image.
- [ ] Docs updated (README and, if rules changed, this file).
- [ ] A full `just build` was run for changes under `Containerfile`, `build_files/` or `system_files/`, or the PR states that it was not.
- [ ] Commit messages use conventional style: `fix(build): …`, `feat(packages): …`, `docs: …`, `fix(system): …`, `fix(ci): …`.

## 10. Troubleshooting

| Symptom | Where to look / what to do |
| --- | --- |
| `resolve-akmods` refuses to build | No published `akmods-extra` tag for the flavor and Fedora release ships `nct6687d`. Do not bypass the check; wait for upstream or make a deliberate decision to change the required kmod |
| dnf metadata or mirror failures | The `dnf5` retry shim covers transient republish windows (6 attempts, 60 s apart). Persistent failure means a real upstream problem |
| GitHub API rate limits in `ghcurl` | Provide `GITHUB_TOKEN` through the secret mount (CI does) |
| A `verify` stage fails | Read the `FAIL:` lines; the failing stage names the step that broke the invariant. Fix the cause; do not delete the assertion without rationale |
| `bootc container lint` fails | Read the lint output. Common suspects: leftover content under `/var`, a leftover dnf5 shim, or a non-conforming layout. Check `finalize` and the shim removal step |
| `just-check` fails | Run `just --unstable --fmt -f <file>` on the offending file (the `just-fix` recipe is private) |
| A docs push did not build | Expected: `.md` and `.txt` are ignored by the workflow |

## 11. Agent behavior

- **Read before writing.** Trace the call graph (§5, §8) for any file you touch.
- **Make minimal diffs** that match existing style: 4-space indentation, trap-based COPR cleanup, `::group::` markers in the kernel scripts, `verify` and `bake-texlive-formats`.
- **Ask before** touching workflows, signing, cleanup, `cosign.pub`, the base image, repository policy or versionlocks.
- **Be explicit about uncertainty.** When you cannot run a build, boot an image or reach a registry, say so and list what remains unverified.
- **Surface drift.** If docs, comments (for example `Containerfile` section headers) and code disagree, report it and fix the documentation in the same change where safe.
- **Do not invent** package names, repo ids, tags or URLs; confirm them in the repo or from a registry.
