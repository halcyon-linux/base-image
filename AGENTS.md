# AGENTS.md

Agent instructions for [`halcyon-linux/base-image`](https://github.com/halcyon-linux/base-image). User-facing documentation belongs in `README.md`. Follow the current executable code when documentation is stale; report discrepancies rather than silently changing behavior.

## Project and build

- `Containerfile` builds the `alcyone` Fedora Atomic/bootc image from Universal Blue `base-main`, with OGC kernel akmods, NVIDIA open drivers, and a Hyprland desktop. The current Fedora release is **45**, defined in the `Containerfile`, `.github/workflows/build.yml`, and `Justfile`.
- The default and publication branch is `containerfile`. Its workflow builds, pushes `ghcr.io/halcyon-linux/alcyone`, and signs the resulting image. **Never push to this branch or trigger publication without explicit approval.** Do not create or switch branches unless requested.
- The build inputs are under `build_files/`; files layered into the image are under `system_files/`. `just_scripts/` contains local tooling; `packages.json` currently supplies package sets and external-repository metadata. These are real, active files: do not treat proposed TODO changes as already implemented.
- Read the relevant `Containerfile` stages and scripts before editing. Preserve stage ordering and verify dependencies across installers, configuration, services, and final checks.

## Commands and validation

```bash
just                          # list recipes
just build                    # local image build
just run                      # run the built image
just just-check               # check Justfile and *.just formatting
bash tests/test-dnf5-retry.sh
bash tests/test-audit-lint.sh
```

Run focused checks appropriate to each change, including `bash -n` for modified shell scripts. The audit-lint script checks shell syntax, executable permissions, JSON/YAML, audit rules, and supply-chain constraints. A complete image build additionally requires Podman, Just, Git, registry/network access, and helper tools used by `just_scripts/`. Never claim a test, build, boot, or registry check passed unless it ran successfully.

## Safety and release invariants

1. **Secrets and signing:** Never disclose, commit, or log `GITHUB_TOKEN`, `SIGNING_SECRET`, private signing keys, or key material. Preserve `.gitignore`, `.containerignore`, and `.dockerignore` protection. `cosign.pub` is a public verification key; coordinate any rotation with the signing secret and README instructions.
2. **CI publication:** Preserve the `github.ref == 'refs/heads/containerfile'` conditions on both publish and sign steps, pinned action SHAs, restrictive permissions, secret scoping, and signing compatibility flags. Review workflow changes with the owner before editing.
3. **Pinned inputs:** `just_scripts/verify-upstream-images` verifies the upstream OCI images and produces digest references for the normal local/CI build. Do not bypass failed verification. Keep the kernel and NVIDIA akmods inputs aligned; `just_scripts/resolve-akmods` selects a compatible tag including `nct6687d`.
4. **Downloads and GPG:** New build-time external downloads require a fixed reference and SHA-256 entry in `build_files/downloads/manifest.tsv`; fetch via the `downloads` stage and mount `/downloads` into consuming stages. `GITHUB_TOKEN` may only be mounted in that package-free stage. Verify vendor GPG fingerprints and do not disable GPG checks.
5. **Immutable image conventions:** Install persistent content under `/usr` (and appropriate image-managed locations); use `/etc` for configuration defaults, not mutable runtime state. Do not introduce static content under `/var` that finalization removes. Do not run destructive host operations (`podman system reset`, host `bootc`/`rpm-ostree` deployment commands) as part of code changes.
6. **Repository policy:** Build-only COPRs and vendor repos must be disabled in the finished image. Retain package versionlocks and source requirements where specified by the installers and `verify`.
7. **Initramfs:** Build the initramfs **once**, after NVIDIA driver setup and final relevant configuration, using `build_files/kernel/build-initramfs`. Do not add intermediate dracut invocations.
8. **Fedora upgrades:** Update the Fedora release in the `Containerfile`, workflow, and `Justfile` together. Check matching base/akmods images, COPRs, the vendored Terra GPG key and fingerprint, and verification expectations.

## Change map

| Area                       | Inspect and update together                                                                                                                             |
| -------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------- |
| RPMs and repositories      | `packages.json`, relevant `build_files/packages/` installer, source-repository handling, `build_files/finalization/verify`, consumers and versionlocks  |
| Build stages               | `Containerfile`, required mounts, `verify <stage>`, `build_files/shared/cleanup`; register any new verification stage in both `case` dispatch locations |
| Kernel and NVIDIA          | `just_scripts/resolve-akmods`, `build_files/kernel/`, `build_files/nvidia/`, matching verification stages, final initramfs step                         |
| systemd                    | Units in `system_files/`, `build_files/system/configure-system-services`, verification for enabled/disabled units and runtime dependencies              |
| Desktop and ujust          | `system_files/desktop/`, `system_files/nvidia/`, `build_files/just/`, `configure-desktop-integration`, `verify justfiles`, `just just-check`            |
| Security and auditing      | `system_files/overrides/etc/audit/`, `configure-security-hardening`, `generate-audit-privileged-rules`, `verify`, and `tests/test-audit-lint.sh`        |
| Image metadata and release | `build_files/finalization/image-info`, `.github/workflows/build.yml`, signing files, and `README.md`                                                    |
| Pinned artifacts           | `build_files/downloads/manifest.tsv`, `fetch-pinned`, installation stage, integrity and attribution checks                                              |

`packages.json` currently defines gaming and application package sets. The build currently installs Steam, Lutris, Heroic Games Launcher and related packages; preserve existing behavior unless explicitly tasked with changing it. Keep Mesa handling consistent across architectures and repositories. The explicit package-removal and optimization-preservation requirements belong in the implementation task, not in claims about the current image.

## Verification contract

- The `Containerfile` runs `/ctx/finalization/verify <stage>` after relevant build stages; it also performs `verify final` and `bootc container lint`. Keep stage checks close to the changes they validate.
- Add both positive checks (required packages, binaries, unit states, repository provenance) and negative checks (forbidden packages, units, files, and insecure settings). Never delete an assertion just to make a failing build pass.
- Audit rules reside under `system_files/overrides/etc/audit/rules.d/`. The final static rule file is `99-finalize.rules`; privileged-binary rules are generated after NVIDIA package installation. Audit rules are validated in the build but not activated as host kernel audit policy during the image build.
- Preserve shell strict-mode conventions, executable bits on scripts, non-executable static files, and the existing formatting style. Keep `.containerignore` and `.dockerignore` in sync.

## Agent workflow

1. Inspect the actual affected files and follow their call sites. Do not infer an implementation from comments or pending TODOs.
2. Make minimal, scoped changes; avoid unrelated refactors and do not silently remove established packages, services, security protections, or fallback logic.
3. Update `verify`, tests, and README when behavior or public-facing instructions change. Keep this file focused on durable agent rules rather than duplicating README details.
4. Run applicable static checks and, where feasible, the full image build; report exact commands, outcomes, and anything not tested.
5. Check the diff for secrets and accidental file or permission changes. Do not push, publish, deploy, or modify release/signing policy without explicit approval.
