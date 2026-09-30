# AGENTS.md — halcyon

Guidance for AI coding agents (and humans) working in this repository.

- Branch of record / publish branch: `container` (`build.yml` publishes only
  from `PUBLISH_BRANCH`).
- `testing` (local-only, do not push): the migration branch consuming the six
  `aahsnr-work/halcyon*` Copr projects. It ships only when those repos are
  proven — see §9.

Task playbooks live in §8 (absorbed from the former SKILLS.md).

---

## 1. What this repo is

`halcyon` builds a **single bootc OCI image**: a lean Hyprland gaming desktop on
`quay.io/fedora/fedora-bootc:44` (recipe `image-version`, mirrored by
`halcyon.env`), with the `catpieleaf/kernel-p03` kernel, prebuilt
`nvidia-open` modules, negativo17 NVIDIA userland, the noctalia greeter on
greetd, and `ujust`/`uupd` for user-facing system tasks.

It is a **BlueBuild project** (converted 2026-09-30): the build is driven by
`recipes/recipe.yml` through the pinned `bluebuild` CLI, which renders a
Containerfile at build time and builds it with podman. The repo keeps some
bazzite heritage — per-RUN cache mounts (the bluebuild template mounts the
package-manager caches for every module), the `/opt` optfix pattern in
bluebuild's `pre_build`/`post_build`, the `ujust`/`uupd` user tooling and
vendored Steam wrappers — but the base is plain `fedora-bootc` and the base
image is **digest-pinned at generate time** (`bluebuild generate` resolves
`image-version: 44` to a digest, so every build is reproducible yet tracks the
release tag each run).

Deliberate deviations from the default bluebuild shape:

- **Per-module verification gates** (bazzite-adjacent, bluebuild lacks them):
  stage scripts end with terse fail-fast gates or `gate()` verify sections;
  `final-verify` is the end-state backstop; `bootc container lint` runs as the
  last module under the hermetic flags. Both gate modules set `no-cache: true`
  so a cached layer can never skip them.
- **`blue-build-tag`/`cosign-version`/`nushell-version` are `none`**: the
  bluebuild CLI, cosign and nushell are NOT baked into the shipped image
  (halcyon signs in CI with its own pinned cosign and ships its own ujust
  tooling). The nushell runtime is still mounted at build time by the
  template.
- **Package lists stay in `files/packages.json`** — a single source of truth
  for every dnf package — instead of bluebuild's `dnf` module, because the
  halcyon repos need `priority=1` arbitration, weak deps are off and Terra is
  exclusive. `just check` proves catalog/recipe/CI consistency.

**Package sources**: the six `aahsnr-work/halcyon*` Copr projects (the
halcyon-packages monorepo) are the primary source — five group repos
(`halcyon` desktop core, `-cli`, `-apps`, `-fonts`, `-texlive`) are
copr-enabled with priority=1 in the repos module (`dnf5 copr enable` +
`config-manager setopt …priority=1`), so every monorepo-built package outranks
Fedora and Terra. The kernel stays on `catpieleaf/kernel-p03`;
`ublue-os/packages`, vscode/brave, RPM Fusion and negativo17 remain for what
the monorepo does not (yet) build. Homebrew, the flatpak transition and the
AppImage/tarball/CTAN install scripts were retired (2026-09-29) — everything
they delivered is an RPM now.

---

## 2. Repository layout

```
recipes/recipe.yml          # THE build definition: base image + labels + module list.
                            #   Module ORDER is load-bearing (old stage order 00–11).
modules/<name>.yml          # one config file per build stage (script or containerfile
                            #   module); the recipe references them with from-file
files/                      # build config root — mounted at /tmp/files in EVERY module
                            #   RUN (bluebuild stage-files); never baked into the image
  packages.json             # single source of truth for every dnf package (+ _docs
                            #   provenance) — the canonical copy lives here
  cosign.pub                # repo key copy — image-info cmp-gates it against the key
                            #   the bluebuild stage-keys RUN baked into the image
  system/                   # static overlay (COPY files/system /) — units, configs,
                            #   ujust modules, theme, wallpaper
  scripts/                  # stage + keeper scripts (bluebuild requires .sh)
    lib/packages-lib        # jq accessors the keeper scripts source
    lib/cleanup.sh          # end-of-module hygiene (was build_files/cleanup)
    python-packages/        # 11 stdlib-only src-layout Python tools
Justfile                    # check / lint / lint-python / test-python / check-github /
                            #   build / verify-image / generate-build-tags / …
halcyon.env                 # dotenv consumed by the Justfile (FEDORA_VERSION, IMAGE_NAME, …)
cosign.pub                  # public signing key — repo root copy for bluebuild's
                            #   stage-keys RUN (baked to /etc/pki/containers/halcyon.pub)
.containerignore            # keeps docs/notes/verify/.github AND .bluebuild-scripts_*
                            #   (the CLI runtime, bound from host, never in the tar) out
                            #   of the build context
README.md                   # user-facing readme
TODO.md                     # task checklist
verify/                     # image-side suites (chezmoi/ujust) + host-side .github audit
.github/                    # build / lint / clean / semantic-pr workflows + dependabot/renovate
```

Generated artifacts (never committed): `.bluebuild-scripts_*` (CLI runtime,
created by `bluebuild generate` in the repo root) and any Containerfile
rendered with `bluebuild generate -o` for inspection.

---

## 3. Commands

```bash
just check          # just --fmt --check, bluebuild validate (recipe schema), module-script
                    #   existence, bash -n over files/scripts, packages.json validity +
                    #   group-consumer consistency, Fedora-version triple consistency
                    #   (recipe ↔ halcyon.env ↔ build.yml URLS), cosign key identity,
                    #   ujust import list vs shipped modules, recipe-body bash -n
just lint           # shellcheck --shell=bash -x over every files/scripts/*.sh
just lint-python    # ruff (E9 + F821/F822/F823) over files/python-packages
just test-python    # pytest suites for the python helpers that have them
just check-github   # host-side .github audit (verify/verify-github.sh)
just build          # bluebuild generate + podman build (mirrors the CLI's own podman
                    #   driver, tagged under the CI scheme)
just verify-image   # run verify/verify-{chezmoi,ujust}.sh inside the built image
just package-count  # run the built image, report RPM count + kernel version
```

**Always run `just check` and `just lint` before proposing a change to anything
under `files/scripts/`, `modules/` or `recipes/`.** A missing `fi` costs a full
~40-minute CI build; a missing group costs the base-packages transaction.

---

## 4. Build architecture — rules that must not be broken

1. **Module order is load-bearing (recipe modules 00–11, banners `nn/13`).**
   The recipe module list replaces the old 12-RUN Containerfile order 1:1:
   static overlay `copy` → repos (00) → remove-packages (01) →
   kernel-nvidia (02) → base-packages (03) → terra (04) → devtools (05) →
   nix (06) → built-apps (07) → ujust-system (08) → finish (09) →
   final-verify (10) → bootc-lint (11). The initramfs is built _last_ (finish);
   `bootc container lint` is the last module. bluebuild's `post_build.sh` runs
   after ALL modules (its `/tmp` + `/var` wipe, optfix tmpfiles and
   rpm-ostree-base-db relink are the very last layers).

2. **Every mutating module script ends with `/tmp/files/scripts/lib/cleanup.sh`**
   — the exceptions are finish (whose `finalize.sh` IS the hygiene sweep,
   bazzite final-RUN pattern), final-verify and bootc-lint (mutate nothing).
   bluebuild's `post_build` wipes `/tmp` and `/var` after them, so build-time
   state never ships.

3. **`--setopt=install_weak_deps=False` on every `dnf5 install`.** Anything
   that used to arrive as a weak dep must be listed explicitly (`hyprland-guiutils`,
   `xdg-desktop-portal-{hyprland,gtk}`, `qt6ct`, `nwg-look`, `kitty-terminfo`).

4. **Third-party repo lifecycle: stage → consume → sweep.** The halcyon group
   repos are the exception to enable→disable-per-module: they are copr-enabled
   once in the repos module with `setopt priority=1` (the bazzite/bluebuild
   pattern — the copr plugin does not set priorities) and used by every later
   module, then `finalize.sh` deletes the generated `_copr:*` + `halcyon*.repo`
   files. Every other third-party repo (catpieleaf, ublue, vscode, brave, terra,
   negativo17, rpmfusion) is enabled → consumed → disabled inside one module.
   `final-verify` asserts that **only Fedora repo files remain** — the shipped
   image carries no third-party repo files (updates arrive via image rebuilds;
   bootc). The bluebuild `dnf` module is deliberately NOT used for halcyon
   groups: it cannot express priority arbitration, weak-deps-off or exclusive
   Terra windows.

5. **NVIDIA comes from negativo17 only** (RPM Fusion's nvidia chain is
   excludepkgs'd in the repos module). Four negativo17 subpackages are
   dependency-entangled with a kmod package and are **payload-extracted via
   `rpm2cpio`** by `install-kernel.sh`, not installed — do not "fix" that by
   adding them to a `dnf5 install` line (it pulls `dkms-nvidia`, which
   `Conflicts` with `kernel-p03-nvidia-open`).

6. **Kernel and NVIDIA RPMs install with `--setopt=tsflags=noscripts`**;
   `depmod` and `dracut` run explicitly (`install-kernel.sh`, then
   `build-initramfs.sh` in the finish module).

7. **Per-module verification, three layers.** (a) Stage scripts end with terse
   fail-fast gates (see §8 add-verify-gate); (b) keeper scripts carry `gate()`
   verify sections; (c) `final-verify.sh` is the authoritative end-state
   backstop (kernel/NVIDIA version match, repo sweep, gaming keepers, census)
   and `bootc container lint` the hermetic final gate — **both modules set
   `no-cache: true`** so layer caching can never skip them.

8. **This is bootc, not rpm-ostree.** Kernel args via `grubby`; cmdline from
   `/proc/cmdline`; `bootc status` replaces `rpm-ostree status`
   (`halcyon-rebase.just` keeps a `command -v rpm-ostree` fallback for
   non-bootc hosts — deliberate, do not copy it to new recipes).

9. **A package a recipe shells out to must be in `files/packages.json`.**
   `gum` is absent (`ugum` falls back to fzf), but `grubby`, `ethtool`, `wget`
   (`wget2-wget`), `hostname`, `fpaste`, `wl-copy`, `zenity`, `jq` are hard
   requirements gated by the ujust-system module's verify section.

10. **Image signatures use the legacy sigstore format.** `build.yml` signs with
    `--new-bundle-format=false --use-signing-config=false
    --registry-referrers-mode=legacy` and verifies with
    `--new-bundle-format=false`; bluebuild's stage-keys RUN bakes the
    repo-root `cosign.pub` to `/etc/pki/containers/halcyon.pub` before any
    module, and `image-info.sh` **cmp-gates** that baked key against
    `files/cosign.pub`; `image-info.sh` writes `registries.d/halcyon.yaml` +
    `policy.json` (`signedIdentity: matchRepository`). Never remove any of
    these — `verify-github.sh` gates them.

11. **The bluebuild CLI is pinned.** CI installs `v0.9.37` from
    `ghcr.io/blue-build/cli:v0.9.37-installer` (never the moving install
    script); `verify-github.sh` asserts the pin. Build-time pulls: the base
    image (digest-pinned by generate), `ghcr.io/blue-build/modules/script:latest`
    (per script module), and `ghcr.io/blue-build/nushell-image:default` (the
    template's module runtime). Those `:latest`/`:default` tags are
    upstream-managed — update the digest-pin + module contract together when
    bumping the CLI.

---

## 5. Package sourcing

Resolution is `priority=1` arbitration: **a package whose name exists in a
halcyon group repo resolves from there**, period. Adding a package therefore
means two questions — which module installs it, and does its halcyon build exist?

| Source | Where in `files/packages.json` | Module |
| --- | --- | --- |
| COPR `aahsnr-work/halcyon` (desktop core) | `desktop` (+ `adw-gtk3` in `core`) | base-packages (03) |
| COPR `aahsnr-work/halcyon-cli` | `cli-tools`/`devtools`/`misc` | devtools (05) |
| COPR `aahsnr-work/halcyon-apps` | `halcyon-apps` + `editors` (`emacs-pgtk`) | built-apps (07) / base-packages |
| COPR `aahsnr-work/halcyon-fonts` | `core` (font names) | base-packages (03) |
| COPR `aahsnr-work/halcyon-texlive` | `halcyon-texlive` (`texlive-meta`) | built-apps (07) |
| COPR `catpieleaf/kernel-p03` | (repos module) | kernel-nvidia (02) |
| COPR `ublue-os/packages` | `ublueos-packages` | base-packages (03) |
| Terra (leftovers only) | `terra` | terra (04, exclusive) |
| Fedora | `programming`/`core`/`hardware`/`editors`/`cli-tools`/`gaming`/`ujust-fedora` | 03/05/06/08 |
| Vendor (vscode, brave) | `vendor-apps` | base-packages (03) |

**Name mapping gotchas** (monorepo name ≠ Fedora/Terra name): `hyprland-git`,
`noctalia-git`, `adw-gtk3`, `jetbrains-mono-fonts-all`, `nerd-fonts-jetbrainsmono`,
`nerd-fonts-symbols-only`, `lazygit`, `dust` (Fedora: `du-dust`), `pandoc`
(Fedora: `pandoc-cli`). `google-noto-emoji-fonts` and `scx-*`/`umu-*`/
`bazzite-portal`/`bibata-cursor-theme` are NOT in the monorepo — Fedora/Terra.

Provenance for every package is recorded in the group's `_docs` entry in
`files/packages.json` (plain JSON — no inline comments; jq rejects them).
`packages.md` was retired: `_docs` + this file are the documentation.

If a NEW Copr joins the build: add it to the repos module's `copr enable` +
`setopt priority` loop (or a copr enable/disable window in the consuming
module), add its `repomd.xml` URL to `build.yml`'s `URLS` wait array, and add
the monitor entry to `verify-github.sh` — all three or the build goes red
randomly.

---

## 6. bootc / image constraints

- `/var` must be effectively empty in the image — bluebuild's `post_build.sh`
  enforces the wipe (`rm -rf /tmp/* /var/*`); runtime state via `tmpfiles.d`
  (`zz-halcyon-*.conf`) or a oneshot unit (`var-nix.service`).
- **Never create `/usr/etc`.** The cosign key lives at
  `/etc/pki/containers/halcyon.pub` (baked by bluebuild's stage-keys RUN,
  cmp-gated by `image-info.sh`).
- `/var/run` stays a symlink to `/run` — hard lint failure.
- `/boot` empty; kernel + initramfs live in `/usr/lib/modules/<kver>/`.
- No `/usr/local` writes; use `/usr/lib/<app>` + `/usr/bin` symlink.
- `pre_build.sh` relocates `/opt` → `/usr/lib/opt` (bluebuild optfix):
  packages that install into `/opt` (Brave) write through the symlink into
  `/usr/lib/opt`, and `post_build.sh` emits `99-bluebuild-optfix-*.conf`
  tmpfiles relinking at boot. Do not gate `/opt` as empty.
- The final `bootc container lint` module runs with tmpfs `/run` and
  `--network=none`, **without** `--fatal-warnings` (var-tmpfiles/sysusers
  warnings pass today).

---

## 7. Conventions by file type

### Module scripts (`files/scripts/*.sh`) and module configs (`modules/*.yml`)

- One script per stage (named after the module), plus the keeper set:
  `remove-packages.sh`, `install-kernel.sh`, `install-built-apps.sh`,
  `image-info.sh`, `build-initramfs.sh`, `finalize.sh`, `final-verify.sh`,
  `cleanup.sh` (lib), `packages-lib` (lib). The recipe's module list is the
  single source of ordering truth.
- `#!/usr/bin/env bash` + `set -euo pipefail` (`set -uo pipefail` only when
  the script deliberately accumulates failures and returns its own `rc`).
- Every script carries the stage banner (`████ STAGE nn/13 · … ████`),
  `echo "::group::…"` / `::endgroup::` folds, and `  OK  ` / `  FAIL  ` /
  `  INFO  ` prefixes. Keeper scripts end with their verify section
  (`fail=0; gate() {…}`) that exits 1 with `::error::<module>-verify failed`.
- Package lists live in `files/packages.json`, never inline; one package per
  line. Scripts resolve groups with `jq -r '.all.include.<group>[]'` into a
  `readarray` (SC2046-clean); keeper scripts source
  `files/scripts/lib/packages-lib` (`PACKAGES_JSON` defaults to
  `/tmp/files/packages.json`).
- Scripts run with `PWD=/tmp/files/scripts` and the whole `files/` dir mounted
  read-write at `/tmp/files` (bluebuild stage-files; the content is NEVER in
  the final image). Scripts may use quoted heredocs (REPO/YAML/POLICY/etc.) —
  the old no-Containerfile-heredocs rule died with the Containerfile.
- `# shellcheck source=files/scripts/lib/packages-lib` — resolved relative to
  ShellCheck's working directory (repo root). Host paths exist for every
  in-image path the linter follows; runtime paths use `/tmp/files/…`.
- The `files/` dir is read-only by convention during the build (scripts copy
  out what they must mutate, e.g. `install-built-apps.sh` →
  `/usr/src/python-packages`).

### Module configs (`modules/<name>.yml` + `recipes/recipe.yml`)

- `type: script` + `scripts: [<file>.sh]`; `no-cache: true` on anything that
  is a gate and must never be skipped by layer caching.
- `type: containerfile` for raw RUNs that must survive verbatim (bootc-lint).
- Recipe labels are STATIC values; dynamic identity (version/date) labels are
  no longer set (the CLI emits created/base.digest/base.name/build-id).
- Every new module must be listed in `recipes/recipe.yml` via
  `- from-file: ../modules/<name>.yml` AND its scripts referenced from
  `files/scripts/`; `just check` validates both.

### Static overlay (`files/system/**`)

- COPY'd before any package install — an RPM owning the same path silently
  overwrites your file. Prefix drop-ins `zz-halcyon-<topic>.conf`; use
  `.d/10-halcyon-*.conf` drop-ins over replacing units you do not own; gate
  final content, not existence. Executable bits come from git
  (`git update-index --chmod=+x`) + a `test -x` gate.
- `profile.d` ordering: `00-path-guard.sh` → `01-nix-resolve-home-env.sh` →
  `02-custom-environment.sh` → `image-path.sh`. `00-path-guard.sh` uses only
  builtins on purpose. Default login shell is **zsh**.
- `pyprland.service` + its `pyprland.service.d/10-halcyon-condition.conf`
  drop-in ship here because the monorepo RPM deliberately does not ship the
  unit (the AUR doesn't either).

### ujust recipes

- `# vim: set ft=make :`, doc comment, `[group("…")]`; register new module
  files in the `for f in …` import loop in `files/scripts/ujust-system.sh`
  (else shipped but never imported); interactive recipes
  `source /usr/lib/ujust/ujust.sh` + `Choose`; `just check` runs `bash -n`
  over every recipe body and proves the import list matches the shipped
  modules.

### Python packages

Stdlib only, one shared venv at `/usr/lib/halcyon-python`. Register in THREE
places: `EXPECTED` in `install-built-apps.sh`'s `install_python_packages()`,
`files/python-packages/README.md`, the helper loop in the built-apps-verify
section of the same file. The `-h` smoke test never reaches the
working code — `just lint-python` (ruff F821) and `just test-python` exist for
that (a missing import once shipped in `rmi`).

---

## 8. Task playbooks (former SKILLS.md, condensed)

### verify-package-availability — before adding ANY package name

`dnf5` aborts the whole transaction on one unresolvable argument. Never guess
from upstream's README (`dust`/`du-dust`, `fd`/`fd-find`, `wget`/`wget2-wget`,
Terra's `golang-github-jesseduffield-lazygit`):

```bash
podman run --rm quay.io/fedora/fedora-bootc:44 bash -lc '
  dnf5 -y install dnf5-plugins >/dev/null 2>&1
  dnf5 repoquery --qf "%{name}-%{version} [%{reponame}]\n" <pkg>          # Fedora
  dnf5 repoquery --disablerepo="*" --enablerepo="terra*" \
    --repofrompath "terra,https://repos.fyralabs.com/terra44" --nogpgcheck \
    --qf "%{name} [%{reponame}]\n" <pkg>                                   # Terra-only
  dnf5 -y copr enable aahsnr-work/halcyon-apps && \
  dnf5 repoquery --qf "%{name} [%{reponame}]\n" <pkg>                      # a halcyon repo'
dnf5 repoquery --whatprovides /usr/bin/<binary>   # find the real name
```

Record name + repo in the group's `_docs` entry. A package sourced from one
repo must not fall back to another (Terra is enforced exclusive by design).
Optional installs get `|| true` AND no hard gate. The terra/devtools groups
verify via the `rpm -q` loops in their scripts + `final-verify` keepers — no
companion scripts.

### add-build-module (was: add-build-stage)

1. Write `files/scripts/<name>.sh` (skeleton = `remove-packages.sh` or the
   de-chained base-packages style): banner `████ STAGE nn/13 · <name> · … ████`,
   `set -euo pipefail`, groups, gates, ending in
   `/tmp/files/scripts/lib/cleanup.sh` for mutating modules.
2. Write `modules/<name>.yml` (`type: script`, `scripts: [<name>.sh]`;
   `no-cache: true` if it is a gate). For verbatim RUNs use `type:
   containerfile` + `snippets:`.
3. Add `- from-file: ../modules/<name>.yml` to `recipes/recipe.yml` at the
   right position — initramfs-destined content before the finish module; repo
   consumers before it too; tooling-dependent modules after base-packages;
   nothing after bootc-lint.
4. `just check`/`just lint` pick the new files up automatically (both walk
   `files/scripts`; the group grep scans scripts; validate resolves the new
   module).

### add-rpm-package

Run verify-package-availability, place by source repo (table in §5), one
package per line, `--setopt=install_weak_deps=False`, add/extend the verify
gate (or `final-verify` for identity-defining packages). Check
`all.exclude.all` for a remove/reinstall pair (`fastfetch` is one — say why in
a comment). New COPR to the build → repos loop + `URLS` array +
`verify-github.sh` monitor (see §5). Verify: `just check && just lint`, then
`podman run --rm --entrypoint /bin/bash localhost/halcyon:latest -c 'rpm -q <pkg>'`.

### add-verify-gate

Two forms, both **proven failable** (invert once, confirm exit 1):

- Script tail form: appended to the stage script — `rpm -q <names>` (fails on
  the first missing package), `test -x …`, `grep -qF …`, a
  `for b in …; do command -v "$b" >/dev/null 2>&1 || exit 1; done` loop.
  Keep tails terse; `final-verify` is the backstop.
- Keeper-script form: `fail=0; gate() { local desc="$1"; shift; if "$@" >/dev/null 2>&1; then echo "  PASS  $desc"; else echo "  FAIL  $desc"; fail=1; fi; }`
  … `gate "desc" command args` (a command, not a shell string); negatives as
  `sh -c '! …'`.

**Gates that must run on EVERY build go in `final-verify.sh` or
`bootc-lint.yml` — both are `no-cache: true`.** Cached layers skip ordinary
module scripts.

Wrong in this environment: `test -e /usr/lib/systemd/system/<target>.wants/<unit>`
(use `systemctl is-enabled` / `test -L` on `/etc/systemd/user/*.wants/`), a
gate whose glob a later module deletes, `test "${VAR}" = "$(...)"` with a
possibly-empty VAR, gating "directory X is empty" without checking writers
(Brave → `/opt`, relocated by optfix), greps over shipped recipe prose, hard
gates on `|| true` installs, bare `grep -rq` over a possibly-missing directory.

### ship-systemd-unit

System unit → `files/system/usr/lib/systemd/system/` + `systemctl enable` in
`ujust-system.sh`; user unit → `…/user/` + explicit symlink into
`/etc/systemd/user/default.target.wants/`; masks → `ln -sf /dev/null
/etc/systemd/system/<u>`; patch a foreign unit via `.d/10-halcyon-*.conf`
drop-in, created **unconditionally**; runtime state under `/var` via
`tmpfiles.d`. Gates: `systemctl is-enabled` (system), `test -L` (user
symlinks). `ConditionEnvironment=` on a user unit reads the user manager's env
— the session must `dbus-update-activation-environment --systemd
XDG_CURRENT_DESKTOP` or pyprland silently never starts. First-login units use
`ConditionPathExists=!%h/…` + stamp-file (`chezmoi-init.service`).
`tsflags=noscripts` installs must self-enable what their `%post` would have.

### add-ujust-recipe

Module under `files/system/usr/share/ublue-os/just/`, registered in the
`ujust-system.sh` import loop; interactive recipes
`source /usr/lib/ujust/ujust.sh` + `Choose`; expose a machine-readable
`status` action. De-Bazzite vendored recipes: `rpm-ostree` → grubby/bootc
(keep `halcyon-rebase.just`'s fallback), `/usr/libexec/bazzite-boot-remount`
is vendored, `ugum` → `Choose` or fzf. Gate every binary the recipe shells
out to in the ujust-system verify section.

### add-python-tool

src-layout under `files/python-packages/<name>/` (copy `fe/`), **stdlib only**
(one shared venv, no dependency safety net; runtime tools come from the RPM
layer and are checked via `shutil.which` at startup), house conventions
(argparse exits 1, `exit_status(128-rc)`, `sys.exit(130)` on
KeyboardInterrupt), register in the THREE places (§7 Python packages), and add
a pytest suite for anything with side effects. `just check`/`just lint`
exclude python-packages by design — use `just lint-python` / `just test-python`.

### software with no RPM

Package it in the halcyon-packages monorepo first — that is now the first
resort, not a build script (`zen-browser`, `zed`, `obsidian`, `zotero` are the
precedents; the monorepo's `add-upstream-binary-app` rules apply: digest
verification, `/usr/lib/<app>` + `/usr/bin` symlink, `DisableAppUpdate`
policy, no metainfo unless wanted). A module install script is the last resort
for anything the monorepo genuinely cannot build.

### remove-package-or-file

Removals run FIRST (remove-packages module, near-pristine base) — do not move
them later. Add to `all.exclude.all` (resolved through `rpm -qa`, absent names
tolerated); use the reverse-dependency gate pattern for risky removals
(`sddm`/`cage`); add to the hard-fail loop for must-not-survive; grep
`files/scripts/` + `files/packages.json` for later reinstalls. The old
Bazzite-era removal helpers are deleted — extend `remove-packages.sh`, never
resurrect them.

### diagnose-failed-build

Locate by banner + `::group::` marker; verify failures print
`::error::<module>-verify failed` or a `FAIL` line. Classify:

| Signature | Cause | Action |
| --- | --- | --- |
| `504` / repodata timeouts | Copr CDN | retry; the repos module drop-in + CI `URLS` wait loop exist for this |
| `no match for argument` | renamed/moved package | verify-package-availability |
| `Conflicts` naming `dkms-nvidia` | NVIDIA subpackage on a `dnf5 install` line | rpm2cpio-extract instead |
| `FAIL` in verify, module logged OK | the gate is wrong | fix the gate, say which in the commit |
| recipe fails `bluebuild validate` | schema/`from-file`/script path error | `bluebuild validate -vv` |
| base pull error on a fresh runner | transient registry/network | retry run |
| `Lint warning: var-tmpfiles` | wrote to `/var` | tmpfiles.d rule |
| `Lint … var-run/kernel/etc-usretc` | **fatal** bootc lints | must fix |
| cosign "no signature exists" on bootc switch/upgrade | Cosign 3 referrer-format signature | rebuild with the legacy flags (§4.10) |
| cosign "identity not accepted" | policy.json missing `matchRepository` | `image-info.sh` |

Reproduce without a build: `bluebuild generate -o /tmp/Containerfile.rendered
recipes/recipe.yml` and inspect the module RUNs; or mount the rendered file's
layer chain by hand and re-run the failing script from `/tmp/files/scripts`.
Never fix a red build by loosening a gate; preserve `# NOTE:` comments while
debugging — they are the design docs.

### bump-fedora-release

Order matters: (1) confirm every consumed third-party repo has builds for the
new release BEFORE touching anything (the seven `repomd.xml` URLs in
`build.yml`'s `URLS` array, plus `repos.fyralabs.com/terra45/`) — if one is
missing, the bump is blocked; (2) confirm negativo17's NVIDIA userland still
matches the COPR kernel modules (see below); (3) `recipes/recipe.yml`
`image-version` + `halcyon.env` — `just check` fails the run if they diverge;
(4) the `URLS` array's `fedora-44-x86_64` paths; (5) re-run
verify-package-availability over every list — expect 2-3 renames per release;
(6) expect `remove-packages.sh` drift; (7) full local build +
`just package-count`, compare the census.

### bump-kernel-or-nvidia (highest-risk change in the repo)

Read `files/scripts/install-kernel.sh`'s header in full. The invariant: the
NVIDIA **userland** version must equal the **kernel module's** reported driver
version (`modinfo -F version` on the `.ko` vs `rpm -q nvidia-driver-libs.x86_64`)
— `final-verify.sh` gates it; divergence boots to a black screen. Re-derive the
entangled-negativo-subpackage list per driver version (do not trust the
comment); re-check the `rpm2cpio` payloads for file collisions; keep
`tsflags=noscripts` + explicit `depmod`/dracut; confirm
`CONFIG_SECURITY_SELINUX=y` (halcyon runs enforcing); boot-test in a VM before
pushing. Fallback if the prebuilt modules and negativo17 drift irreconcilably:
DKMS (`rakuos-base` pattern) — a kernel-module change, not a patch. NOTE:
flipping the kernel source to `aahsnr-work/halcyon-kernel` (same package names)
is the planned Stage K2 — the repo file is already written, just not staged.

### ci-signing-and-runners

Keep the legacy cosign flags + pinned `cosign-release` (Cosign 4 will remove
them; `verify-github.sh` gates both steps). Keep the bluebuild CLI install
pinned to `ghcr.io/blue-build/cli:v0.9.37-installer` (`verify-github.sh` gates
it). Pin `ubuntu-24.04` (the 26.04 migration window is 2026-10-19…11-19; bump
`ublue-os/remove-unwanted-software` past v9 when moving). Only `PUBLISH_BRANCH`
publishes; scheduled/dispatch runs execute the default branch's workflow —
keep `container` as the default branch or the daily rebuild never runs. Pin
actions to tags/SHAs. Run `just check-github` after any workflow edit.

---

## 9. Known traps

- **Verify gates must not be skippable by layer caching.** Anything new that
  is a gate (not a normal build step) must live in `final-verify.sh` or
  `bootc-lint.yml`, or carry `no-cache: true` on the module config.
- **Module scripts run with `PWD=/tmp/files/scripts`** and the `files/` dir
  mounted at `/tmp/files` (read-write bind of a scratch stage, never baked).
  Do not rely on repo-root paths; do not write build state into `files/`
  expecting it to persist — copy out to `/usr/src/…` or similar.
- **bluebuild's `post_build.sh` wipes `/tmp/*` and `/var/*`** after the last
  module (and re-links `/opt` → `/var/opt`, writes `99-bluebuild-optfix-*.conf`
  tmpfiles). All halcyon gates run before it; nothing may depend on `/tmp` or
  `/var` content surviving into the image.
- **The base image is digest-pinned by generate** — a fresh `bluebuild
  generate` each build re-resolves `image-version: 44`; `--pull=newer` is
  moot. The digest flip is visible in the generated Containerfile
  (`LABEL org.opencontainers.image.base.digest`).
- **Module images use upstream-managed `:latest`/`:default` tags**
  (`ghcr.io/blue-build/modules/script:latest`, `nushell-image:default`).
  Bump the CLI pin together with testing those.
- **Prove every new gate can fail.** Invert it once and confirm exit 1. Beware
  `test "${VAR}" = "$(...)"` with empty VAR (the NVIDIA gate needs
  `test -n "${NV_MOD_VER}"` first).
- **Do not gate what you have not checked exists** (no `/opt` gate; no grep
  over shipped recipe prose).
- **`ConditionEnvironment=` reads the user manager's env** — see §7; without
  `dbus-update-activation-environment --systemd` pyprland never starts.
- **Package names change between Fedora releases** (`terra-gamescope`/
  `terra-mangohud` retired; lazygit's Terra name). `dnf5` aborts the whole
  transaction on one bad name — verify before adding. Halcyon names are pinned
  by the monorepo registry, which is the point of the split.
- **Build-tool preconditions are invisible dependencies** (`git`, `curl`,
  `jq`, `gcc-c++`); the base-packages verify section gates them.
- **The halcyon group repos come from `dnf5 copr enable` (repos module),**
  which hits the Copr API at build time — the CI `URLS` wait only covers
  repodata. If the API flakes, the five `.repo` files can return as quoted
  heredocs inside `repos.sh`.
- **Local podman graph store on this dev machine is corrupt** (missing overlay
  layers — `podman pull` fails with readlink …/diff: no such file). Host
  verification is `just check`/`lint`/`check-github` + `bluebuild
  validate/generate`; the first real build is the CI run.
- **CI runners are pinned to `ubuntu-24.04`** (26.04 migration window
  2026-10-19…11-19; `remove-unwanted-software@v9` is incompatible).
- **Scheduled workflows run only from the default branch**; `build.yml`
  publishes only from `PUBLISH_BRANCH` (`container`).
- **The six halcyon repos must be complete before the image consumes them.**
  Readiness: the migration cascade finished, repoclosure green on both
  releases, and the packages the image installs are green in their groups.
  Until then `testing` stays local and unpushed.

---

## 10. CI

- `lint.yml`: pinned bluebuild install → `just check` (incl. `bluebuild
  validate`), `just lint`, `.github` audit, actionlint 1.7.12, ruff, pytest.
- `semantic-pr.yml`: PR-title Conventional Commits check.
- `build.yml`: publish gate → COPR metadata wait (the seven `URLS`) → syntax
  gates → pinned bluebuild install → `just build` (bluebuild generate + podman
  build) → `verify/` suite → census → tags → (publish branch only) push, sign
  (legacy format), verify. Consumed COPRs: the five `aahsnr-work/halcyon*` group
  repos, `catpieleaf/kernel-p03`, `ublue-os/packages`.
- `clean.yml`: weekly GHCR pruning (Sundays 00:15 UTC).

Any COPR the build consumes must be in the `URLS` wait array AND the
`verify-github.sh` monitor list — both or the build goes red randomly. The
bluebuild CLI pin, the cosign legacy flags and the runner pins are all gated
by `verify-github.sh` too.

---

## 11. Checklist before proposing a change

- [ ] `just check` and `just lint` pass.
- [ ] `just lint-python` / `just test-python` pass if python helpers changed.
- [ ] `bluebuild validate recipes/recipe.yml` passes (in `just check`).
- [ ] New module is listed in `recipes/recipe.yml` (from-file) and its script
      lives in `files/scripts/` with a `nn/13` banner.
- [ ] New mutating module script ends with `lib/cleanup.sh` (finish/final
      modules excepted per §4.2).
- [ ] Every new gate has been inverted once and confirmed to fail; gate
      modules carry `no-cache: true` in their config.
- [ ] New `dnf5 install` uses `--setopt=install_weak_deps=False` and
      readarray-typed lists (no SC2046).
- [ ] Third-party repos: enabled and disabled inside one module (halcyon group
      repos excepted — copr-enabled in the repos module, swept by
      `finalize.sh`).
- [ ] Every binary a new recipe calls is in `files/packages.json` and gated.
- [ ] Nothing new lands in `/var`, `/usr/etc`, `/usr/local` or `/boot`.
- [ ] New files in `usr/bin` / `usr/libexec` are mode 0755.
- [ ] Workflows: no branch pins, no `ubuntu-latest`, signing flags untouched,
      bluebuild CLI pin untouched.
- [ ] Comments that describe _why_ are preserved — they are the design docs.