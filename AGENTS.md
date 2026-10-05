# AGENTS.md — halcyon (base-image)

Guidance for AI coding agents (and humans) working in this repository. This is
a BlueBuild project on the Bazzite base: every claim below was checked against
the tree.

## 1. What this repo is

`halcyon` builds a minimal Hyprland gaming-desktop OCI image on
`ghcr.io/ublue-os/bazzite-nvidia-open:latest` (Bazzite's KDE Plasma edition
with NVIDIA open modules) via the BlueBuild CLI (`bluebuild generate` +
build). The base already ships the kernel, NVIDIA driver stack,
firmware/mesa/audio, Steam/Lutris/gamescope, ublue-os-* tooling and uupd,
plus the Terra + RPM Fusion repo files — SHIPPED DISABLED (CI 2026-10-05:
only fedora/updates/updates-archive load during dnf transactions), so any
Terra payload must stage a scoped .repo file — halcyon strips the Plasma
desktop, install-closure-sweeps the base fonts, and layers Hyprland +
Noctalia plus a curated app/dev set. `recipes/halcyon.yml` is the build
definition: base
image, labels, and the module list in execution order. Shared module groups
live in `recipes/modules/*.yml` and are pulled in with
`from-file: modules/<name>.yml`. Package installs use BlueBuild's `dnf`
module with `install-weak-deps: false`; one-off build logic uses the `script`
module (`scripts:` from `files/scripts/`, or inline `snippets:`); systemd
units ship in the `files/system/` overlay and are enabled by name with the
`systemd` module. `packages.md` at the repo root is an `rpm -qa` inventory of
the base image — THE source of truth for "is this name already installed"
dedupe and for the removals list (checked `[x]` entries are user-marked
removals). The nix module's logic follows [fu5ha/winter](https://github.com/fu5ha/winter)
(`recipes/modules/nix.yml`: package set, enable order); file placement
follows this repo's overlay rule, not winter's sidecar dirs.

## 2. Repository layout (actual)

```
recipes/halcyon.yml       # THE build definition. Module order is load-bearing:
                          #   signing → files (system → /) → files (dnf-libdnf5 →
                          #   /etc/dnf) → removals → core → programming → fonts →
                          #   gaming → desktop → devtools → nix → texlive →
                          #   apps → chezmoi → ujust → finish → final-verify →
                          #   bootc-lint (bootc-lint must stay last)
recipes/modules/*.yml     # present: apps, chezmoi, core, desktop, devtools,
                          #   gaming, nix, programming, removals, texlive,
                          #   ujust (terra/ublue-pkgs/hardware were deleted —
                          #   the bazzite base provides all three payloads)
packages.md               # rpm -qa of the base image; source of truth for
                          #   dedupe + the checked ([x]) removal set
files/                    # mounted at /tmp/files in every module RUN; never baked in
  system/                 # static overlay — recipe copies files/system/* → /
                          #   etc/default/useradd (SHELL=zsh)
                          #   etc/skel/.gnupg/gpg-agent.conf (pinentry-qt —
                          #     Wayland-native GPG prompts; chezmoi does not
                          #     manage it, so --force applies never delete it)
                          #   etc/profile.d/00-path-guard.sh,
                          #     01-nix-resolve-home-env.sh, 02-custom-environment.sh,
                          #     03-gnupg-ssh.sh (SSH_AUTH_SOCK → keyring socket
                          #     when present), image-path.sh (mode 755; run in
                          #     that order — path guard first, image PATH hook last)
                          #   usr/libexec/bazzite-boot-remount (sourced by the
                          #     grub recipes in 80-halcyon.just; the vendored
                          #     usr/bin/bazzite-steam* wrappers were deleted —
                          #     the base ships them)
                          #   usr/libexec/halcyon-image/{encrypt-repo,git-setup,
                          #     hyprtheme,nuke-nvim} (mode 755; exposed on PATH
                          #     by image-path.sh)
                          #   usr/lib/systemd/system/{var-nix.service,nix.mount}
                          #   usr/lib/systemd/user/pyprland.service (+ .d/
                          #     10-halcyon-condition.conf; pyprland's RPM ships
                          #     no unit) and chezmoi-init.service.d/
                          #     10-halcyon.conf (first-rebase drop-in on the
                          #     blue-build chezmoi module's generated unit —
                          #     the module writes the base units itself; the
                          #     old ConditionUser=!greetd is gone — no greeter
                          #     user exists anymore)
                          #   usr/lib/tmpfiles.d/zz-halcyon-nix.conf
                          #   usr/share/ublue-os/just/{60-custom.just,*.just} —
                          #     the 10 halcyon ujust modules plus the static
                          #     import list registering them (the ublue-os-just
                          #     RPM ships the justfile's `import?` hook)
  dnf/*.repo              # local .repo files consumed by the dnf module (the
                          #   scoped COPR repos, see §4; fonts.repo +
                          #   terra-gaming.repo — the scoped Terra repo for
                          #   heroic-games-launcher, since the base ships
                          #   terra's own repo files disabled)
  dnf-libdnf5/libdnf5.conf.d/99-halcyon-retries.conf  # → /etc/dnf (retries=20)
  scripts/ujust-system.sh      # Stage 08: ujust gates + base steam wiring
                               #   no-op gates + ujust/system verify tail
  scripts/guarded-removals.sh  # compose-variance sweep (two passes: blind
                               #   candidates, then reverse-dep-gated cores:
                               #   sddm/cage/ibus/fcitx5) + must-be-gone gates
  scripts/erase-noscripts-{on,off}.sh  # stage/unstage tsflags=noscripts for
                               #   the removals stage: rpm fails the WHOLE
                               #   transaction when any erase scriptlet fails
                               #   (akonadi %postun killed a completed
                               #   413-package erase); file triggers unaffected
  scripts/fonts-cleanup.sh     # reverse-dep-gated base font sweep (*fonts*
                               #   glob; dejavu-sans comes back as a noctalia
                               #   hard dep, curated set installs in fonts.yml)
  scripts/grub-config.sh       # key-preserving /etc/default/grub update:
                               #   GRUB_TIMEOUT=10 + GRUB_TIMEOUT_STYLE=menu
  scripts/texlive-formats.sh   # bakes updmap maps + fmtutil formats after the
                               #   rolling-COPR install (no %post ordering)
  scripts/repo-leftover-sweep.sh  # deletes module-staged repo files when
                               #   bluebuild's cleanup mapping comes back
                               #   empty (its parallel `dnf repo info` storm
                               #   races dnf5's metadata cache); wired before
                               #   each repos-module verify gate
  scripts/finalize.sh          # sweep of RECIPE-STAGED repo files only (the
                               #   base's own terra/rpmfusion/ublue repos are
                               #   deliberately untouched) + /usr/etc sweep
                               #   (ublue-os-signing's policy.json) + hygiene
  scripts/final-verify.sh      # Stage 10 no-cache cross-cutting backstop
  scripts/verify-<module>.sh   # per-module gates (11 files — one per module
                               #   with a payload; wired as trailing script
                               #   blocks)
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
                           #     loop over the 5 aahsnr-work repos; pinned CLI
                           #     ghcr.io/blue-build/cli:v0.9.37-installer;
                           #     generate + podman build; census (kernel +
                           #     nvidia driver version); tags; cosign 2.6.5
                           #     legacy-format sign+verify via SIGNING_SECRET)
                           #   workflows/lint.yml (validate + bash -n +
                           #     shellcheck + repo audit; actionlint 1.7.12)
                           #   workflows/clean.yml (weekly GHCR prune, 90d)
                           #   workflows/semantic-pr.yml (PR-title check)
                           #   renovate.json5 (config:best-practices — digest-
                           #     pins every action; tracks the bluebuild CLI
                           #     pin via a regex customManager; automerges
                           #     pin PRs; leaves the actionlint tag alone)
                           #   log-helpers.sh, CODEOWNERS, PR template
AGENTS.md / README.md / TODO.md / LICENSE / .gitignore
```

NOT in this repo: `Justfile`, `files/packages.json`, `verify/`, `halcyon.env`,
`files/python-packages/`. Package installs go through the `dnf` module
(never a package catalog — do not reintroduce one); CI steps are inlined in
the workflows (no Justfile).

## 3. Module inventory (what each file actually does)

- `signing` (inline in recipe): image signing setup.
- `files` (inline): `system → /` runs first, so overlay files precede every
  package install. A regular (non-config) file at an RPM-owned path would be
  silently overwritten by the RPM; a `%config(noreplace)` path KEEPS the
  overlaid file and the RPM's copy lands as `.rpmnew` — verified 2026-09-30
  against `greetd` on `fedora-bootc:44`. `dnf-libdnf5 → /etc/dnf` second.
- `removals.yml`: the bazzite de-Plasmaing. The whole stage runs under a
  staged `tsflags=noscripts` drop-in (`erase-noscripts-on.sh` first,
  `erase-noscripts-off.sh` before the verify gate): rpm records ANY scriptlet
  failure — even "non-critical" `%postun` — in a transaction-global flag and
  then fails the whole transaction (rpm 6.0+, dnf5 #2507), and erase
  scriptlets shell out to `systemctl`, which cannot work in a build chroot —
  akonadi-server's `%postun` aborted the transaction after all 413 erases had
  completed. File-trigger cache maintenance (ldconfig, glib schemas) is
  unaffected, and the drop-in is removed before the first install stage (both
  verify scripts gate on its absence). Then `dnf remove` with
  `auto-remove: true` (closes the orphaned kf5/kf6/qt5 closure) of every
  Plasma/KDE top-level package verified present in the base inventory
  (packages.md — dnf5 aborts the transaction on one absent name) PLUS the
  checked `[x]` set from packages.md (rom-properties*, ryzen_smu*, ryzenadj,
  signon*, system76-*, tesseract*, twitter-twemoji-fonts, urw-base35-*,
  vlc-*, xdg-desktop-portal-kde, zenergy*) → `guarded-removals.sh` (pass 1:
  tolerant only-if-present candidates — old GNOME stack, steamdeck variance,
  ibus/fcitx5 application packages; pass 2: reverse-dep-gated cores sddm/
  cage/ibus/ibus-libs/fcitx5/fcitx5-libs removed only when nothing installed
  requires them; must-be-gone hard-fail loop) → `fonts-cleanup.sh`
  (reverse-dep-gated sweep of EVERY `*fonts*` package; keep-regex protects
  fontconfig/fonts-filesystem/fontpackages/dejavu-sans{,-mono}; the curated
  set installs in core.yml, and dejavu-sans-fonts returns as a hard dep of
  noctalia-git) → `verify-removals.sh`. Never pattern-match keepers:
  kernel*/kmod-* (base kernel + NVIDIA akmods + gaming kmods), kbd*,
  kpartx (multipath), kvazaar-libs (codec). Keepers are NOT gated here —
  nothing is installed yet this early; `final-verify.sh` owns the keeper set
  at end state.
- `programming.yml`: the toolchains the base lacks (`nodejs22(+npm)`,
  `cargo`, `cmake`, `golang`); python3/perl/gcc-c++ are base-provided and
  PATH-asserted by `verify-programming.sh`.
- `apps.yml`: `repos` (local `vscode.repo`, brave `.repo` URL, both GPG keys,
  COPR `aahsnr-work/applications`, `cleanup: true`) then `install` — editors,
  browsers, VPNs, office apps. `zed` is a DELIBERATE install, not pulled by
  `emacs-pgtk` (verified against both COPR specs — emacs-pgtk has no
  zed-related dep at all).
- `core.yml`: the utilities the base lacks (grim/slurp/swappy/imv/zathura,
  file-roller, zsh, brightnessctl, fail2ban/lynis/bleachbit, setroubleshoot…),
  wired right after removals.yml. Everything the old list carried that
  packages.md shows in the base (cockpit*, podman*, distrobox, gnupg2,
  openssh-clients, plymouth*, hunspell*, ImageMagick, just, fastfetch deps…)
  is dropped — re-installing base packages is pure redundancy, and dnf5
  ERRORS on install-of-installed. Deliberately absent (first bazzite CI
  build, 2026-10-05): libinput-utils (base ships the same name), ddcutil
  (base ships terra-ddcutil, which conflicts with Fedora's ddcutil), and
  mpv (Fedora's mpv needs libavfilter-free, obsoleted by the base's epoch-1
  RPM Fusion ffmpeg; RPM Fusion ships no mpv, Terra only mpv-nightly —
  dropped by user decision). The old `group-install custom-environment` is
  gone (the base provides it) and qt5ct is retired (the qt5 stack now
  follows whatever actually requires it). fastfetch stays: removals strips
  bazzite's blinged build and core reinstalls vanilla.
- `fonts.yml`: the curated font set from COPR `aahsnr-work/fonts` (via
  `fonts.repo`, priority=1 + includepkgs), wired right after
  programming.yml. Swept base fonts + dejavu-sans return as a noctalia hard
  dep; `verify-fonts.sh` gates the set + fontconfig registration.
- `desktop.yml`: COPR `aahsnr-work/base-pkgs` (`cleanup: true`), the Hyprland
  + Noctalia stack. greetd + noctalia-greeter-git are REMOVED (ly is planned,
  not landed — login is `getty@tty2` + a manual Hyprland start) and the
  Thunar suite is replaced by nautilus (file-roller installs in core.yml).
  Noctalia ships its own polkit agent, so removing polkit-kde strands
  nothing. gnome-keyring + gnome-keyring-pam install here (the PAM module
  pre-wires the future ly stack). xdg-desktop-portal-gtk and wl-clipboard
  are NOT installed — the base ships both under the same names (dnf5
  install-of-installed errors); verify-desktop keeps asserting them as
  base-provided keepers.
- `gaming.yml`: the native gaming stack (RakuOS model — Steam/Lutris/Heroic
  as RPMs, zero Flatpak). The base already ships steam, steam-devices,
  lutris, gamescope (as terra-gamescope), mangohud (+i686, as terra-mangohud),
  zenity, evtest, input-remapper, usbip, ydotool; this module installs only
  `gamemode` (Fedora) and `heroic-games-launcher` via `terra-gaming.repo` —
  the base ships terra's own repo files DISABLED (CI repo-load log,
  2026-10-05), so the scoped repo (priority=1 + includepkgs) is mandatory;
  documented fallback if the name ever vanishes: COPR
  atim/heroic-games-launcher. No `nonfree: rpmfusion` staging. The four
  NVIDIA exclude globs stay so no transaction can clobber the base's
  kmod-nvidia chain.
- `devtools.yml`: COPR `aahsnr-work/cli-tools` (`cleanup: true`), only the
  tools the base lacks (asdf, atuin, bun, direnv, lazygit, pixi, ripgrep,
  starship, tealdeer, texlab, topgrade, uv…); bat/btop/cava/chafa/cliphist/
  dust/eza/fd-find/fpaste/fzf/gnuplot/opencode/pandoc are base-provided and
  re-asserted by `verify-devtools.sh`.
- `nix.yml`: `systemd` enable (`var-nix.service`, `nix.mount`) → `dnf install`
  `nix`, `nix-daemon` → `systemd` enable (`nix-daemon`). Units and config
  arrive via the `files/system/` overlay, not `files/systemd/` (no such
  dirs — the `systemd` module's auto-copy path is unused here). `dnf5`
  aborts a transaction on one bad name, so never add a package name without
  verifying it first (against packages.md or a repo file — see §6).
- `texlive.yml`: rolling TeX Live from COPR `aahsnr-work/texlive-packages`
  (`cleanup: true`) — `texlive-bin` (upstream's engine bundle + the TeXLive
  perl modules + the repo tlpdb) + the 12 `texlive-*` data groups, all under
  one self-contained `/usr/lib/texlive/<year>/` root that kpathsea resolves
  via SELFAUTOPARENT, so Fedora's fixed-release texlive is never touched
  (no path overlap, no name collisions). `texlive-formats.sh` bakes the
  format files after the transaction (rpm can't order %post after sibling
  data groups): it FIRST rebuilds texmf-dist's ls-R (texlive-basic ships an
  ls-R covering only its own members and mktexlsr refuses to overwrite a
  file whose magic header deviates — rm before mktexlsr) and trims
  language.dat/def/lua to the pattern files actually installed (the
  language collections are pruned upstream; fmtutil aborts mid-ini on the
  first missing loader); THEN updmap-sys + fmtutil-sys. `verify-texlive.sh`
  gates the tree, the PATH hook and the baked formats (find-based —
  lualatex bakes under luahbtex/, not luatex/). Fedora's texlive-collections
  era (2026-10-01) lasted one build — it was the fallback while the COPR
  shipped no engines.
- `chezmoi.yml`: the OFFICIAL blue-build `chezmoi` module
  (blue-build/modules) — writes `chezmoi-init.service` and
  `chezmoi-update.{service,timer}` to `/usr/lib/systemd/user/` and enables
  init+timer `--global` (`all-users: true`). `repository:
  aahsnr-configs/dotfiles` (public, HTTPS — no keys needed on a fresh
  machine) and `file-conflict-policy: replace` → the update timer runs
  `chezmoi update --no-tty --force` (dotfiles are the source of truth),
  with the module's default cadence stated explicitly (`wait-after-boot:
  5m`, `run-every: 1d`). The binary is deliberately NOT an RPM: the module
  downloads the latest GitHub release to `/usr/bin/chezmoi` itself (the
  download shells out to `/usr/bin/curl`, shipped by the base; freshness
  over build reproducibility), and `final-verify.sh` backstops the
  invariant with a negative `rpm -q chezmoi` gate. The generated init unit is
  a plain `--apply`, so the overlay drop-in `usr/lib/systemd/user/
  chezmoi-init.service.d/10-halcyon.conf` carries the first-rebase fixes
  (its ExecStart override re-states the repository — keep the two in
  sync): `--force` (a home rebasing from a previous OS holds differing
  dotfiles and the non-interactive apply dies on the first "already
  exists"), `Restart=on-failure` + 15s (network-online.target
  does not exist in a user manager, so a clone racing the network retries
  instead of waiting for the next login), and `TimeoutStartSec=600` (a
  cold clone+apply can outrun the ~90s user-manager default). The old
  `ConditionUser=!greetd` is gone — no greeter user exists anymore.
  Trailing `verify-chezmoi.sh` gates the binary, the not-RPM invariant, the
  three units, the drop-in and the `--global` wiring.
- `ujust.yml`: `dnf` install of `grubby` only (glow/jq/just/stress-ng ship
  in the base; grubby backs the kernel-arg recipes in 80-halcyon.just) →
  `systemd` module (declarative unit state): `system.enabled` =
  `uupd.timer`, `getty@tty2.service` (the login path until ly lands);
  `system.masked` = sddm/gdm/plasma-login-manager/bazzite-autologin/
  nvidia-persistenced/nvidia-powerd/systemd-oomd (oomd stays masked — this
  is a gaming box; masking needs no unit file); `user.enabled` = pyprland
  (`--global` → symlinks under `/etc/systemd/user/*.wants/`; the chezmoi
  units enable themselves --global in chezmoi.yml) → `script`
  `ujust-system.sh` (Stage 08): only what no module covers — the ujust
  presence gates, base steam wiring no-op gates (the base ships
  bazzite-steam + the patched steam.desktop; gate, don't re-patch), and the
  ujust+system verify tail (`ujust --list`, companion-binary sweep, a
  60-custom.just ↔ shipped-recipes completeness gate, getty@tty2/uupd
  enablement, overlay configs), ending with `lib/cleanup.sh`. The 10
  modules are registered by the static overlay file `60-custom.just` (the
  `ublue-os-just` RPM ships the justfile's `import?` hook for it);
  `var-nix.service`/`nix.mount` remain in nix.yml.
- `finish.yml`: `os-release` module (NAME/`PRETTY_NAME: halcyon (Bazzite)`/
  HOME_URL → /etc/os-release) → `script` `[grub-config.sh, finalize.sh]`.
  `grub-config.sh` key-preservingly sets `GRUB_TIMEOUT=10` +
  `GRUB_TIMEOUT_STYLE=menu` in /etc/default/grub (the base hides the menu
  with ~1s; fresh installs read it at grub.cfg generation, deployed machines
  use the shipped `ujust regenerate-grub`). `finalize.sh` sweeps ONLY the
  repo files this recipe stages (the base's terra/rpmfusion/ublue repos are
  deliberately untouched — deleting them breaks the base's update path) and
  runs the end-of-build hygiene (keepcache=0, log//boot/cache wipes, the
  /usr/etc sweep that keeps the bootc etc-usretc lint green). No `initramfs`
  module anymore: the base ships a valid initrd for its kernel and this
  recipe adds no kernel modules. No `image-info.sh` anymore: the base ships
  `/usr/share/ublue-os/image-info.json` and bazzite-steam reads it.
- `final-verify.yml`: `type: script`, **`no-cache: true`**, `final-verify.sh`
  — the end-state backstop: bazzite kernel + kmod-nvidia gates (incl. the
  modinfo-vs-rpm version match and `kernel-p03` absent), gaming + desktop
  keeper sets (incl. heroic-games-launcher/gamemode, nautilus/file-roller,
  pinentry-qt wiring, curated fonts, no `default-fonts-*`), the
  no-halcyon-staged-repos gate, identity files
  (os-release/image-info.json/texlive tree), grub timing, zsh default shell,
  chezmoi wiring, and the package census baked to
  `/usr/share/halcyon/package-count` (kernel + nvidia driver version).
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
  confines it to exactly the packages the consuming module installs —
  including their runtime subpackages (missing `chafa-libs` silently served
  Fedora's older chafa: a name filtered out of the COPR falls back to
  Fedora for the WHOLE closure). `cleanup: true` has a known failure mode —
  its repo-info resolution races dnf5's cache and then removes nothing —
  so `repo-leftover-sweep.sh` runs before every repos-module verify gate.
- `dnf remove` blocks may only list names verified present in `packages.md`
  (dnf5 aborts on one absent name); anything that may or may not exist goes
  through `guarded-removals.sh`'s only-if-present sweeps instead. Never add a
  package name to ANY dnf block without verifying it first (packages.md,
  dnf repoquery, or the consuming repo's spec).
- Install lists get the same treatment in reverse: dnf5 ERRORS when a listed
  name is already installed, and same-name/terra-name twins conflict
  (ddcutil vs the base's terra-ddcutil). Before adding any install name,
  check packages.md AND its terra-*/renamed twins. The base also ships
  terra + rpmfusion repo files DISABLED — any Terra/RPM Fusion payload
  needs a scoped `.repo` file staged in the consuming module
  (see terra-gaming.repo), never a bare package name.
- Declarative first: do with bluebuild modules (`files`, `dnf`, `systemd`)
  whatever a module can express; the `script` module is only for what no
  module covers (verify gates, key-preserving file edits like grub-config).
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
  (`files/scripts/*.sh`, `lib/`), the `usr/libexec` wrappers and the
  profile.d hooks are 0755; units, justfiles, configs and tmpfiles are 0644.
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
  theme assets and `etc/issue`/`motd`.
- Login has no display manager (greetd + noctalia-greeter were removed with
  the bazzite migration): `getty@tty2` + manual Hyprland start is the interim
  path; `ly` (in Fedora repos) is the planned replacement — see TODO.md.
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
      `cleanup: true`; no added package name is unverified (packages.md is
      the base-dedupe source of truth).
- [ ] Nothing new lands in `/var`, `/usr/local`, `/boot`, or `/usr/etc`.
- [ ] Workflow changes: no `ubuntu-latest`, no branch pins on `uses:`, the
      bluebuild CLI pin / cosign 2.6.5 legacy flags / `PUBLISH_BRANCH: main`
      gate stay intact, and `actionlint` passes.
- [ ] `_why_` comments are preserved — they are the design docs.
