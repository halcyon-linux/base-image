# TODOs

Open work first; resolved questions are one-liners, full detail in `git log -p TODO.md`.

## Open

- [x] fzf from fedora repo may have been installed. Remove it and install it from my copr repo (10-20)
- [x] Remove certain kmods and handheld stuff. (10-20)
- [x] Setup gui pinentry using pinentry-tty and/or pinentry-curses (10-20)
- [x] Make everything as automated as much as possible: dynamic upstream ogc kernel resolution from ublue-os/bazzite with fallback to pinned version; automated candidate akmods tag presence check on ghcr plus a payload check that the device kmod is really published in the akmods-extra image; unpinned brew:latest in Containerfile with configurable BREW_IMAGE; parameterised AKMODS_TAG in Containerfile. (10-20)
- [x] TeX Live must work — the COPR ships no %post scriptlets, so the image bakes the formats itself (ls-R rebuild, hyphenation trim, updmap/fmtutil) and `verify texlive-packages` gates the baked `pdflatex`/`lualatex` formats. (10-20)
- [x] Visible GRUB menu — `configure-grub` sets `GRUB_TIMEOUT=10` / `GRUB_TIMEOUT_STYLE=menu` in `/etc/default/grub`; `verify grub` gates it. (10-20)
- [x] Missing utilities and toolchains — git, grim/slurp/imv/swappy, zathura*, pipx, fail2ban, lynis, setools-console, udiskie, file-roller, transmission-gtk, igt-gpu-tools, brightnessctl, bleachbit, cronie, inotify-tools, ninja-build, pymol, xdg-user-dirs-gtk, setroubleshoot, direnv, ripgrep, plus nodejs22/cargo/cmake/golang; `neovim` added so the `EDITOR=nvim` default resolves. (10-20)

- [ ] Switch to uwsm and systemd user units
- [ ] Determine what toggle automatically mounting disks do and what systemd service is responsible for this

## Resolved

### Image and tooling

- [x] Podman-only? Yes — helpers use `podman`/`podman-remote`; CI uses buildah, podman, skopeo, cosign. `docker://` is only the OCI transport and `~/.docker/config.json` only cosign's auth file; no Docker Engine dependency. (10-18)
- [x] Only one custom image? Yes — `alcyone` (was `bazzfin-nvidia`) is the only image on this branch; `akmods*`/`brew`/`ctx` are build inputs, not outputs. The project also publishes `ceyx` (BlueBuild, `bluebuild` branch); `os-release` reports `NAME=Halcyon` on both. (10-18/19)
- [x] `usr/bin` vs `usr/libexec` — `/usr/bin` is the user-facing PATH, `/usr/libexec` holds helpers called by units, ujust recipes and polkit. `system_files/desktop/usr/bin` is intentionally empty: user commands come from RPMs (`brh`, `bruh`, `crh`, `gameclass`, `bbrew-helper`, `ublue-motd`, `uupd-update`); `dlss-swapper` is user-facing too, now provided by its RPM. (10-18)
- [x] Unneeded in-tree scripts — all `usr/bin` scripts removed (incl. `copr`); dangling refs (Steam wrapper in `configure-desktop-integration`, `bazzite-steam-bpm.desktop`, `setup-boot-windows-steam` recipe + yafti entry, `fix-reset-steam` relaunch) cleaned. (10-18)
- [x] `bazzite-fork` branch — this is the `containerfile` branch, which builds `alcyone`. (10-18)
- [x] Vendor developer tools & browsers — `code` (Microsoft), `codium` (Paul Carroty), `brave-browser` (Brave), `firefox` (Fedora), `google-chrome-stable` (Google), `microsoft-edge-stable` (Microsoft Edge), `vivaldi-stable` (Vivaldi) integrated into `install-applications` with strict priority=1, weak deps off, and immediate repository disablement; verified. (10-20)

### Services and units

- [x] Combine `bazzite-hardware-setup` / `bazzite-iwd-migration` / `bazzite-boot-remount`? Done — `bazzite-iwd-migration` deleted (unit + script; iwd not installed, target NetworkManager drop-ins clean); boot-remount and hardware-setup helpers now come from vendor-neutral RPMs, so the old Bazzite-named scripts are not bundled. (10-19)
- [x] `hardware-setup.service` — installs the `hardware-setup` RPM and checks `/usr/bin/hardware-setup`; the local oneshot orders it before user sessions, no in-tree helper script. (10-19)
- [x] `user-setup.service` / `dynamic-fixes.service` — helpers come from the `user-setup` / `dynamic-fixes` RPMs; user units stay globally enabled and `verify final` checks both. (10-19)
- [x] `bazzite-libvirtd-setup.service` — `libvirtd.service` ships in `libvirt-daemon`; the old one-shot was deleted and virtualization is default-on (libvirt/QEMU/swtpm, `virt-manager`, `virt-install`, `libvirtd.service` enabled, KVM kargs via the `hardware-setup` RPM). `ujust setup-virtualization` is the repair/disable path. (10-18)
- [x] `beesd@.timer` — templates ship in the `bees` RPM; the shipped timer (`WantedBy=timers.target`) drives the daily run, `ujust configure-beesd` enables per-filesystem `beesd@<uuid>.timer` instances. Nothing else pulls it in; kept. (10-18)
- [x] `cockpit.service` — cockpit sub-packages installed but not `cockpit-ws`, so no socket unit; the shipped oneshot gates `cockpit-container.service` (Podman Quadlet) with `ExecStart=/usr/bin/true`, toggled by ujust. Kept. (10-18)
- [x] `dev-hugepages1G.mount` — kept; inert unless the kernel cmdline has `hugepagesz=1G`. (10-18)
- [x] `force-wol.service` — removed entirely (unit, `usr/libexec/force-wol`, `configure-system-services` entry, `ujust wol` + `toggle-wol`, yafti action). (10-18)
- [x] `fstrim.service.d` — kept, no changes. (10-18)
- [x] incus — removed `incus-workaround.service`, `tmpfiles.d/incus-workaround.conf`, the `configure-system-services` entry and the `distrobox.ini` download. (10-18)
- [x] `kmod-sleep-workaround@.service` — kept; `kmod` added to `common_packages`, `verify packages` checks `rmmod` + `modprobe`. (10-18)
- [x] `ntfs-nag.service` — removed, plus `ntfs-exfat-monitor-script`, the `configure-system-services` entry and the `_disable-ntfs-service` recipe. (10-18)
- [x] `mesa-git` script — removed with the `usr/bin` purge, along with `89-bazzite-mesa-git.just` and its import. (10-18)
- [x] Waydroid — deferred: not in the image and forbidden by final verification; its Portal entry is removed. No NVIDIA support without revisiting the package policy. (10-18)

### Packages and integration

- [x] fzy must come from the cli-tools COPR — Terra ships a newer fzy release and shadowed the COPR package; the cli-tools install now pushes Terra behind the COPR and `verify cli-tools` asserts the COPR vendor. (10-20)
- [x] Steam must not start on first login — autostart entries in `/etc/skel`, `/etc/xdg` and `/usr/share/autostart` are purged and `verify final` asserts they stay absent. (10-19)
- [x] Merge `install-steam-lutris` + `install-gaming-stack` + mesa-git + protonplus — `install-steam-lutris` removed; `install-gaming-stack` enables `aahsnr-work/gaming` at priority=1, installs `protonplus` (+ `heroic-games-launcher`), then disables the repo; `verify final` asserts the COPR is disabled. mesa-git not installed (kept in the COPR for manual use). (10-19/20)
- [x] chezmoi-init over SSH (10-22) — HTTPS cloning by chezmoi's shorthand default left fresh machines with a password-prompting remote; switched to `chezmoi init --apply --force --ssh`, added `ExecStartPost` pinning `core.sshCommand` (aahsnr-configs key, `IdentitiesOnly`) in the cloned repo, and shipped `/etc/ssh/ssh_config.d/10-halcyon-github.conf` mapping plain `github.com` to that key (the includeIf tree in `~/Git/<account>/` is unaffected since per-account `core.sshCommand` replaces the whole ssh command); verify asserts `--ssh`, the pin and the ssh_config default.
- [x] chezmoi — RPM installed in `install-common-packages`; `chezmoi-init.service` force-applies `aahsnr-configs/dotfiles` at login (retry on failure), `chezmoi-update.timer` pulls updates, units enabled, `ujust dotfiles` for manual sync; verified in build. (10-19)
- [x] Flatpak integration — in bootc system flatpaks live in machine-local `/var/lib/flatpak`, so Containerfile installs do not survive. Done declaratively: Flathub remote file `/etc/flatpak/remotes.d/flathub.flatpakrepo` (embedded key, no build-time network), manifest `/usr/share/ublue-os/flatpak/system-flatpaks.list`, `system-flatpak-setup.service` reconciling declared flatpaks into system storage at boot; verified in build. (10-19)
- [x] Flatpak default policy (supersedes the 10-19 provisioning above) — the image ships **no** flatpak applications: removed the A-026 machinery (`system-flatpaks.list` manifest, `system-flatpak-setup` helper + service, `configure-system-services` entry); only the system Flathub remote remains declared in `/etc/flatpak/remotes.d/flathub.flatpakrepo` and other remote definitions are forbidden in both `remotes.d` dirs; Bazaar stays the dnf-packaged software center (`bazaar` from the `ublue-os:packages` COPR) and `flatpak` stays installed for runtime installs; verify asserts machinery absence, flathub-only remotes, and zero system flatpak apps. Verify updated; build not yet run. (10-22)
- [x] sddm instead of greetd, only base `zsh` — `sddm` + `sddm-wayland-generic` installed, `sddm.service` enabled, `graphical.target` default, `greetd` purged; auxiliary `zsh-*` plugins removed and forbidden, `/etc/skel/.zshrc` sources only the in-tree `zsh-preexec.zsh`; chezmoi guards use `ConditionUser=!sddm`; verified. (10-19)
- [x] What `ublue-os/base-main` pre-packages — distrobox, toolbx, flatpak-spawn, podman, `just` (used by ujust), cosign, RPM Fusion Free/Non-Free, Cisco OpenH264, `ublue-os-udev-rules`, alsa-firmware, ffmpeg (+libs, fdk-aac, thumbnailer), heif-pixbuf-loader, apr(-util), fuse, fzf, grub2-tools-extra, htop (purged), CJK Noto fonts (purged). (10-19)
- [x] Fonts COPR — `build_files/packages/install-fonts` installs the 6 font packages from `aahsnr-work/fonts` at priority=1, weak deps off; `verify fonts`. (10-20)
- [x] Base packages COPR — `build_files/packages/install-base-pkgs` (23 packages from `aahsnr-work/base-pkgs`); `verify base-pkgs`. (10-20)
- [x] Applications COPR — `build_files/packages/install-applications` with a dedicated two-step `bees` install (several units depend on it) and `bees` dropped from common packages; `verify applications`. (10-20)
- [x] TeX Live COPR — `build_files/packages/install-texlive-packages`; `verify texlive-packages`. (10-20)

### Verification

- [x] Strong verification at every build stage — every stage `RUN` calls `/ctx/finalization/verify <stage>` before cleanup; 28 stage checks assert required RPMs, repo states, binaries, unit enablement and forbid-lists, aborting the build on failure. The image ends with `bootc container lint`. (10-19)
