# AGENTS.md — halcyon (base-image)

Guidance for AI agents (and humans) working in this repo. Every fact is
stated once; the ymls and scripts carry their own _why_ comments — keep
them in sync with this file.

## 1. What this repo is

`halcyon` builds a minimal Hyprland gaming-desktop OCI image on
`ghcr.io/ublue-os/bazzite-nvidia-open:latest` (Plasma removed; Hyprland +
Noctalia layered; fonts swept and re-curated) via the BlueBuild CLI. The
base already ships kernel, NVIDIA stack, firmware/mesa/audio,
Steam/Lutris/gamescope/mangohud, ublue-os-* tooling and uupd — none of
that is reinstalled. The base ships terra/rpmfusion repo files DISABLED
(only fedora/updates/updates-archive load during dnf transactions): any
Terra/RPM Fusion payload needs a scoped `.repo` file staged in the
consuming module. `recipes/halcyon.yml` is the build definition — its
module ORDER is load-bearing (removals must precede every install so the
sweep cannot eat the curated set) and `bootc-lint` stays last. Shared
groups live in `recipes/modules/*.yml`, pulled with
`from-file: modules/<name>.yml`. The nix module follows
[fu5ha/winter](https://github.com/fu5ha/winter)'s package set; file
placement follows this repo's overlay rule.

## 2. Repository layout

```
recipes/halcyon.yml       # build definition; order load-bearing, bootc-lint last
recipes/modules/*.yml     # one module group per file (terra/ublue-pkgs/hardware
                          #   were deleted — the bazzite base provides all three)
files/                    # mounted at /tmp/files in every module RUN; never baked in
  system/                 # overlay copied to / BEFORE every package install:
                          #   etc/default/useradd (SHELL=zsh)
                          #   etc/skel/.gnupg/gpg-agent.conf (pinentry-gnome3 —
                          #     pinentry-qt stays gone after the KDE sweep; chezmoi
                          #     doesn't manage skel, so --force never deletes it)
                          #   etc/profile.d/{00-path-guard,01-nix-resolve-home-env,
                          #     02-custom-environment,03-gnupg-ssh,image-path}.sh —
                          #     run in that order; image-path.sh (755) puts
                          #     usr/libexec/halcyon-image/* on PATH
                          #   usr/lib/systemd/system/{var-nix.service,nix.mount}
                          #   usr/lib/systemd/user/pyprland.service (+ .d/ drop-in;
                          #     pyprland's RPM ships no unit)
                          #   usr/lib/systemd/user/chezmoi-init.service.d/10-halcyon.conf
                          #   usr/lib/tmpfiles.d/zz-halcyon-nix.conf
                          #   usr/share/ublue-os/just/ — 60-custom.just registers the
                          #     halcyon-own recipes (recipes shared with bazzite are
                          #     bazzite's)
  dnf/*.repo              # scoped repos for the dnf module: the COPRs
                          #   (applications, fonts, python-packages, cli-tools,
                          #   base-pkgs, texlive-packages), vscode, brave,
                          #   terra-gaming
  dnf-libdnf5/            # retries=20 drop-in → /etc/dnf
  scripts/                # stage scripts + verify-<module>.sh gates +
                          #   lib/cleanup.sh (per-script why: §3 bullets)
cosign.pub                # CLI stages it to /etc/pki/containers before any module
.containerignore          # keeps .github etc. out of the build context
.github/                  # workflows: build (PUBLISH_BRANCH=main gate, CLI pin
                          #   v0.9.37, cosign 2.6.5 legacy sign, COPR wait loop,
                          #   package census, ubuntu-24.04, quay.io zstd:chunked
                          #   mirror push gated on the QUAY_* secrets), lint,
                          #   clean, semantic-pr; renovate.json5 (digest-pins
                          #   everything, tracks the CLI pin, automerges pin PRs)
AGENTS.md / README.md / TODO.md / LICENSE / .gitignore
```

NOT in this repo: Justfile, files/packages.json, verify/, halcyon.env.
Never reintroduce a package catalog — installs go through the `dnf`
module; CI steps are inlined (no Justfile).

## 3. Module inventory (the _why_ per module, in recipe order)

- `signing`: image signing.
- `files`: `system → /` first, so overlay files precede installs. A
  regular file at an RPM-owned path is silently overwritten by the RPM; a
  `%config(noreplace)` path KEEPS the overlaid file and the RPM's copy
  lands as `.rpmnew`. `dnf-libdnf5 → /etc/dnf` second.
- `removals.yml`: the de-Plasmaing. `strip-mesa-exclusion.sh` strips the
  mesa TOKENS from the `exclude=` lines bazzite's own build wrote into the
  fedora repo files (kernel/steam protection stays; any mesa install must
  remain possible). The stage runs under a staged drop-in
  (`erase-noscripts-{on,off}.sh`): `tsflags=noscripts` — rpm fails the
  WHOLE transaction when any erase scriptlet fails (rpm 6.0+, dnf5 #2507;
  akonadi's `%postun` aborted a completed 413-package erase; erase
  scriptlets shell out to systemctl, impossible in a build chroot; file
  triggers unaffected) — and `excludepkgs` protecting the gaming/media
  stack (mesa/libglvnd/gstreamer/pipewire/ffmpeg-libav/libva/codecs): the
  remove-time auto-remove closure ignores install reasons AND
  `dnf5 mark user`, so exclusion is the only reliable guard; `steam*`
  stays unprotected on purpose (guarded-removals removes steamdeck-*
  explicitly). The drop-in is removed before the first install stage
  (both verify scripts gate on its absence). `dnf remove`
  (`auto-remove: true` — closes the orphaned kf5/kf6/qt5 closure) lists
  only names verified present in the base image (dnf5 aborts on one absent
  name) plus the user-marked removal set — EXCEPT the tesseract closure
  (tesseract-libs/-common/-langpack-eng/-tessdata-doc): the protected
  ffmpeg hard-requires libtesseract. Exclusion globs are lookalike-proof
  (`ffmpeg`/`ffmpeg-*`, never `ffmpeg*` — dnf5 refuses to remove an
  excluded name, and ffmpegthumbs IS removed). Then `guarded-removals.sh`:
  pass 1 tolerant only-if-present candidates (old GNOME stack, steamdeck
  variance, ibus/fcitx5 application packages); pass 2 reverse-dep-gated
  cores (sddm/cage/ibus/ibus-libs/fcitx5/fcitx5-libs); must-be-gone
  hard-fail loop. Then `fonts-cleanup.sh`: dnf remove of `*fonts*` to a
  fixpoint first (removing a requirer frees its deps for the next pass),
  then a reverse-dep-gated `rpm -e` mop-up; keep-regex protects
  fontconfig/fonts-filesystem/fontpackages/dejavu-sans{,-mono}; fonts that
  later packages pull back as deps are ACCEPTED and NOT gated (user
  decision). Never pattern-match keepers: kernel*/kmod-* (base kernel +
  NVIDIA akmods + gaming kmods), kbd*, kpartx (multipath), kvazaar-libs
  (codec). Keepers are NOT gated here — nothing is installed yet this
  early; `final-verify.sh` owns the keeper set at end state.
- `core.yml`: utilities the base lacks; everything the base inventory shows
  is dropped — dnf5 ERRORS on install-of-installed. Deliberately
  absent: libinput-utils (base ships the same name), ddcutil (base ships
  terra-ddcutil, which conflicts with Fedora's), mpv (needs
  libavfilter-free, obsoleted by the base's epoch-1 RPM Fusion ffmpeg; RPM
  Fusion ships no mpv, Terra only mpv-nightly). fastfetch: removals strips
  bazzite's blinged build, core reinstalls vanilla. qt5ct retired.
- `programming.yml`: the toolchains the base lacks (nodejs22(+npm),
  cargo, cmake, golang); python3/perl/gcc-c++ are base-provided and
  PATH-asserted by verify-programming.sh.
- `fonts.yml`: curated font set from COPR aahsnr-work/fonts
  (priority=1 + includepkgs); swept base fonts + dejavu-sans return as a
  noctalia hard dep — accepted, not gated.
- `desktop.yml`: COPR aahsnr-work/base-pkgs, the Hyprland + Noctalia
  stack. greetd + noctalia-greeter-git are REMOVED — login is
  `getty@tty2` + a manual Hyprland start (ly is planned, see TODO.md).
  Thunar suite replaced by nautilus (file-roller installs in core.yml).
  Noctalia ships its own polkit agent, so removing polkit-kde strands
  nothing. gnome-keyring(+pam) pre-wires the future ly stack.
  xdg-desktop-portal-gtk + wl-clipboard are base-provided keepers (dnf5
  install-of-installed errors).
- `gaming.yml`: RPM-only gaming (zero flatpak). Base already ships
  steam/steam-devices/lutris/gamescope(terra-)/mangohud(terra-, +i686)/
  zenity/evtest/input-remapper/usbip/ydotool; the module installs only
  `gamemode` and `heroic-games-launcher` via scoped `terra-gaming.repo`
  (if the name ever vanishes: COPR atim/heroic-games-launcher). The four
  NVIDIA exclude globs stay so no transaction can clobber the base's
  kmod-nvidia chain.
- `devtools.yml`: COPR aahsnr-work/cli-tools, the full curated set. btop
  + fpaste are base-provided keepers (the COPR doesn't build them). fzf
  is in the base AND the COPR — removals strips the base copy so the COPR
  version can install.
- `nix.yml`: systemd enable (var-nix.service, nix.mount) → dnf install
  nix, nix-daemon → systemd enable nix-daemon. Units and config arrive
  via the files/system overlay (no files/systemd/ dir — the systemd
  module's auto-copy path is unused here). Never add a package name
  without verifying it first (dnf5 aborts a transaction on one bad name).
- `texlive.yml`: rolling TeX Live from COPR aahsnr-work/texlive-packages
  — texlive-bin + the texlive-* data groups under one self-contained
  /usr/lib/texlive/<year>/ root that kpathsea resolves via SELFAUTOPARENT
  (no path overlap, no name collisions with Fedora's texlive).
  `texlive-formats.sh` bakes formats after the transaction (rpm can't
  order %post after sibling data groups): FIRST rebuild texmf-dist's ls-R
  (texlive-basic ships one covering only its own members; mktexlsr refuses
  to overwrite a deviating magic header — rm first) and trim
  language.dat/def/lua to the pattern files actually installed (fmtutil
  aborts mid-ini on the first missing loader); THEN updmap-sys +
  fmtutil-sys. verify-texlive is find-based (lualatex bakes under
  luahbtex/, not luatex/).
- `apps.yml`: repos (vscode.repo, brave, COPR aahsnr-work/applications)
  then install — editors, browsers, VPNs, office apps. `zed` is a
  DELIBERATE install, not pulled by emacs-pgtk (verified against both
  COPR specs).
- `python-packages.yml`: halcyon's own Python helper tools from COPR
  aahsnr-work/python-packages.
- `flatpaks.yml`: the zero-flatpak policy via bluebuild's
  `default-flatpaks@v1` (pinned: v2 dropped remove support). Bazzite bakes
  NO flatpaks into the image — four boot-time services deliver them
  (bazzite-flatpak-manager, ublue-nvidia-flatpak-runtime-{sync,verify},
  flatpak-add-fedora-repos; all RPM-unowned, masked in ujust.yml). The
  module's `system.remove` list (25 IDs) is enforced on every boot by
  system-flatpak-setup.timer, which is what covers rebasing machines
  whose /var/lib/flatpak survives the rebase. No repo fields set → the
  boot script adds no remote, deletes the fedora flatpak remotes it
  finds, and leaves the base's disabled flathub untouched (skipping
  Flathub's build-time ID validation too). `user: {}` neutralizes the
  unconditional --global user timer (without user/repo-info.json it
  errors on an empty repo name every boot). Upstream v1 matches its
  remove list against installed APPS only — the runtime refs are
  declarations; a rebased machine clears orphaned runtimes with
  `flatpak uninstall --unused`, fresh installs never get any.
  verify-flatpaks.sh gates the shipped config + the masks (build-time
  only — the removals themselves are not assertable in a container).
- `chezmoi.yml`: the official blue-build chezmoi module — writes
  chezmoi-init.service + chezmoi-update.{service,timer} and enables them
  --global; repository aahsnr-configs/dotfiles (public HTTPS — no keys
  needed on a fresh machine), file-conflict-policy replace (dotfiles are
  the source of truth). The binary is deliberately NOT an RPM: the module
  downloads the latest GitHub release (freshness over reproducibility);
  final-verify backstops with a negative `rpm -q chezmoi` gate. The
  overlay drop-in 10-halcyon.conf carries the first-rebase fixes — its
  ExecStart override re-states the repository, keep the two in sync:
  `--force` (a rebased home holds differing dotfiles and the
  non-interactive apply dies on the first "already exists"),
  Restart=on-failure + 15s (network-online.target doesn't exist in a
  user manager, so a clone racing the network retries), and
  TimeoutStartSec=600 (a cold clone+apply outruns the ~90s default).
- `ujust.yml`: no dnf block (base ships glow/jq/just/stress-ng) →
  `systemd` module, declarative unit state: enabled = uupd.timer,
  getty@tty2.service (login path until ly lands); masked =
  sddm/gdm/plasma-login-manager/bazzite-autologin/nvidia-persistenced/
  nvidia-powerd/systemd-oomd (gaming box) plus the flatpak quartet
  (flatpaks.yml owns flatpak state); user.enabled = pyprland. → `script
  ujust-system.sh`: only what no module covers — ujust presence gates,
  base steam wiring no-op gates (base ships bazzite-steam + the patched
  steam.desktop; gate, don't re-patch), and the verify tail (`ujust
  --list`, companion-binary sweep, 60-custom.just ↔ shipped-recipes
  completeness gate), ending with lib/cleanup.sh. Only halcyon-OWN
  recipes are registered by 60-custom.just; recipes shared with bazzite
  are NOT carried — bazzite's win (just has no allow-duplicate-aliases;
  the first bazzite build's `ujust --list` died on forked copies).
  var-nix.service/nix.mount remain in nix.yml.
- `finish.yml`: os-release module (NAME/PRETTY_NAME/HOME_URL) →
  grub-config.sh (key-preserving GRUB_TIMEOUT=10 + GRUB_TIMEOUT_STYLE=
  menu; the base hides the menu — fresh installs read it at grub.cfg
  generation, deployed machines use `ujust regenerate-grub`) +
  finalize.sh (sweeps ONLY recipe-staged repo files — the base's own
  terra/rpmfusion/ublue repos are deliberately untouched, deleting them
  breaks the base's update path; /usr/etc sweep keeps the bootc
  etc-usretc lint green; keepcache=0, log/boot/cache wipes). No
  initramfs module (base ships a valid initrd; recipe adds no kernel
  modules). No image-info.sh (base ships
  /usr/share/ublue-os/image-info.json; bazzite-steam reads it).
- `final-verify.yml`: `no-cache: true` end-state backstop — its gate
  groups mirror the script's own group headers. Policies worth knowing:
  NO gate on base font packages' absence (later installs may pull them
  back), the no-staged-repos gate anchors on the staged FILENAMES (a
  broad pattern false-positived on the base's own negativo17 repos), and
  flatpak removals are not assertable in the build.
- `bootc-lint.yml`: `no-cache: true`, hermetic
  `RUN --mount=type=tmpfs,target=/run --network=none bootc container
  lint` — always last.
- Per-module `verify-<module>.sh` (trailing script block in every payload
  module): rpm -q/binary/config gates, `gate()` fail-latcher,
  `::error::` + exit 1. Deliberately CACHEABLE — a no-cache gate per
  module would bust every downstream layer on each build; final-verify +
  bootc-lint are the no-cache backstop. They mutate nothing, so they
  don't call lib/cleanup.sh.

## 4. Conventions

- Schema headers: `recipe-v1.json` for the recipe, `module-v1.json` for a
  single module, `module-list-v1.json` for a `modules:` list. New groups
  go in recipes/modules/ and are referenced from the recipe at the
  correct position (overlay-dependent content after the `files` entries).
- `dnf install` always sets `install-weak-deps: false` (list weak deps
  explicitly). Third-party repos set `cleanup: true`, which removes the
  repo files at the END of the same RUN — the repos block and the
  install that consumes it must live in ONE dnf module. Local `.repo`
  files live in files/dnf/. COPR repos pair priority=1 with
  includepkgs=<the curated set>: priority alone would make dnf5 prefer
  the COPR for every dependency name, and a name filtered out of the
  COPR falls back to Fedora for the WHOLE closure (missing chafa-libs
  silently served Fedora's older chafa). `cleanup: true` has a known
  race — its repo-info resolution can come back empty and remove
  nothing — so repo-leftover-sweep.sh runs before every repos-module
  verify gate.
- `dnf remove` lists only names verified present in the base inventory;
  may-or-may-not names go through guarded-removals.sh's only-if-present
  sweeps. Install lists get the reverse treatment: dnf5 errors on
  already-installed names, and same-name/terra-name twins conflict
  (ddcutil vs terra-ddcutil) — check the base inventory AND twins before
  adding any name.
- The base carries dnf `exclude` config that fights the build (bazzite
  writes `exclude=mesa-* …` into the fedora repo files). If a
  transaction starts failing with "filtered out by exclude filtering"
  after the `:latest` base moves, check for new exclusions
  (strip-mesa-exclusion.sh owns the mesa tokens). The auto-remove cascade
  also ignores install reasons AND `dnf5 mark user`: anything the image
  must KEEP is made invisible to the solver via the staged excludepkgs
  drop-in.
- Declarative first: do with bluebuild modules (files, dnf, systemd)
  whatever a module can express; `script` is only for what none covers.
  The systemd module's `user.enabled` = `systemctl --global enable`;
  `masked` works on units that aren't installed; enabling a missing unit
  aborts the build.
- `script` `scripts:` name files under files/scripts/ that MUST exist
  (validate won't catch a missing one); prefer `snippets:` for short
  inline gates. Scripts start `#!/usr/bin/env bash` +
  `set -euo pipefail`; gates print `FAIL …` to stderr and exit 1, and
  every new gate is proven failable (invert once, confirm exit 1).
- Log style: `████ STAGE nn · <name> · … ████` banners, ::group:: /
  ::endgroup:: folds, OK/FAIL prefixes.
- Executable bits come from git (chmod +x before commit): build scripts,
  lib/, usr/libexec wrappers and profile.d hooks are 0755; units,
  justfiles, configs and tmpfiles are 0644.
- Nothing new lands in /var, /usr/local, /boot, or /usr/etc. Comments
  explain _why_, not _what_.

## 5. Known gaps (status, not work)

- CI prerequisites (repo side done): the SIGNING_SECRET secret must hold
  the cosign private key matching cosign.pub, and the Renovate App must
  be installed — without them the publish-gated sign/verify steps fail on
  the publish branch. The quay.io mirror additionally needs the
  QUAY_USERNAME/QUAY_PASSWORD secrets (a quay.io robot account — free, no
  credit card) and its repo flipped to PUBLIC once in the web UI (quay
  auto-creates pushed repos as private); without the secrets the mirror
  push is skipped with a warning, never a failure.
- files/system/ still misses the wider-overlay extras: wallpaper/plymouth
  theme assets and etc/issue/motd.
- No display manager (greetd + noctalia-greeter removed with the bazzite
  migration): getty@tty2 + manual Hyprland start is the interim path; ly
  is the planned replacement (TODO.md).
- Runner is pinned ubuntu-24.04 with remove-unwanted-software@v9;
  ubuntu-latest migrates to 26.04 between 2026-10-19 and 2026-11-19 —
  switch to ubuntu-26.04 + jlumbroso/free-disk-space when it does (v9 is
  incompatible with 26.04).

## 6. Commands

```bash
bluebuild validate recipes/halcyon.yml        # schema + from-file resolution (must be clean)
bluebuild validate -a recipes/halcyon.yml     # all errors, not just the first
bluebuild generate -o /tmp/Containerfile.rendered recipes/halcyon.yml  # inspect RUNs
bash -n files/scripts/*.sh files/scripts/lib/*.sh   # syntax check on build scripts
shellcheck --shell=bash -x files/scripts/*.sh files/scripts/lib/*.sh
docker run --rm -v "$PWD:/repo" --workdir /repo rhysd/actionlint:1.7.12 -shellcheck= -pyflakes=
```

Full image builds go through CI (.github/workflows/build.yml): generate +
podman build locally is possible but NOT run in this checkout — respect
the no-local-build rule.

## 7. Checklist before proposing a change

- [ ] `bluebuild validate` is clean.
- [ ] New module file uses the right schema header and sits at the
      correct position in recipes/halcyon.yml.
- [ ] New `script` entries name files that exist under files/scripts/;
      `bash -n` and `shellcheck -x` are clean.
- [ ] New install module ships a verify-<module>.sh companion wired as a
      trailing script block; every new gate has been inverted once and
      confirmed to fail.
- [ ] New `dnf install` sets install-weak-deps: false; third-party repos
      set cleanup: true; no added package name is unverified against the
      base image.
- [ ] Nothing new lands in /var, /usr/local, /boot, or /usr/etc.
- [ ] _Why_ comments are preserved — they are the design docs.
- [ ] Workflow changes: no ubuntu-latest, no branch pins on `uses:`, the
      CLI pin / cosign 2.6.5 legacy flags / PUBLISH_BRANCH: main gate
      stay intact, actionlint passes.
