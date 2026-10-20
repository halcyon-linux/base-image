# TODOs

---

1. Is everything using podman?

→ Answered (2026-10-18): yes, podman-only tooling. The local helpers (`just_scripts/container_mgr`) support `podman`/`podman-remote`; CI uses buildah (build + rechunk), podman (pull/run/push), skopeo (inspect/copy), and cosign. `docker://` is only the OCI transport scheme, and `~/.docker/config.json` is only the registry-auth file cosign reads; there is no Docker Engine dependency.

2. Is there is only custom image?

→ Answered (2026-10-18): yes — `alcyone` (formerly `bazzfin-nvidia`) is the single published image on this branch. `just_scripts/get-defaults` rejects other targets, CI builds/tags/signs only it, and the cleanup workflow prunes only its package. The `akmods*`, `brew`, and `ctx` stages are build inputs, not outputs. Renamed (2026-10-19): the Halcyon project publishes two images — `alcyone` (Containerfile, this branch) and `ceyx` (BlueBuild, `bluebuild` branch); `os-release` reports `NAME=Halcyon` on both.

3. What is the difference between binary/script in `system_files/desktop/usr/bin` and `system_files/desktop/usr/libexec`?

→ Answered (2026-10-18): `/usr/bin` is the user-facing PATH; `/usr/libexec` holds internal helpers invoked by units, ujust recipes, and polkit. `system_files/desktop/usr/bin` is now intentionally empty — user commands are RPM-provided (`brh`, `bruh`, `crh`, `gameclass`, `bbrew-helper`, `ublue-motd`, `uupd-update`); `system_files/nvidia/usr/bin/dlss-swapper` stays user-facing.

---

If you plan to combine bazzite-hardware-setup, bazzite-iwd-migration and bazzite-boot-remount into hardware-setup, you have to take into account the system systemd services and determine how to handle that?

→ Resolved (2026-10-19): `bazzite-iwd-migration` is deleted (unit + script): iwd is not installed in this image and the target machine's NetworkManager drop-ins are already clean. The boot-remount and hardware-setup helpers are now supplied by vendor-neutral RPMs; the image keeps the hardware setup oneshot unit and does not bundle their old Bazzite-named scripts.

[To understand the system systemd services, look at /usr/libexec/ binaries]:

1. `Important:` hardware setup service and helper

→ Resolved (2026-10-19): the image installs the `hardware-setup` RPM and checks its `/usr/bin/hardware-setup` executable. The local oneshot unit orders it before user sessions; no old in-tree helper script is shipped.

2. `Important` bazzite-iwd-migration.service -> bazzite-iwd-migration [NOTE:] Needs to be understand 1st or if even needed since NetworkManager is to be used. → RESOLVED (2026-10-18): both deleted; NetworkManager uses wpa_supplicant here and nothing in the image re-creates the iwd drop-ins.

3. For `bazzite-libvirtd-setup.service` where does libvirtd service exist?

→ Resolved (2026-10-18): `libvirtd.service` ships in the `libvirt-daemon` RPM. Follow-up same day: virtualization is now enabled by default — the libvirt/QEMU/swtpm stack, `virt-manager`, and `virt-install` ship in the image, `libvirtd.service` is enabled at build time, KVM kargs are applied by the `hardware-setup` RPM, and the old `bazzite-libvirtd-setup.service` one-shot (which only queued the enable for the next boot after a runtime `rpm-ostree install`) was deleted. `ujust setup-virtualization` remains as the repair/disable path.

4. `Ultra-important`: beesd@timer needs to exist which service pulls in the timer?

→ Resolved (2026-10-18): the `beesd@.service`/`beesd@.timer` templates ship in the `bees` RPM; the shipped `beesd@.timer` (`WantedBy=timers.target`) drives the daily run, and `ujust configure-beesd` enables per-filesystem `beesd@<uuid>.timer` instances. Nothing else pulls it in; kept as-is.

5. [Question:] Does cockpit.service need to be created manually? Does it not come installed normally? What is cockpit-container.service in this manual cockpit.serivce?

→ Resolved (2026-10-18): the image installs the cockpit sub-packages but not `cockpit-ws`, so the socket unit is absent. The manually shipped `cockpit.service` is a oneshot gate that `Requires=cockpit-container.service` (the Podman Quadlet in `usr/share/containers/systemd/`) with `ExecStart=/usr/bin/true`; ujust toggles it. Kept.

6. `Rare`: Determine the importance of `dev-hugepages1G.mount`. Otherwise remove it completely.

→ Resolved (2026-10-18): kept — it is gated by `ConditionKernelCommandLine=hugepagesz=1G` and is inert otherwise.

7. `Insignificant`: I don't want `force-wol.service`. Remove it completely.

→ Resolved (2026-10-18): removed entirely — unit, `usr/libexec/force-wol`, the `configure-system-services` entry, the whole `ujust wol` recipe + `toggle-wol` alias, and the yafti Wake-on-LAN action.

8. `Significant`: Keep `fstrim.service.d`

→ Resolved (2026-10-18): kept; no changes.

9. `Ultra-important`: Remove all traces of incus, services and any bash scripts.

→ Resolved (2026-10-18): removed `incus-workaround.service`, `tmpfiles.d/incus-workaround.conf`, the `configure-system-services` entry, and the incus `distrobox.ini` download in `install-system-integration-files`.

10. `Ultra-important`: `kmod-sleep-workaround@.service` must be kept and to make sure it works, make sure rmmod and modprobe are installed.

→ Resolved (2026-10-18): kept; added `kmod` to `common_packages`, and `verify packages` now requires the RPM and checks `/usr/bin/rmmod` + `/usr/bin/modprobe`.

11. `Important`: The dynamic-fixes user service needs its helper executable.

→ Resolved (2026-10-19): the `dynamic-fixes` RPM provides `/usr/bin/dynamic-fixes`; the user unit remains enabled globally and final verification checks both.

12. `Important`: The user-setup service needs its helper executable.

→ Resolved (2026-10-19): the `user-setup` RPM provides `/usr/bin/user-setup`; the user unit remains enabled globally and final verification checks both.

13. `Important`: `ntfs-nag.service` user service cannot exist because ntfs file system will be blacklisted or removed. Similarly, ntfs-exfat-monitor-script is no longer needed.

→ Resolved (2026-10-18): removed `ntfs-nag.service`, `ntfs-exfat-monitor-script`, the `configure-system-services` entry, and the `_disable-ntfs-service` recipe.

14. `Important`: Custom mesa-git script in system_files/desktop/usr/bin not needed since I have my own copr repo

→ Resolved (2026-10-18): the `mesa-git` script was removed with the `usr/bin` purge; also removed `89-bazzite-mesa-git.just` and its import line.

15. Waydroid support

→ Deferred: Waydroid is not included in this image and is explicitly forbidden by final verification. Its Portal entry, which invoked missing recipes, has been removed. Do not add NVIDIA support without revisiting the image's package policy.

---

1. tmpfiles.d/incus-workaround.conf must be removed

→ Resolved (2026-10-18): removed (with item 9 above).

---

---

Unneeded scripts/binaries

1. copr

→ Resolved (2026-10-18): all in-tree `usr/bin` scripts were removed, including `copr`; user-facing commands now come from RPMs. Dangling references (the Steam wrapper block in `configure-desktop-integration`, `bazzite-steam-bpm.desktop`, the `setup-boot-windows-steam` recipe + yafti entry, and the `fix-reset-steam` relaunch) were cleaned too.

- [x] Add bazzite-fork as a branch for base-image with Containerfile as the base image. → Done: this is the `containerfile` branch, which builds `alcyone`.

- [x] Don't start steam when logging 1st in.

→ Resolved (2026-10-19): autostart desktop entries in /etc/skel, /etc/xdg, and /usr/share/autostart are purged in configure-desktop-integration, and verify_final asserts they remain absent so Steam does not automatically launch upon user login.

- [x] Combine install-steam-lutris, install-gaming-stack and mesa-git, protonplus from aahsnr-work/gaming copr repo

→ Resolved (2026-10-19): `install-steam-lutris` removed; its contents merged into `install-gaming-stack`, which now also enables `aahsnr-work/gaming` at priority=1, installs `protonplus`, then immediately disables the repo. `verify_final` asserts the gaming COPR is disabled and `protonplus` is installed. mesa-git is not installed (kept in the COPR for manual/future use only).

- [x] Add chezmoi integration from aahsnr-configs/dotfiles repo

→ Resolved (2026-10-19): `chezmoi` RPM is installed via `install-common-packages`; `chezmoi-init.service` initializes and force-applies `aahsnr-configs/dotfiles` on user login (with retry on failure and `@system`/`greetd` guards); `chezmoi-update.timer` & `chezmoi-update.service` periodically pull dotfiles updates; units are globally enabled; `ujust dotfiles` provides interactive inspection and synchronization; build verification asserts package, units, and symlinks.

- [x] Determine if flatpak integration is complete and in place, just in case I want to add system flatpaks to the custom image.

→ Resolved (2026-10-19): Flatpak integration determined and completed. In bootc/OSTree, system Flatpaks live in machine-local `/var/lib/flatpak`; installing them directly inside Containerfile writes to `/var`, which gets stripped during image build or masked by the host's persistent `/var` volume on `bootc upgrade`. To enable system flatpaks declaratively without breaking image upgrades:

1. Flathub is pre-configured system-wide via declarative `/etc/flatpak/remotes.d/flathub.flatpakrepo` containing Flathub's official embedded GPG key (zero network calls during image build).
2. Declarative manifest `/usr/share/ublue-os/flatpak/system-flatpaks.list` allows listing application IDs to be provisioned system-wide.
3. Systemd oneshot unit `system-flatpak-setup.service` triggers `/usr/libexec/system-flatpak-setup` at boot (after network-online and flatpak-system-helper), idempotently reconciling and installing any declared Flatpaks into system storage.
4. Build verification asserts `flatpak`, `flatpak-system-helper`, remote definition, manifest, helper, and service enablement.

- [x] sddm must be installed instead of greetd. Only zsh package should be installed. No other zsh package is allowed.

→ Resolved (2026-10-19): `sddm` and `sddm-wayland-generic` added to `common_packages` in `install-common-packages`; `sddm.service` enabled and default target set to `graphical.target` in `configure-system-services`; `greetd.service` explicitly disabled and `greetd`/`greetd-selinux` added to the global-remove purge loop; auxiliary zsh packages (`zsh-autosuggestions`, `zsh-syntax-highlighting`) removed from package installation and added to the forbid list; `/etc/skel/.zshrc` simplified to source only the in-tree `zsh-preexec.zsh` shim; chezmoi user unit guards updated from `ConditionUser=!greetd` to `ConditionUser=!sddm`; `verify_packages` asserts `sddm`/`sddm-wayland-generic` required and forbids all auxiliary `zsh-*` RPMs with a glob check; `verify_final` asserts `sddm.service` presence, display-manager enablement, greetd artifact absence, and `/etc/skel/.zshrc` contains no auxiliary zsh plugin references.

- [x] Determine what else ublue-os/base-main comes pre-packaged with

→ Resolved (2026-10-19): Researched `ublue-os/main` and `packages.json`. The `ghcr.io/ublue-os/base-main` image layers on top of Fedora Atomic/Silverblue/bootc and pre-packages:

- Container orchestration & tooling: `distrobox`, `toolbx`, `flatpak-spawn`, `podman`
- Command runner: `just` (used by `ujust` recipes)
- Cryptographic verification: `cosign`
- Pre-configured repositories: RPM Fusion Free & Non-Free, Fedora Cisco OpenH264
- Hardware support: `ublue-os-udev-rules` for gamepads, controllers, and peripherals
- Audio & Multimedia codecs: `alsa-firmware`, `ffmpeg`, `ffmpeg-libs`, `fdk-aac`, `ffmpegthumbnailer`, `heif-pixbuf-loader`
- Base utilities & fonts: `apr`, `apr-util`, `fuse`, `fzf`, `grub2-tools-extra`, `htop` (purged in `global-remove`), `google-noto-sans-*-fonts` (CJK purged in `global-remove`).

- [x] Add strong verifications steps at every stage of the Containerfile custom image build

→ Resolved (2026-10-19): Comprehensive stage verification implemented across all 20+ build stages:

1. Extended `build_files/finalization/verify` with stage-specific verification functions: `brew`, `kernel`, `repos`, `cli-tools`, `utils`, `removals`, `common-packages`, `gaming`, `picker`, `media`, `desktop-integration`, `justfiles`, `services`, `integration-files`, `image-info`, `initramfs`, `finalize`, `nvidia-config`, `nvidia`, `system-policy`, `nvidia-finalize`, `packages`, and `final`.
2. Updated every single `RUN` instruction in `Containerfile` to call `/ctx/finalization/verify <stage>` immediately upon stage completion (prior to cleanup or subsequent stages).
3. If any layer fails its required RPMs, repository states, binary executables, unit enablement, or negative assertions (forbid list), the build aborts immediately at that layer with a descriptive failure.

---

- [x] In an appropriate location in the Containerfile as a bash script, install the following packages from aahsnr-work/fonts copr repo with priority=1 and install_weak_deps=False in the bash script: Keep in mind that you don't have to look for the copr repo.

google-noto-color-emoji-fonts, jetbrains-mono-fonts-all, nerd-fonts-jetbrainsmono, nerd-fonts-symbols-only, nerd-fonts-ubuntu, nerd-fonts-ubuntu-mono

→ Resolved (2026-10-20): Created `build_files/packages/install-fonts`, wired into dedicated RUN layer in Containerfile, verified via `verify fonts`.

- [x] In an appropriate location in the Containerfile as a bash script, install the following packages from aahsnr-work/base-pkgs copr repo with priority=1 and install_weak_deps=False in the bash script: Keep in mind that you don't have to look for the copr repo.

adw-gtk3, aquamarine, glaze, hyprcursor, hyprgraphics, hyprland-git, hyprland-guitils, hyprland-protocols, hyprland-qt-support, hyprlang, hyprpwcen, hyprshutdown, hyprtoolkit, hyprutils, hyprwayland-scanner, hyprwire, noctalia-git, nwg-displays, nwg-look, pyprland, qt6ct, xcur2png, xdg-desktop-portal-hyprland

→ Resolved (2026-10-20): Created `build_files/packages/install-base-pkgs`, wired into dedicated RUN layer in Containerfile, verified via `verify base-pkgs`.

- [x] In an appropriate location in the Containerfile as a bash script, install the following packages from aahsnr-work/applications copr repo with priority=1 and install_weak_deps=False in the bash script: Keep in mind that you don't have to look for the copr repo. Also keep in mind that bees is an important package and there are several systemd services that at depend on it so the placement and installation of bees package is very crucial.

antigravity-cli bees bitwarden distroshelf emacs-pgtk ferdium kitty mullvad-vpn obsidian onlyoffice-desktopeditors opencode-desktop private-internet-access proton-vpn-daemon proton-vpn-gtk-app python3-proton-core python3-proton-keyring-linux python3-proton-vpn-api-core ticktick zed zen-browser zotero

→ Resolved (2026-10-20): Created `build_files/packages/install-applications` with dedicated, verified two-step bees installation, removed bees from common-packages, wired into dedicated RUN layer in Containerfile, verified via `verify applications`.

- [x] In an appropriate location in the Containerfile as a bash script, install the following packages from aahsnr-work/texlive-packages copr repo with priority=1 and install_weak_deps=False in the bash script: Keep in mind that you don't have to look for the copr repo.

texlive-basic texlive-bibtexextra texlive-bin texlive-binextra texlive-fontsrecommended texlive-fontutils texlive-formatsextra texlive-humanities texlive-latex texlive-latexextra texlive-latexrecommended texlive-luatex texlive-mathscience texlive-meta texlive-metapost texlive-pictures texlive-plaingeneric texlive-pstricks texlive-publishers texlive-xetex

→ Resolved (2026-10-20): Created `build_files/packages/install-texlive-packages`, wired into dedicated RUN layer in Containerfile, verified via `verify texlive-packages`.

---

- [ ] Make everything as automated as much as possible

---

---

---

# Task: Add four COPR package-installation scripts to the Containerfile

## Role

You are an expert in Fedora/RPM packaging, container image builds (Containerfile semantics, layer caching, bind/cache mounts), and systemd. Your job is to add four self-contained bash scripts to my image build and wire them into the Containerfile in the right places.

## Context

- The image is built from a Containerfile that already exists. Each COPR repository gets its own bash script, run from its own `RUN` instruction.
- Each script must: enable its COPR repo, set `priority=1` on it, install a fixed package list with `install_weak_deps=False`, verify the result, and then **disable** the COPR repo so it is not left enabled in the final image. Disable the repo; do not remove its `.repo` file.
- All four COPR repos (`aahsnr-work/fonts`, `aahsnr-work/base-pkgs`, `aahsnr-work/applications`, `aahsnr-work/texlive-packages`) exist and are reachable. **Do not search for, look up, or verify them.** Use the slugs exactly as written.

## Step 0: Inspect before writing

Read the existing Containerfile and any build scripts first, and identify:

1. The base image and Fedora version.
2. The package manager in use (`dnf5` on Fedora 41+, `dnf`, or `rpm-ostree`). Match it. If nothing is established, assume `dnf5`.
3. How scripts are invoked (COPY + RUN, bind mounts, cache mounts, tmpfs) and the existing naming, numbering, logging and error-handling conventions.
4. Where systemd services are enabled, masked or preset, and where cleanup, `fc-cache`, initramfs, `bootc container lint` or `ostree container commit` steps live.
5. Whether any of the target packages are already installed by earlier layers or conflict with them.

Follow the existing conventions. Do not modify unrelated parts of the Containerfile.

## Global requirements (all four scripts)

- Use `#!/usr/bin/env bash` and `set -euo pipefail`. The build must fail loudly if anything goes wrong.
- Keep each script **self-contained**: it enables its own repo, installs its own packages and disables its own repo. It must not depend on state from another script.
- Hard-code the COPR slug and the derived repo ID at the top. For `owner/project` the repo ID is `copr:copr.fedorainfracloud.org:<owner>:<project>`, and the repo file is `/etc/yum.repos.d/_copr:copr.fedorainfracloud.org:<owner>:<project>.repo`.
- Enable the repo non-interactively (for example `dnf5 -y copr enable <slug>`).
- Set `priority=1` on the COPR repo **before** installing, and verify it took effect on every section of the repo file. Lower numbers win, so same-named Fedora packages must lose to the COPR build.
- Install with weak dependencies disabled via `--setopt=install_weak_deps=False` on the install command itself. Do not change the global dnf configuration. Install each repo's whole package list in a single transaction so dependency resolution is consistent. The one exception is `bees`, described below.
- Do not use `--allowerasing`, `--skip-broken` or `--skip-unavailable`. A missing package or conflict must fail the build instead of producing a partial install. If a real conflict forces a swap or removal, handle it explicitly and call it out in your notes.
- Define package lists as bash arrays, one package per line, using the names **exactly as I wrote them**. Do not rename, drop or "correct" any package. If you suspect a typo, flag it in your notes but leave the name unchanged.
- After installing, verify every requested package with `rpm -q`. The script must exit non-zero if any are missing.
- Disable the COPR repo after installation, and register a `trap ... EXIT` so the repo is also disabled on failure. The disable must be idempotent. After disabling, confirm the repo file shows `enabled=0`.
- Respect the existing cache mounts. Do not add redundant `clean all` steps unless the Containerfile's own pattern includes them. Do not leave stray files in `/tmp`, `/var` or the working directory.
- Add a short header comment to each script (purpose, repo, package list rationale) and brief `echo` progress banners.

## Tasks

- [ ] **1. `aahsnr-work/fonts`**: in an appropriate location in the Containerfile, run a bash script that installs the following with `priority=1` and `install_weak_deps=False`, then disables the repo:
      `google-noto-color-emoji-fonts`, `jetbrains-mono-fonts-all`, `nerd-fonts-jetbrainsmono`, `nerd-fonts-symbols-only`, `nerd-fonts-ubuntu`, `nerd-fonts-ubuntu-mono`
      Run any existing font-cache refresh (`fc-cache`) step after this script, not before.

- [ ] **2. `aahsnr-work/base-pkgs`**: in an appropriate location in the Containerfile, run a bash script that installs the following with `priority=1` and `install_weak_deps=False`, then disables the repo:
      `adw-gtk3`, `aquamarine`, `glaze`, `hyprcursor`, `hyprgraphics`, `hyprland-git`, `hyprland-guitils`, `hyprland-protocols`, `hyprland-qt-support`, `hyprlang`, `hyprpwcen`, `hyprshutdown`, `hyprtoolkit`, `hyprutils`, `hyprwayland-scanner`, `hyprwire`, `noctalia-git`, `nwg-displays`, `nwg-look`, `pyprland`, `qt6ct`, `xcur2png`, `xdg-desktop-portal-hyprland`
      This is the Hyprland stack. Many of these packages also exist in the Fedora repos, so `priority=1` must make the COPR builds win. If the base image already ships stock `hyprland` or related libraries that conflict with `hyprland-git` and friends, resolve that explicitly in the same transaction and document it.

- [ ] **3. `aahsnr-work/applications`**: in an appropriate location in the Containerfile, run a bash script that installs the following with `priority=1` and `install_weak_deps=False`, then disables the repo:
      `antigravity-cli`, `bees`, `bitwarden`, `distroshelf`, `emacs-pgtk`, `ferdium`, `kitty`, `mullvad-vpn`, `obsidian`, `onlyoffice-desktopeditors`, `opencode-desktop`, `private-internet-access`, `proton-vpn-daemon`, `proton-vpn-gtk-app`, `python3-proton-core`, `python3-proton-keyring-linux`, `python3-proton-vpn-api-core`, `ticktick`, `zed`, `zen-browser`, `zotero`
      **`bees` is critical.** Several systemd services depend on it, so both its placement and its installation need special care (see "Handling `bees`" below).

- [ ] **4. `aahsnr-work/texlive-packages`**: in an appropriate location in the Containerfile, run a bash script that installs the following with `priority=1` and `install_weak_deps=False`, then disables the repo:
      `texlive-basic`, `texlive-bibtexextra`, `texlive-bin`, `texlive-binextra`, `texlive-fontsrecommended`, `texlive-fontutils`, `texlive-formatsextra`, `texlive-humanities`, `texlive-latex`, `texlive-latexextra`, `texlive-latexrecommended`, `texlive-luatex`, `texlive-mathscience`, `texlive-meta`, `texlive-metapost`, `texlive-pictures`, `texlive-plaingeneric`, `texlive-pstricks`, `texlive-publishers`, `texlive-xetex`
      This is a large transaction. Give it its own `RUN` layer so it caches independently. Since weak dependencies are off, make sure nothing is silently missing that TeX Live needs at runtime, and flag it if so.

## Placement rules (where each `RUN` goes)

Choose locations that satisfy all of these, and justify the final order in a short note:

1. Dependency order: anything another layer needs is installed first, and each script's packages are installed before any step that configures, enables or validates them.
2. **Every step that enables, presets, masks, drops in overrides for, or validates a systemd service that depends on `bees` must come after the applications script.** This includes `systemctl enable/preset/mask`, `systemd-analyze verify`, and `COPY` of unit files or drop-ins.
3. Layer-cache efficiency: put rarely changing, heavy layers (TeX Live) earlier, and frequently changing ones later, as long as rules 1 and 2 still hold.
4. Every script comes before final-stage steps such as cleanup, `fc-cache`, initramfs generation, `bootc container lint` and `ostree container commit`.
5. Each script gets its own `RUN`, so each COPR repo is enabled and disabled within a single layer.

## Handling `bees`

- Inside the applications script, install `bees` **first, in its own dedicated `dnf` transaction** with the same priority and weak-deps settings. Then install the remaining applications in a second transaction while the repo is still enabled. A failure in `bees` then surfaces immediately and is not hidden inside a large transaction.
- After installing, assert that `bees` is installed (`rpm -q bees`) and that the systemd unit files it ships exist. Derive the paths from `rpm -ql bees` instead of hard-coding them, and fail the build if no unit files are found.
- Because weak dependencies are disabled, check what `bees` only _recommends_ (for example `dnf5 repoquery --recommends bees`). If any of those are required for the dependent services to work, install them explicitly in the same script with a comment explaining why. Otherwise just report them.
- Do not enable, start or configure `bees` services in this script unless the existing Containerfile already does that here. Service enablement belongs in the existing enablement step, which must run later (placement rule 2).
- Make sure no later layer can remove `bees` (for example through a cleanup or `dnf remove` step).

## Reference pattern (illustrative; adapt and verify against the package manager version in the base image)

```bash
#!/usr/bin/env bash
# Install packages from the aahsnr-work/fonts COPR (priority=1, no weak deps),
# then disable the repo.
set -euo pipefail

COPR_REPO="aahsnr-work/fonts"
COPR_REPO_ID="copr:copr.fedorainfracloud.org:aahsnr-work:fonts"
REPO_FILE="/etc/yum.repos.d/_${COPR_REPO_ID}.repo"

PACKAGES=(
    google-noto-color-emoji-fonts
    jetbrains-mono-fonts-all
    nerd-fonts-jetbrainsmono
    nerd-fonts-symbols-only
    nerd-fonts-ubuntu
    nerd-fonts-ubuntu-mono
)

disable_copr() {
    dnf5 -y copr disable "${COPR_REPO}" || true
}
trap disable_copr EXIT   # never leave the repo enabled, even on failure

echo ">>> Enabling ${COPR_REPO}"
dnf5 -y copr enable "${COPR_REPO}"

# Set priority=1 in every section of the repo file
if grep -q '^priority=' "${REPO_FILE}"; then
    sed -i 's/^priority=.*/priority=1/' "${REPO_FILE}"
else
    sed -i '/^enabled=/a priority=1' "${REPO_FILE}"
fi
grep -q '^priority=1$' "${REPO_FILE}"

echo ">>> Installing packages"
dnf5 -y install --setopt=install_weak_deps=False "${PACKAGES[@]}"

echo ">>> Verifying"
rpm -q "${PACKAGES[@]}"

echo ">>> Disabling ${COPR_REPO}"
disable_copr
trap - EXIT
grep -q '^enabled=0' "${REPO_FILE}"
```

## Edge cases to check and report

- **`/opt` on ostree/bootc-based images:** if the base image is ostree/bootc-based, `/opt` is typically a symlink to `/var/opt`, and anything an RPM installs there will not persist from the image. Several applications here (for example bitwarden, obsidian, ticktick, zen-browser, ferdium, onlyoffice-desktopeditors, mullvad-vpn, private-internet-access) may install under `/opt`. Check what the Containerfile already does about this and follow that convention. If there is none, flag the problem and propose a fix (such as relocating to `/usr/lib/opt` with `tmpfiles.d` entries) instead of silently ignoring it.
- **Same-named packages installed from another repo in an earlier layer:** confirm the COPR build is what ends up installed, for example via the "From repository" field of `dnf5 info <pkg>`, and log it.
- **RPM scriptlets that call `systemctl`, `useradd` or similar inside a container build:** report any that fail or warn.
- **Missing, renamed or possibly misspelled packages:** report them, including `hyprpwcen`, without changing the list.

## Acceptance checklist

- [ ] Four separate bash scripts exist, one per COPR repo, each self-contained and executable (or invoked via `bash`).
- [ ] Each script enables its repo, sets and verifies `priority=1`, installs with `install_weak_deps=False`, verifies every package with `rpm -q`, disables the repo, and confirms `enabled=0`.
- [ ] Package lists match mine exactly, with no additions, removals or renames.
- [ ] `bees` is installed first, in its own transaction, before any dependent service is enabled or configured, and its unit files are asserted to exist.
- [ ] No `--allowerasing`, `--skip-broken` or `--skip-unavailable` is used, except a clearly documented and justified exception.
- [ ] Each script has its own `RUN` in the Containerfile, matching the existing mount, cache and logging conventions.
- [ ] No COPR repo remains enabled in the final image, and there are no leftover temporary files.
- [ ] Nothing unrelated in the Containerfile was changed.

## Deliverables

1. The complete contents of the four bash scripts (not fragments), with suggested file names that follow the repo's convention.
2. The exact Containerfile changes (the new `RUN` blocks and where they go), shown as a diff or clearly marked snippets.
3. A short notes section covering: assumptions made (package manager, Fedora version, atomic vs. non-atomic), the justification for the chosen order, the `bees` handling, and any conflicts, typos or risks found under "Edge cases".

Do not search the web for the COPR repos or their packages.

---

---

---

# Task: Add four COPR package-install scripts to the Containerfile

## Context

- Each COPR repo gets its own bash script, run from its own `RUN` instruction in the existing Containerfile.
- Each script must: enable its COPR repo, set `priority=1`, install its packages with `install_weak_deps=False`, verify the install, and then **disable** the COPR repo.
- The COPR repos exist and are reachable. **Do not search for or verify them.** Use the slugs exactly as written.

## Before writing anything

Read the existing Containerfile and build scripts. Identify the base image, the package manager (`dnf5`, `dnf` or `rpm-ostree`; assume `dnf5` if unclear), and how scripts are invoked (COPY + RUN, bind mounts, cache mounts). Also find where systemd services are enabled and where cleanup or `fc-cache` steps happen. Follow the existing conventions and do not change unrelated parts.

## Rules for every script

- Use `#!/usr/bin/env bash` and `set -euo pipefail`.
- Keep each script self-contained, with no dependence on the other scripts.
- Enable the repo non-interactively, then set `priority=1` in its repo file and verify it took effect.
- Install with `--setopt=install_weak_deps=False` on the install command itself, in a single transaction (except `bees`, see below).
- Do not use `--allowerasing`, `--skip-broken` or `--skip-unavailable`. A missing package or conflict must fail the build.
- Write the package list as a bash array using the names **exactly as I wrote them**. Do not rename, add or drop anything. If a name looks like a typo, flag it in your notes but leave it unchanged.
- Verify every package with `rpm -q` after installing.
- Disable the repo after installing (do not delete the `.repo` file). Use a `trap ... EXIT` so it is also disabled if the script fails, and confirm `enabled=0` at the end.
- Add a short header comment and simple `echo` progress messages.

## Tasks

- [ ] **1. `aahsnr-work/fonts`**: install:
      `google-noto-color-emoji-fonts`, `jetbrains-mono-fonts-all`, `nerd-fonts-jetbrainsmono`, `nerd-fonts-symbols-only`, `nerd-fonts-ubuntu`, `nerd-fonts-ubuntu-mono`
      Any existing `fc-cache` step must run after this script.

- [ ] **2. `aahsnr-work/base-pkgs`**: install:
      `adw-gtk3`, `aquamarine`, `glaze`, `hyprcursor`, `hyprgraphics`, `hyprland-git`, `hyprland-guitils`, `hyprland-protocols`, `hyprland-qt-support`, `hyprlang`, `hyprpwcen`, `hyprshutdown`, `hyprtoolkit`, `hyprutils`, `hyprwayland-scanner`, `hyprwire`, `noctalia-git`, `nwg-displays`, `nwg-look`, `pyprland`, `qt6ct`, `xcur2png`, `xdg-desktop-portal-hyprland`
      Many of these also exist in the Fedora repos, so `priority=1` must make the COPR versions win. If the base image already ships a conflicting stock Hyprland package, handle it explicitly and document it.

- [ ] **3. `aahsnr-work/applications`**: install:
      `antigravity-cli`, `bees`, `bitwarden`, `distroshelf`, `emacs-pgtk`, `ferdium`, `kitty`, `mullvad-vpn`, `obsidian`, `onlyoffice-desktopeditors`, `opencode-desktop`, `private-internet-access`, `proton-vpn-daemon`, `proton-vpn-gtk-app`, `python3-proton-core`, `python3-proton-keyring-linux`, `python3-proton-vpn-api-core`, `ticktick`, `zed`, `zen-browser`, `zotero`

- [ ] **4. `aahsnr-work/texlive-packages`**: install:
      `texlive-basic`, `texlive-bibtexextra`, `texlive-bin`, `texlive-binextra`, `texlive-fontsrecommended`, `texlive-fontutils`, `texlive-formatsextra`, `texlive-humanities`, `texlive-latex`, `texlive-latexextra`, `texlive-latexrecommended`, `texlive-luatex`, `texlive-mathscience`, `texlive-meta`, `texlive-metapost`, `texlive-pictures`, `texlive-plaingeneric`, `texlive-pstricks`, `texlive-publishers`, `texlive-xetex`
      This is a large transaction, so give it its own `RUN` layer. Because weak dependencies are off, flag anything TeX Live needs at runtime that ends up missing.

## Handling `bees` (critical)

Several systemd services depend on `bees`, so:

- In the applications script, install `bees` **first, in its own transaction**, then install the remaining packages in a second transaction while the repo is still enabled.
- After installing, confirm `rpm -q bees` succeeds and that its systemd unit files exist (find them with `rpm -ql bees`, do not hard-code paths). Fail the build if none are found.
- Check what `bees` recommends (for example `dnf5 repoquery --recommends bees`). If any of it is needed for the dependent services to work, install it explicitly with a comment explaining why. Otherwise just report it.
- Do not enable or start `bees` services inside this script. Leave that to the existing service-enablement step.
- Make sure no later layer (cleanup, `dnf remove`) can remove `bees`.

## Where each `RUN` goes

1. Every script runs before any step that enables, presets, masks, configures or validates a service that depends on `bees`, and before any `COPY` of related unit files or drop-ins.
2. Every script runs before the final cleanup, `fc-cache`, initramfs, `bootc container lint` and `ostree container commit` steps.
3. For cache efficiency, put heavy, rarely changing layers (TeX Live) earlier and frequently changing ones later, as long as rules 1 and 2 still hold.
4. Briefly justify the final order.

## Things to check and report

- On ostree/bootc images, `/opt` is usually a symlink to `/var/opt`, so apps that install there (for example bitwarden, obsidian, ticktick, zen-browser, ferdium) may not persist. Follow whatever the Containerfile already does. If nothing is in place, flag it and propose a fix.
- Confirm the COPR build is the one actually installed for packages that also exist in Fedora.
- Report any RPM scriptlet failures or warnings, and any missing or possibly misspelled package names (for example `hyprpwcen`) without changing the list.

## Deliverables

1. The complete contents of all four scripts, with file names that follow the repo's convention.
2. The exact Containerfile changes (new `RUN` blocks and their positions) as a diff or clearly marked snippets.
3. A short notes section covering assumptions, the chosen order, the `bees` handling, and any issues found.

Do not search the web for the COPR repos or their packages.

---

---

---

# Task: Add four COPR install scripts to the Containerfile

## Objective

This is a custom Fedora Atomic (bootc/ostree) desktop image built from a Containerfile. Add **four separate bash scripts**, one per COPR repository, and wire each into the Containerfile at a well-reasoned position. Each script must:

1. Enable its COPR.
2. Install a fixed package list with that COPR at `priority=1` and `install_weak_deps=False`.
3. Disable the COPR again once the install succeeds.

Work in this order: **investigate → plan (show me the plan before editing) → implement → verify → report.**

**Do not search for, browse, or inspect the COPR repos themselves.** The four repos exist and the package names below are authoritative. Do not substitute, rename, add, or drop packages.

## Step 1: Investigate (read-only)

Before planning, determine the following from the repository, not from assumptions:

- The base image and Fedora release, and which package manager the existing build scripts use (`dnf5`, `dnf`, or `rpm-ostree`). Prefer `dnf5` unless the repo clearly does something else, and justify any deviation.
- The existing conventions:
  - script directory and naming or numbering
  - shebang and `set` flags
  - how scripts are invoked from the Containerfile (bind-mounted build context, cache mounts, tmpfs)
  - cleanup steps
  - any `bootc container lint` or CI check
- Every place that already installs, removes, overrides, or configures any package in the lists below. This includes other COPRs, Fedora repos, the Terra repo, AppImage or GitHub-release installs, and Homebrew. Examples: pyprland, obsidian, zed, zen-browser, hyprland-git, noctalia-git, kitty, emacs, texlive-*.
- Every reference to `bees` anywhere in the repo: systemd units, drop-ins, presets, `systemctl enable` calls, ujust recipes, overlay files, and Containerfile steps.
- Any global dnf configuration that already exists.

Verify `dnf5` flag syntax against the official docs (dnf5.readthedocs.io) or by running it. Do not rely on memory for option names.

## Step 2: Script specifications

| Order | COPR                           | Packages                                    |
| ----- | ------------------------------ | ------------------------------------------- |
| 1     | `aahsnr-work/fonts`            | see below                                   |
| 2     | `aahsnr-work/base-pkgs`        | see below                                   |
| 3     | `aahsnr-work/applications`     | see below (**contains `bees`, see Step 4**) |
| 4     | `aahsnr-work/texlive-packages` | see below                                   |

```
# fonts
google-noto-color-emoji-fonts jetbrains-mono-fonts-all nerd-fonts-jetbrainsmono
nerd-fonts-symbols-only nerd-fonts-ubuntu nerd-fonts-ubuntu-mono

# base-pkgs
adw-gtk3 aquamarine glaze hyprcursor hyprgraphics hyprland-git hyprland-guitils
hyprland-protocols hyprland-qt-support hyprlang hyprpwcen hyprshutdown hyprtoolkit
hyprutils hyprwayland-scanner hyprwire noctalia-git nwg-displays nwg-look pyprland
qt6ct xcur2png xdg-desktop-portal-hyprland

# applications
antigravity-cli bees bitwarden distroshelf emacs-pgtk ferdium kitty mullvad-vpn
obsidian onlyoffice-desktopeditors opencode-desktop private-internet-access
proton-vpn-daemon proton-vpn-gtk-app python3-proton-core python3-proton-keyring-linux
python3-proton-vpn-api-core ticktick zed zen-browser zotero

# texlive-packages
texlive-basic texlive-bibtexextra texlive-bin texlive-binextra texlive-fontsrecommended
texlive-fontutils texlive-formatsextra texlive-humanities texlive-latex texlive-latexextra
texlive-latexrecommended texlive-luatex texlive-mathscience texlive-meta texlive-metapost
texlive-pictures texlive-plaingeneric texlive-pstricks texlive-publishers texlive-xetex
```

In the scripts, put each package on its own line in a bash array so diffs stay readable. Keep the names exactly as written.

## Step 3: Behavior required of every script

- Start with `#!/usr/bin/bash` and `set -euo pipefail` (add `-x` if that matches existing conventions). Add a short header comment naming the COPR and its purpose.
- **Enable and disable inside the same script and the same `RUN` layer.** A COPR must never remain enabled across layers.
- **Apply `priority=1` and `install_weak_deps=False` only to this install command**, using transient options such as `--setopt=<repo-id>.priority=1` and `--setopt=install_weak_deps=False`.
  - Do not write them into global dnf config, because that would leak into later layers.
  - In dnf, a lower number means higher priority (default 99). `priority=1` therefore makes this COPR's packages shadow same-named packages in all other repos, which is intended.
  - Confirm that `--setopt` accepts COPR repo IDs, which contain dots and colons (e.g. `copr:copr.fedorainfracloud.org:aahsnr-work:fonts`), by testing in a throwaway Fedora container.
  - If it does not, fall back to `dnf5 config-manager setopt`. Note that this writes a persistent override, so state that side effect.
  - As a last resort, edit the repo file. Report which method you used and why.
- Confirm the exact repo ID after enabling instead of assuming it. Fail fast with a clear error if it is not found.
- If `dnf5 copr` needs `dnf5-plugins` and it is not in the base image, install it.
- Install the whole list in one transaction per script (with the `bees` exception in Step 4).
- **Never hide a failure.** Do not use `--skip-unavailable`, `--skip-broken`, `--allowerasing`, `--nobest`, or any GPG-check bypass.
  - If dnf reports "No match for argument: X", stop and report it. Do not guess or substitute.
- Disable the COPR only after a successful install. Then verify that the repo state is `disabled` and that the `.repo` file under `/etc/yum.repos.d/` has `enabled=0`.
- Verify post-install that every requested package is present (`rpm -q`). Where dnf5 exposes it (e.g. `dnf5 info --installed`, "From repository"), also verify that each package came from the intended COPR and not silently from a Fedora repo.
- Do not run `dnf clean`, `ostree`, or `bootc` commands inside these scripts unless existing conventions require it. Reuse the Containerfile's existing cleanup.

Reference skeleton. Adapt it to the repo's conventions and the verified syntax:

```bash
#!/usr/bin/bash
set -euo pipefail

COPR_PROJECT="aahsnr-work/fonts"
COPR_REPO_ID="copr:copr.fedorainfracloud.org:aahsnr-work:fonts"   # confirm after enable

PACKAGES=(
  google-noto-color-emoji-fonts
  # ...one per line
)

dnf5 -y copr enable "${COPR_PROJECT}"

# grep without -q: avoids SIGPIPE failures under pipefail
repo_state="$(dnf5 repo list --all | grep -F "${COPR_REPO_ID}" || true)"
[[ -n "${repo_state}" ]] || { echo "ERROR: repo ${COPR_REPO_ID} not found" >&2; exit 1; }

dnf5 -y install \
  --setopt="${COPR_REPO_ID}.priority=1" \
  --setopt=install_weak_deps=False \
  "${PACKAGES[@]}"

dnf5 -y copr disable "${COPR_PROJECT}"

repo_state="$(dnf5 repo list --all | grep -F "${COPR_REPO_ID}" || true)"
[[ "${repo_state}" == *disabled* ]] || { echo "ERROR: ${COPR_REPO_ID} still enabled" >&2; exit 1; }

rpm -q "${PACKAGES[@]}" >/dev/null
```

## Step 4: Placement in the Containerfile

- Give each script its own `RUN` instruction, invoked the same way the existing scripts are. Make sure the script is executable (and the mode is committed) or call it via `bash`.
- Every script runs **after** base system updates and general repo setup, and **before** any step that configures, enables, masks, presets, or overlays things belonging to the installed packages. Examples: `systemctl enable/preset`, dconf or skel defaults, the display-manager setup, ujust recipes, `/etc` overlays.
- Default relative order is fonts → base-pkgs → applications → texlive.
  - Each COPR is disabled after its own script, so a later COPR can only depend on packages from an earlier COPR if those were already installed.
  - If a transaction reports an unsatisfied dependency provided by another of these COPRs, reorder the scripts. Do not re-enable an earlier COPR inside a later script. Report the reorder.
- Explain each placement decision in the final report in one or two sentences.

### `bees` (critical)

Several systemd services depend on `bees`, so its installation and placement are the highest-risk part of this task.

1. In the `applications` script, install `bees` in its **own dedicated `dnf5 install` command first**, with the same `priority=1` and `install_weak_deps=False` options. Then install the remaining packages in a second command, without repeating `bees`. Confirm that `bees` came from this COPR and not from Fedora.
2. Right after that first install, verify the following. Fail the build if any check fails.
   - `rpm -q bees` succeeds.
   - The binary and unit files it ships exist (discover them with `rpm -ql bees`).
3. Map every existing dependency on `bees` found in Step 1. Place the `applications` script **before** every step that enables, presets, overrides (drop-ins), or otherwise references `bees` units.
4. Ensure no later step removes, downgrades, or replaces `bees`. This includes `dnf remove` or swap steps, cleanup scripts that delete unit directories, and any other repo or COPR that could provide a same-named package.
5. Check whether the package ships anything under `/var`. If it does, handle it per the atomic-filesystem notes below.
6. Do not enable instance-specific units such as `bees@<UUID>.service` at build time, and do not weaken any existing `Requires=` or `After=` relationship. If an existing unit expects something the package does not provide, report it. Do not paper over it.

## Step 5: Reconcile duplicates and conflicts

For any package in the four lists that another part of the build already installs by other means, report it. If the existing install is directly superseded by this task, remove it and list what you removed. Examples: an older COPR, the Terra repo, an AppImage or GitHub-release install, or `texlive-medium`. If it is ambiguous, leave it in place and flag it for me. Also flag any other COPR or repo-enable step that this change makes redundant.

## Step 6: Atomic/bootc filesystem checks

Use `rpm -qlp` or `rpm -ql` on the installed packages to check for files under `/opt` or `/var`. Several of these applications (the VPN clients, desktop apps) commonly install under `/opt`.

- If the Containerfile already has an optfix-style mechanism (e.g. `/var/opt` handling or relocation to `/usr/lib/opt` plus tmpfiles.d), make sure the new installs go through it.
- If an install would fail without such handling, add the minimal fix that matches existing conventions and report it.
- Otherwise, only report what you found.

## Step 7: Verification

Report each result explicitly as **verified by running** or **verified by reading docs only**. Do not claim a successful build unless one actually ran.

- Run `shellcheck` and `bash -n` on each script, and lint the Containerfile if the repo has a linter configured.
- If a container runtime and network are available, test the scripts in a throwaway container from the same base image (or run a real image build). Confirm the install succeeds, the COPR ends up disabled, `priority=1` and `install_weak_deps=False` took effect, and the `bees` checks pass.
- If the repo uses `bootc container lint`, run it and report any new warnings.
- If you cannot build or test, say so and list what remains unverified.

## Out of scope

- Do not enable, disable, mask, or configure any service.
- Do not change non-COPR parts of the build beyond what the steps above require.
- Do not add packages or COPRs beyond the four lists.
- If any package ships systemd units you think I should decide on, list them in the report.

## Deliverables

1. The four scripts, in the correct directory with executable permissions.
2. The Containerfile edits, shown as a diff.
3. A concise report covering:
   - the placement rationale and the `bees` findings: every dependent unit found, and the ordering that protects it
   - duplicates or conflicts found and what you did about them
   - the `--setopt` method used
   - verification results, with the verified-by-running vs docs-only distinction
   - open questions or risks

### Acceptance checklist

- [ ] Four scripts, one per COPR, each in its own `RUN` layer
- [ ] Each COPR enabled, used with `priority=1` and `install_weak_deps=False`, then disabled in the same layer
- [ ] Package lists exactly as specified, with no substitutions or skip flags
- [ ] `bees` is installed in a dedicated, verified step, placed before everything that depends on it, and nothing later removes or replaces it
- [ ] No leftover global dnf config changes (or any persistent override is explicitly reported)
- [ ] Duplicates and conflicts reconciled or flagged
- [ ] `/opt` and `/var` handling checked
- [ ] Verification results reported honestly
