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

A build needs `podman`, `just`, `git`, `skopeo`, `jq`, `cosign` and network. Local builds are unsigned and do not forward `GITHUB_TOKEN` (unauthenticated GitHub requests may hit rate limits). If a tool or the network is missing, say so and limit yourself to static checks (`bash -n`, `shellcheck` if present, reading the call graph).

## Hard rules

1. Never push, force-push or trigger a publish on `containerfile` without explicit approval. Work on the existing `containerfile` branch (committing is fine when asked; pushing needs approval).
2. Never create, print, commit or paste `cosign.key`, `*.key`, `SIGNING_SECRET` or `GITHUB_TOKEN`. Keep `*.key` in `.gitignore`, `.containerignore` and `.dockerignore`.
3. Do not weaken signing or publishing: keep the `github.ref == refs/heads/containerfile` guard on **both** the push and sign steps, pin actions to full commit SHAs, keep `permissions: {}` at top level.
4. Signing flags (`--new-bundle-format=false --use-signing-config=false`) are a contract with the README verification section; change them together.
5. Key rotation is atomic: `cosign.pub`, the `SIGNING_SECRET` secret and the README fingerprint change together. The human owner changes the secret.
6. Never hardcode a kernel version. `just_scripts/resolve-akmods` picks the newest tag whose akmods-extra ships `nct6687d`. Add no other akmods-extra kmods without an explicit decision.
7. The Fedora release lives in three places: `Containerfile` (`FEDORA_VERSION`), `.github/workflows/build.yml` (`FEDORA_VERSION`) and `Justfile` (`latest`). It also drives the akmods tag prefix and the Terra key: vendor `build_files/keys/RPM-GPG-KEY-terra<N>` and update its fingerprint in `setup-repositories` and the key id in `verify_repos`.
8. Do not reintroduce deliberate removals without updating `verify` and stating why. Enforced: Waydroid, fish, greetd, `zsh-autosuggestions`, `zsh-syntax-highlighting`, `nerd-fonts` (Terra), Steam Deck/handheld packages, `pinentry-qt`, `nvidia-gpu-firmware`, `gamemode`, `wazuh-agent` (installs only under `/var/ossec`, which `finalize` wipes), `cicpoffs` (unsigned RPM on a rolling release tag), Cockpit (`cockpit-*`, its unit and Quadlet) and the VM host stack (libvirt, QEMU, virt-manager, `edk2-ovmf`, `ls-iommu`, VFIO dracut config). `virtiofsd` is the deliberate exception: it is required for VM/podman machine file sharing, so `verify` requires it while the rest of the stack stays forbidden. Intended but not enforced: bundled Flatpak apps.
9. Persistent static content goes under `/usr`; `/etc` holds defaults only; nothing static under `/var` (`finalize` strips it).
10. Do not claim success you did not observe. Never say "the build passes" without a build or CI run.
11. Do not run `bootc`, `rpm-ostree` or `podman system reset`, and do not deploy to a real machine, as part of a code change.
12. No new external download without a pin: add a row to `build_files/downloads/manifest.tsv` (release tag or commit SHA plus sha256, never `latest`/`master`/`main`), install it from `/downloads` in the installer, and record attribution with `setfattr -n user.component`. Vendor GPG keys are pinned by fingerprint (`gpg_fingerprints` in `packages.json`, `/ctx/shared/check-gpg-fingerprints`); never `--nogpgcheck` or `rpm --import … || true`. `tests/test-audit-lint.sh` enforces these. Remaining mutable downloads (`install-pia`'s changelog scrape, runtime ujust recipes) are known debt (A-008); do not add more.
13. Do not invent branches. Work on `containerfile` (the default and release branch) or a branch the user names; never create or switch to a new branch on your own.

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

- `GITHUB_TOKEN` is mounted **only** in the `downloads` stage (`/ctx/downloads/fetch-pinned`), which installs no packages, so RPM scriptlets and vendor installers can never read it (CI's token has `packages: write`). Stages that install a pinned file add `--mount=type=bind,from=downloads,source=/out,target=/downloads`. `tests/test-audit-lint.sh` fails on a token mount anywhere else.
- Upstream images are consumed by verified digest: `just_scripts/verify-upstream-images` cosign-verifies `base-main`, `akmods*` and `brew` against `build_files/keys/ublue-os.pub` and emits `BASE_IMAGE`, `AKMODS_REF`, `AKMODS_EXTRA_REF`, `AKMODS_NVIDIA_REF`, `BREW_IMAGE`; CI and `just build` pass them as build args. Never bypass a failed verification.
- Stage order matters: kernel → repos → COPR sets → removals → common/gaming → … → overrides → system config → NVIDIA → system policy → NVIDIA finalize → audit privileged rules → image-info/initramfs/finalize (once; dracut runs only here) → `verify final` → lint. Trace dependencies before reordering.

## Where to change what

| Change | Touch together |
| --- | --- |
| Add/remove an RPM | installer in `build_files/packages/` (match the source repo), matching `verify_*` (`require_rpms` / `forbid_rpms`), any unit/recipe/policy that consumes it |
| COPR package set | copy `install-fonts`: `copr_enabled` flag + `EXIT` trap, priority 1, install with `--setopt='*terra*'.priority=10`, disable, assert `disabled` in `dnf5 repo list --all` and `enabled=0` in the `.repo` file; new `Containerfile` `RUN`; new `verify` group registered in **both** the top whitelist `case` and the bottom dispatch `case`; `require_repos_disabled` |
| Vendor repo | `.repo` written inside the installer, disabled immediately, id added to `repositories` in `build_files/system/configure-system-policy`, `verify_repos` |
| systemd unit | unit under `system_files/desktop/usr/lib/systemd/{system,user}/` (never `/etc`), binary installed first, enable in `configure-system-services`, assert in `verify_services` / `verify_final`; human-only user units keep `ConditionUser=!@system` / `!sddm` |
| Audit rules | `system_files/overrides/etc/audit/rules.d/*.rules` (Fedora numbering; one `-D`, `-c` not `-i`, ends `-e 1`), `auditd.conf`, `configure-security-hardening` (deletes stock `audit.rules`, sets 0600/0640), `generate-audit-privileged-rules` (builds `31-privileged.rules` after the NVIDIA stage), `verify_audit_config` / `verify_audit_privileged_rules`, README "Auditing". Use `/usr/bin` paths (sbin is a symlink) and match real files, not symlinks. Rules cannot be loaded at build time: say so |
| `cli-tools` package | only `packages.json` `cli-tools.packages` (all from the `aahsnr-work/cli-tools` COPR; `install-cli-tools` swaps any non-COPR copy; `verify_cli_tools_source` checks `from_repo` in `cli-tools` and `final`). A tool the COPR does not ship goes in `common-packages` |
| ujust recipe | `.just` under `system_files/{desktop,nvidia}/usr/share/ublue-os/just/`, `import-bazzite-justfiles`, `finalize-nvidia` (NVIDIA), `yafti.yml`, `verify_justfiles`; run `just just-check` |
| Kernel / akmods / NVIDIA | `resolve-akmods`, `build_files/kernel/*`, `build_files/nvidia/*`, `verify_kernel` / `verify_nvidia*`; same tag on all three akmods images, keep versionlocks, rebuild initramfs after NVIDIA |
| Bump Fedora | the three locations in rule 7; confirm base tag, akmods tags, Terra/COPR availability, the Terra key (rule 7); full local build |
| Pinned download | `build_files/downloads/manifest.tsv` row, installer reads `/downloads/<dest>`, `bind from=downloads` on its `RUN`, `verify` check; bump with `just bump-downloads` and review the diff |
| Upstream image keys | `build_files/keys/ublue-os.pub`, `just_scripts/verify-upstream-images`, README build-inputs bullet; change only after confirming upstream rotated |
| CI | pin new actions to full SHAs with a version comment; keep ref guards, `permissions`, concurrency and secret scoping; never log secrets |
| `system_files/` | `desktop/` copies early, `overrides/` copies after packages and wins on conflicts; no static files under `/var` |
| Image identity | `image-info`, workflow labels/tags, `Containerfile` ARGs, README, `verify_image_info`; `image-ref` must start with `ostree-image-signed:docker://ghcr.io/` |
| Signing | `build.yml` sign step, `cosign.pub`, README verification section, `SIGNING_SECRET` |
| Flatpak policy | `flathub.flatpakrepo`, `verify` (Flathub-only remotes, no provisioning machinery) |
| chezmoi | `chezmoi-init` / `chezmoi-update` units (opt-in: `ConditionPathExists=%h/.config/halcyon/chezmoi-enable`, set by `ujust dotfiles enable`), `configure-system-services`, `10-halcyon-github.conf`, `verify` HTTPS and `pushInsteadOf` policy, README chezmoi section |

## Troubleshooting

| Symptom | What to do |
| --- | --- |
| `resolve-akmods` refuses to build | No published `akmods-extra` tag for the flavor and Fedora release ships `nct6687d`. Do not bypass; wait for upstream or make a deliberate decision to change the required kmod |
| dnf metadata or mirror failures | The shim retries 6 times, 60 s apart. Persistent failure is a real upstream problem |
| GitHub rate limits in `ghcurl` | Provide `GITHUB_TOKEN` through the secret mount (CI does) |
| `sha256sum` FAILED in `fetch-pinned` | Upstream changed a pinned file. Run `just bump-downloads`, review the upstream change, then update the row; never drop the checksum |
| `verify-upstream-images` fails | An upstream image is unsigned or signed with another key. Do not build from tags; check upstream for a key rotation first |
| `unexpected key` from `check-gpg-fingerprints` | A vendor rotated its repo key. Confirm the new fingerprint from the vendor's docs before updating `packages.json` |
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
- `just_scripts/` accept only `alcyone` (or `containerfile`) as a target; `.containerignore` and `.dockerignore` must stay identical.
- Commit style: `fix(build): …`, `feat(packages): …`, `docs: …`, `fix(system): …`, `fix(ci): …`.

## Pre-merge checklist

- [ ] On `containerfile` (or a branch the user named); nothing pushed without approval.
- [ ] No secrets in `git diff` (search for `PRIVATE KEY`).
- [ ] `bash -n` passes on changed scripts; scripts stay `100755`.
- [ ] `bash tests/test-dnf5-retry.sh` passes if the shim changed; `just just-check` passes if `.just` files or the `Justfile` changed.
- [ ] `Containerfile` `RUN` shape preserved; `GITHUB_TOKEN` mounted only in the `downloads` stage.
- [ ] `verify` updated for every package, repo, unit or policy change; new groups registered in both `case` blocks.
- [ ] Build-only repositories are still disabled in the shipped image.
- [ ] README (and this file, if rules changed) updated.
- [ ] A full `just build` was run for changes under `Containerfile`, `build_files/` or `system_files/`, or the PR says it was not.
