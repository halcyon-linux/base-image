*Updates are staged, not live.* `ujust update` fetches the next image; reboot to apply it — the banner tells you when one is waiting.
*Broke something?* `brh` walks you through rolling back to an older deployment or rebasing.
*The kernel and the NVIDIA driver are pinned together.* If `uname -r` surprises you after an update, they moved as one.
*Keep the image clean.* Apps go in Flatpak, Nix, Distrobox, or containers — layered packages can pin your deployment.
*Root is Btrfs with zstd compression and bees dedup.* `compsize` measures what they save.
*Tailscale is built in.* `sudo tailscale up` joins your tailnet; `tailscale status` lists your machines.
*Snapper and Btrfs Assistant are installed* if you want snapshots before risky changes.
*Everything about this image is public.* `ujust verify-image` checks your deployment's signing status; Halcyon images report no action needed.
