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

→ Resolved (2026-10-18): not combined. `bazzite-iwd-migration` is deleted (unit + script): iwd is not installed in this image and the target machine's NetworkManager drop-ins are already clean. `bazzite-boot-remount` is a sourced function library (no unit) and stays as-is. `bazzite-hardware-setup` keeps its own unit; its rewrite is separate.

[To understand the system systemd services, look at /usr/libexec/ binaries]:

1. `Important:` bazzite-hardware-setup.service -> bazzite-hardware-setup bash script needs a lot of changes using to finished files [NOTE: Only complete it after every file is finalized]

→ Resolved (2026-10-18): rewrote with helper functions and `set -Eeuo pipefail`. Kept the karg handling (bluetooth.disable_ertm append, nomodeset delete, reboot-if-changed) and the distrobox hostname/`/etc/hostname` fix; dropped the zram `vm.min_free_kbytes` tweak and the inert Waydroid apparmor cleanup. The state gate is bumped to `HWS_VER=80` (later 81, for the KVM kargs — see item 3) so existing installs re-run.

2. `Important` bazzite-iwd-migration.service -> bazzite-iwd-migration [NOTE:] Needs to be understand 1st or if even needed since NetworkManager is to be used. → RESOLVED (2026-10-18): both deleted; NetworkManager uses wpa_supplicant here and nothing in the image re-creates the iwd drop-ins.

3. For `bazzite-libvirtd-setup.service` where does libvirtd service exist?

→ Resolved (2026-10-18): `libvirtd.service` ships in the `libvirt-daemon` RPM. Follow-up same day: virtualization is now enabled by default — the libvirt/QEMU/swtpm stack, `virt-manager`, and `virt-install` ship in the image, `libvirtd.service` is enabled at build time, KVM kargs are applied by `bazzite-hardware-setup`, and the old `bazzite-libvirtd-setup.service` one-shot (which only queued the enable for the next boot after a runtime `rpm-ostree install`) was deleted. `ujust setup-virtualization` remains as the repair/disable path.

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

11. `Important`: For `bazzite-dynamic-fixes.service` systemd user service, bazzite-dynamic-fixes bash script is needed.

→ Resolved (2026-10-18): restored `usr/libexec/bazzite-dynamic-fixes`; the user unit remains enabled globally.

12. `Important`: For `bazzite-user-setup.service`, bazzite-user-setup bash script is needed.

→ Resolved (2026-10-18): present (`usr/libexec/bazzite-user-setup` + user unit, version-gated); no change needed.

13. `Important`: `ntfs-nag.service` user service cannot exist because ntfs file system will be blacklisted or removed. Similarly, ntfs-exfat-monitor-script is no longer needed.

→ Resolved (2026-10-18): removed `ntfs-nag.service`, `ntfs-exfat-monitor-script`, the `configure-system-services` entry, and the `_disable-ntfs-service` recipe.

14. `Important`: Custom mesa-git script in system_files/desktop/usr/bin not needed since I have my own copr repo

→ Resolved (2026-10-18): the `mesa-git` script was removed with the `usr/bin` purge; also removed `89-bazzite-mesa-git.just` and its import line.

15. add Waydroid nvidia support

---

1. tmpfiles.d/incus-workaround.conf must be removed

→ Resolved (2026-10-18): removed (with item 9 above).

---

---

Unneeded scripts/binaries

1. copr

→ Resolved (2026-10-18): all in-tree `usr/bin` scripts were removed, including `copr`; user-facing commands now come from RPMs. Dangling references (the Steam wrapper block in `configure-desktop-integration`, `bazzite-steam-bpm.desktop`, the `setup-boot-windows-steam` recipe + yafti entry, and the `fix-reset-steam` relaunch) were cleaned too.

- [x] Add bazzite-fork as a branch for base-image with Containerfile as the base image. → Done: this is the `containerfile` branch, which builds `alcyone`.

- [ ] Don't start steam when logging 1st in.
