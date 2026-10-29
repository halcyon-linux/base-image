# CLAUDE.md

Guidance for Claude Code in **Halcyon `alcyone`** (`halcyon-linux/base-image`). User docs live in [`README.md`](README.md), which is the single documentation source (the former `AUDIT.md`, `TODO.md`, `CHEZMOI.md` and `AGENTS.md` were consolidated into it and this file).

## What this is

A bootc / Fedora Atomic OCI image built by one `Containerfile` (target `alcyone`) on `ghcr.io/ublue-os/base-main:44`. OGC kernel from prebuilt `ublue-os/akmods*` images, NVIDIA open modules, SDDM + Hyprland + Noctalia from the `aahsnr-work/base-pkgs` COPR. Published as `ghcr.io/halcyon-linux/alcyone` (`stable`, `latest`, `YYYYMMDD`) and signed with cosign (`cosign.pub`). Branch `containerfile` is the default and the release branch: pushes to it build **and publish**.

There are no application unit tests. The safety net is `build_files/finalization/verify`, `bootc container lint` and `tests/test-dnf5-retry.sh`.

When sources disagree, trust: executable code and `verify` → workflows → `Containerfile` comments → README → everything else. Fix the docs (or flag the mismatch) rather than the code, unless the code is demonstrably wrong.

## Commands

```bash
just                  # list recipes
just build            # resolve akmods tag, then podman build -> localhost/alcyone-build:44-<branch>
just run              # shell in the built image
just just-check       # format check for *.just and Justfile
bash tests/test-dnf5-retry.sh
for f in build_files/*/* just_scripts/* tests/*.sh; do bash -n "$f"; done
```

A build needs `podman`, `just`, `git`, `skopeo`, `jq` and network. Local builds are unsigned and do not forward `GITHUB_TOKEN` (unauthenticated GitHub requests may hit rate limits). If a tool or the network is missing, say so and limit yourself to static checks (`bash -n`, `shellcheck` if present, reading the call graph).

## Hard rules

1. Never push, force-push or trigger a publish on `containerfile` without explicit approval. Work on a branch and propose a PR.
2. Never create, print, commit or paste `cosign.key`, `*.key`, `SIGNING_SECRET` or `GITHUB_TOKEN`. Keep `*.key` in `.gitignore`, `.containerignore` and `.dockerignore`.
3. Do not weaken signing or publishing: keep the `github.ref == refs/heads/containerfile` guard on **both** the push and sign steps, pin actions to full commit SHAs, keep `permissions: {}` at top level.
4. Signing flags (`--new-bundle-format=false --use-signing-config=false`) are a contract with the README verification section; change them together.
5. Key rotation is atomic: `cosign.pub`, the `SIGNING_SECRET` secret and the README fingerprint change together. The human owner changes the secret.
6. Never hardcode a kernel version. `just_scripts/resolve-akmods` picks the newest tag whose akmods-extra ships `nct6687d`. Add no other akmods-extra kmods without an explicit decision.
7. The Fedora release lives in three places: `Containerfile` (`FEDORA_VERSION`), `.github/workflows/build.yml` (`FEDORA_VERSION`) and `Justfile` (`latest`). It also drives the akmods tag prefix and the `cicpoffs-fc<N>.rpm` asset name.
8. Do not reintroduce deliberate removals without updating `verify` and stating why. Enforced: Waydroid, fish, greetd, `zsh-autosuggestions`, `zsh-syntax-highlighting`, `nerd-fonts` (Terra), Steam Deck/handheld packages, `pinentry-qt`, `nvidia-gpu-firmware`, `gamemode`, `wazuh-agent` (installs only under `/var/ossec`, which `finalize` wipes). Intended but not enforced: `cockpit-ws` and bundled Flatpak apps.
9. Persistent static content goes under `/usr`; `/etc` holds defaults only; nothing static under `/var` (`finalize` strips it).
10. Do not claim success you did not observe. Never say "the build passes" without a build or CI run.
11. Do not run `bootc`, `rpm-ostree` or `podman system reset`, and do not deploy to a real machine, as part of a code change.
12. No new external download without a pinning plan: use `/ctx/shared/ghcurl`, prefer a pinned release or commit plus a checksum or signature, and record attribution with `setfattr -n user.component`. Existing mutable downloads (GitHub `latest`, winetricks and bash-preexec from `master`, Distrobox template from `main`) are known debt (A-008); do not add more.

## Build contract

- `build_files/` is bind-mounted at `/ctx`; scripts run as `/ctx/<dir>/<script>` and never persist in layers.
- Scripts start with a strict `set` line (`set -Eeuo pipefail`; kernel and finalization scripts use `set -eoux pipefail`). Scripts are mode `100755`, static config is **not** executable. 4-space indent, no tabs.
- Use `dnf5` (the retry shim is first on `PATH` during the build and is deleted before `bootc container lint`; it must never ship). Keep `--setopt=install_weak_deps=False --setopt='*.skip_if_unavailable=False'`.
- Package-installing `RUN` steps keep this shape:

```dockerfile
RUN --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/packages/<installer> && \
    /ctx/finalization/verify <stage> && \
    /ctx/shared/cleanup
```

- Any `RUN` whose script calls `ghcurl` (`install-common-packages`, `install-gaming-stack`, `install-system-integration-files`, `install-ujust-picker`) needs `--mount=type=secret,id=GITHUB_TOKEN`. The NVIDIA driver step mounts it too; leave that.
- Stage order matters: kernel → repos → COPR sets → removals → common/gaming → … → overrides → system config → finalize → NVIDIA → system policy → NVIDIA finalize → image-info/initramfs/finalize again → `verify final` → lint. Trace dependencies before reordering.

## Where to change what

| Change | Touch together |
| --- | --- |
| Add/remove an RPM | installer in `build_files/packages/` (match the source repo), matching `verify_*` (`require_rpms` / `forbid_rpms`), any unit/recipe/policy that consumes it |
| COPR package set | copy `install-fonts`: `copr_enabled` flag + `EXIT` trap, priority 1, install with `--setopt='*terra*'.priority=10`, disable, assert `disabled` in `dnf5 repo list --all` and `enabled=0` in the `.repo` file; new `Containerfile` `RUN`; new `verify` group registered in **both** the top whitelist `case` and the bottom dispatch `case`; `require_repos_disabled` |
| Vendor repo | `.repo` written inside the installer, disabled immediately, id added to `repositories` in `build_files/system/configure-system-policy`, `verify_repos` |
| systemd unit | unit under `system_files/desktop/usr/lib/systemd/{system,user}/` (never `/etc`), binary installed first, enable in `configure-system-services`, assert in `verify_services` / `verify_final`; human-only user units keep `ConditionUser=!@system` / `!sddm` |
| ujust recipe | `.just` under `system_files/{desktop,nvidia}/usr/share/ublue-os/just/`, `import-bazzite-justfiles`, `finalize-nvidia` (NVIDIA), `yafti.yml`, `verify_justfiles`; run `just just-check` |
| Kernel / akmods / NVIDIA | `resolve-akmods`, `build_files/kernel/*`, `build_files/nvidia/*`, `verify_kernel` / `verify_nvidia*`; same tag on all three akmods images, keep versionlocks, rebuild initramfs after NVIDIA |
| Bump Fedora | the three locations in rule 7; confirm base tag, akmods tags, Terra/COPR availability, `cicpoffs` asset; full local build |
| CI | pin new actions to full SHAs with a version comment; keep ref guards, `permissions`, concurrency and secret scoping; never log secrets |
| `system_files/` | `desktop/` copies early, `overrides/` copies after packages and wins on conflicts; no static files under `/var` |
| Image identity | `image-info`, workflow labels/tags, `Containerfile` ARGs, README, `verify_image_info`; `image-ref` must start with `ostree-image-signed:docker://ghcr.io/` |
| Signing | `build.yml` sign step, `cosign.pub`, README verification section, `SIGNING_SECRET` |
| Flatpak policy | `flathub.flatpakrepo`, `verify` (Flathub-only remotes, no provisioning machinery) |
| chezmoi | `chezmoi-init` / `chezmoi-update` units, `configure-system-services`, `10-halcyon-github.conf`, `verify` HTTPS and `pushInsteadOf` policy, README chezmoi section |

## Repository map

| Path | Role |
| --- | --- |
| `Containerfile` | Orchestrates all stages; order-sensitive; ends with `bootc container lint` |
| `build_files/finalization/` | `verify` (all build-time assertions, 29 groups), `image-info` (branding, `image-ref`), `finalize` (account relocation, `/var` cleanup) |
| `build_files/kernel/` | Kernel swap, kmod install, initramfs; the `05-rpmostree.install` / `50-dracut.install` shims are temporary |
| `build_files/nvidia/` | NVIDIA config, install, finalize; runs after the main finalize, initramfs rebuilt afterwards |
| `build_files/packages/` | One installer per package set, repo setup, TeX Live format baking |
| `build_files/system/` | Desktop integration, GRUB, services, repo policy (`configure-system-policy` disables build-only repos) |
| `build_files/shared/` | `cleanup`, `dnf5` retry shim (build-only, a sourced function library), `ghcurl` |
| `build_files/just/` | Imports Bazzite `.just` files into the composed justfile |
| `just_scripts/` | Local helpers for the `Justfile`; only `alcyone` (or `containerfile`) is accepted as a target |
| `system_files/desktop/` | Shared payload copied to `/` early: units, sysctl, ujust recipes, polkit, configs |
| `system_files/nvidia/` | NVIDIA-only payload: modprobe, udev, ujust, services |
| `system_files/overrides/` | Copied **after** packages; intentional overrides only |
| `.github/workflows/{build,clean}.yml` | Build/publish/sign; weekly cleanup (production-impacting) |
| `.containerignore`, `.dockerignore` | Build-context exclusions; keep identical (exclude `.git`, `.github`, `*.key`) |

## CI

- `build.yml`: triggers daily 04:40 UTC, push to `containerfile` (except `**.md`, `**.txt`), manual dispatch. Flow: `just` syntax check → shim test → `resolve-akmods` → `buildah build --target alcyone` → labels → rechunk (`rpm-ostree compose build-chunked-oci --bootc --max-layers 127`) → push `:stable` → copy `:latest` and `:YYYYMMDD` by digest → cosign sign by digest. Timeout 90 minutes.
- `clean.yml`: Sundays 00:15 UTC; removes versions older than 90 days, keeps 7 tagged and 7 untagged, deletes orphans.

## Troubleshooting

| Symptom | What to do |
| --- | --- |
| `resolve-akmods` refuses to build | No published `akmods-extra` tag for the flavor and Fedora release ships `nct6687d`. Do not bypass; wait for upstream or make a deliberate decision to change the required kmod |
| dnf metadata or mirror failures | The shim retries 6 times, 60 s apart. Persistent failure is a real upstream problem |
| GitHub API rate limits in `ghcurl` | Provide `GITHUB_TOKEN` through the secret mount (CI does) |
| A `verify` stage fails | Read the `FAIL:` lines; the stage names the broken invariant |
| `bootc container lint` fails | Suspects: leftover content under `/var`, a leftover dnf5 shim, a non-conforming layout. Check `finalize` and the shim removal step |
| `just-check` fails | `just --unstable --fmt -f <file>` on the offending file (`just-fix` is private) |

## Verification (`verify`)

- `verify <stage>` runs right after the stage it checks; do not defer to `final` when a stage check fits.
- Write positive checks (RPMs, binaries, enabled units, repo states) and negative checks (forbidden RPMs, files, units, autostart entries). Prefer `fail` over warnings for invariants the image depends on.
- Read `packages.json` lists through `load_packages` (`require_rpms_from_json` / `forbid_rpms_from_json`). It fails on a missing or empty list; the old dotted jq path silently returned nothing for hyphenated sections such as `cli-tools`, so those checks never ran.
- Every new group goes in both `case` blocks and is called from the `Containerfile` (`packages` is the one group not invoked there).
- If a `FAIL:` line appears, fix the cause. Do not delete the assertion without a stated reason.

## Working agreements

- Read before writing. Trace the call graph for any file you touch.
- Keep diffs minimal and in the existing style (trap-based COPR cleanup, `::group::` markers in kernel scripts).
- Ask before touching workflows, signing, cleanup, `cosign.pub`, the base image, repository policy or versionlocks.
- Say what you ran and what you could not run (build, boot, registry access).
- Surface drift between docs, comments and code; fix the docs in the same change where safe.
- Do not invent package names, repo ids, tags or URLs; confirm them in the repo or from a registry.
- `**.md` and `**.txt` pushes do not trigger CI. Never put executable or build-relevant content in them.
- Commit style: `fix(build): …`, `feat(packages): …`, `docs: …`, `fix(system): …`, `fix(ci): …`.

## Pre-merge checklist

- [ ] On a branch; nothing pushed to `containerfile`.
- [ ] No secrets in `git diff` (search for `PRIVATE KEY`).
- [ ] `bash -n` passes on changed scripts; scripts stay `100755`.
- [ ] `bash tests/test-dnf5-retry.sh` passes if the shim changed; `just just-check` passes if `.just` files or the `Justfile` changed.
- [ ] `Containerfile` `RUN` shape preserved; `GITHUB_TOKEN` mounted only where needed.
- [ ] `verify` updated for every package, repo, unit or policy change; new groups registered in both `case` blocks.
- [ ] Build-only repositories are still disabled in the shipped image.
- [ ] README (and this file, if rules changed) updated.
- [ ] A full `just build` was run for changes under `Containerfile`, `build_files/` or `system_files/`, or the PR says it was not.
