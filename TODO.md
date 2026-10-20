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
