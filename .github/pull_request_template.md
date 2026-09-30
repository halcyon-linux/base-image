## halcyon — lean Hyprland gaming desktop on fedora-bootc

Read `AGENTS.md` first — it documents the build architecture rules (module
order, overlay semantics, gate conventions).

Changes under `recipes/` or `files/` cost a full ~40-minute CI build —
double-check package names with `dnf5 repoquery` before adding any
(`dnf5` aborts the whole transaction on one bad name).

Run locally before pushing:

```bash
bluebuild validate recipes/halcyon.yml
bash -n files/scripts/*.sh && shellcheck -x files/scripts/*.sh
```

Use a Conventional-Commits PR title (enforced by `semantic-pr.yml`).

- [ ] `bluebuild validate` and `shellcheck` pass locally
- [ ] Every new verify gate was inverted once and confirmed to fail
- [ ] New install stage has a `verify-<stage>.sh` companion wired into its module file
- [ ] Third-party repos are consumed inside their module window (`cleanup: true`)
- [ ] Nothing new lands in `/var`, `/usr/etc`, `/usr/local` or `/boot`
- [ ] New files in `usr/bin` / `usr/libexec` are mode 0755 (exec bits come from git)
- [ ] Workflow changes: no `@main`/`@master` pins, no `ubuntu-latest`
- [ ] Comments explaining _why_ are preserved
