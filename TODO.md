# TODO & Implementation Status

`Important`: All the TODO items below must be done during building the image so that no extra steps are needed for these todo items when I login after rebasing fedora silverblue to my custom image. In other words when I rebase my fedora silverblue installation to my custom image, everything should be ready upon login. Everything should be baked into the custom image.

---

- [x] Add separate build-time verification scripts for all modules in the whole project (verify-<module>.sh per module, wired as trailing script blocks; final-verify.sh + bootc-lint.yml are the no-cache backstop)
- [ ] Disable zram and tmpfs
