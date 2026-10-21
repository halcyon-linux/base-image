# Chezmoi on Halcyon

A simple, practical manual for dotfile management on this image. chezmoi keeps your
home directory's dotfiles in a git-backed **source directory** (`~/.local/share/chezmoi`)
and applies them to `$HOME`. This image installs `chezmoi` as an RPM, wires it into
systemd automation, and uses [`aahsnr-configs/dotfiles`](https://github.com/aahsnr-configs/dotfiles)
as the dotfiles repository.

Official documentation lives at <https://chezmoi.io>; this manual covers the 90% you
need day to day, tuned to how this image behaves.

## 1. What this image sets up

| Component                | When it runs                                  | What it does                                                                                       |
| ------------------------ | --------------------------------------------- | -------------------------------------------------------------------------------------------------- |
| `chezmoi-init.service`   | At login **only if** `~/.local/share/chezmoi/.git` does not exist | `chezmoi init --apply --force aahsnr-configs/dotfiles` — clones the repo, creates the config, applies |
| `chezmoi-update.timer`   | 5 minutes after boot, then daily              | Triggers `chezmoi-update.service`                                                                   |
| `chezmoi-update.service` | On demand (by the timer)                      | `chezmoi update --no-tty --force` — pulls remote commits and applies them                            |
| `ujust dotfiles`         | Manual                                        | Interactive menu: `status` / `sync` / `diff` / `edit`                                                |

The units are part of the image (read-only, under `/usr/lib/systemd/user/`), so don't
edit them — any local change would be overwritten by an image update. They are guarded
so they only run for real human users (not system accounts, not the sddm greeter), and
the update units only fire once the source repository has been initialized.

Inspect the automation:

```bash
systemctl --user list-timers chezmoi-update.timer   # next scheduled update
journalctl --user -u chezmoi-update.service -e      # last update's log
```

## 2. The mental model

```text
~/.local/share/chezmoi        (git clone = "source directory")
        │  chezmoi renders templates / resolves attributes
        ▼
   target state
        │  chezmoi apply: make $HOME match the target state
        ▼
        $HOME
```

Rules that make this model predictable:

- `chezmoi apply` works from the source directory **as it is on disk** — uncommitted,
  unpushed edits count. Git commit state only matters for pulling and pushing.
- `apply` walks **every managed entry** and touches **only the entries that differ**.
  Files chezmoi doesn't manage are never touched.
- chezmoi never commits, pushes, or creates branches for you. Git is yours; chezmoi's
  commands only ever *pull* (`update`, `init`).
- The source and target live under two different name schemes — that's normal
  (see §3).

## 3. Naming translation (source ↔ target)

Files in `~/.local/share/chezmoi` are stored with attribute prefixes. The common ones:

| Source name                    | Target result                                            |
| ------------------------------ | -------------------------------------------------------- |
| `dot_zshrc`                    | `~/.zshrc` (`dot_` → leading dot)                         |
| `dot_config/htop/`             | `~/.config/htop/`                                         |
| `exact_dot_gnupg/`             | `~/.gnupg`, also **removes** files not tracked in source  |
| `private_dot_ssh/`             | `~/.ssh`, group/world permission bits cleared (0600-ish)  |
| `create_dot_zprofile`          | Created **only if missing**; never overwrites             |
| `run_once_00-setup.sh`         | Script, runs at most once per content per machine         |
| `run_onchange_00-setup.sh`     | Script, re-runs whenever its contents change              |
| `run_once_before_x.sh`         | Script ordered **before** file application (`after_` after) |
| `dot_zshrc.tmpl`               | Rendered as a template before being applied               |

Useful helpers that work regardless of attributes: `chezmoi source-path` prints the
source directory; `chezmoi target-path <source-file>` prints where a source file lands
in `$HOME`.

## 4. Daily operations

| Command                          | Direction        | What it does                                                                                      |
| -------------------------------- | ---------------- | ------------------------------------------------------------------------------------------------- |
| `chezmoi status`                 | —                | Quick list of pending changes, git-status style (`M .zshrc` means apply would modify it)           |
| `chezmoi diff`                   | source → `$HOME` | Dry run: exactly what `apply` would change to `$HOME`                                             |
| `chezmoi apply --force`          | source → `$HOME` | Apply; `--force` skips the "file modified at target, proceed?" prompts                            |
| `chezmoi add ~/.zshrc`           | `$HOME` → source | Copy a file into the source state. If already managed, its source contents are **replaced**        |
| `chezmoi re-add`                 | `$HOME` → source | Bulk re-snapshot of every file in `$HOME` that differs from the source (preserves templates/encryption) |
| `chezmoi edit ~/.zshrc`          | —                | Open the **source** copy of `~/.zshrc` in your editor; add `--apply` to apply right after saving   |
| `chezmoi forget ~/.zshrc`        | —                | Stop tracking a file; the file stays in `$HOME` but becomes unmanaged                             |
| `chezmoi remove ~/.zshrc`        | both             | Delete the source entry **and** the file in `$HOME`                                               |
| `chezmoi update --force`         | remote → `$HOME` | `git pull --autostash --rebase` then `apply` — how you receive other machines' pushes              |
| `chezmoi managed` / `unmanaged`  | —                | List files under (or outside) chezmoi's control                                                    |
| `chezmoi cd`                     | —                | Shell into the source directory (handy for git work)                                               |
| `chezmoi git -- commit -m "msg"` | —                | Run any git command in the source dir from anywhere (`--` separates chezmoi flags from git flags)  |
| `chezmoi doctor`                 | —                | Environment health check — run it when something feels off                                         |

The two mirrors you'll use constantly:

```text
source → $HOME : chezmoi diff  →  chezmoi apply --force  →  chezmoi diff (empty = in sync)
$HOME → source : chezmoi add <file>                           (then commit & push)
```

After any apply, `chezmoi diff` should print nothing. An empty diff is your "everything
is in sync" green light; run it before you continue working on anything else.

## 5. Working recipes

### 5.1 You edited files in the source directory but haven't committed/pushed

Since chezmoi applies the working tree as-is, no git work is needed to get your edits
running:

```bash
chezmoi diff                # preview — the habit to keep
chezmoi apply --force       # applies your new source edits to $HOME
chezmoi diff                # should now print nothing
```

Then persist the work so the two-way sync machinery stays happy:

```bash
git -C ~/.local/share/chezmoi add -A
git -C ~/.local/share/chezmoi commit -m "Update dotfiles"
git -C ~/.local/share/chezmoi push
```

Why `apply` and not `update` here? `update` additionally does git pull machinery
(`--autostash --rebase`) aimed at *remote* changes. With purely local edits it works —
your edits get stashed and re-restored around the pull — but it's pointless juggling
that turns into rebase conflicts the moment the remote ever touched the same lines.

Commit and push soon after editing. Your unpushed work lives only in the source
directory, and the daily timer keeps stashing/restoring it around pulls until you do.

### 5.2 You hand-edited a file directly in `$HOME`

```bash
chezmoi diff ~/.zshrc       # confirm that's the only divergence
chezmoi add ~/.zshrc        # snapshot into the source state (dot_zshrc)
git -C ~/.local/share/chezmoi add -A && git -C ~/.local/share/chezmoi commit -m "Update from home edit" && git -C ~/.local/share/chezmoi push
chezmoi re-add              # if you edited several files at once
```

> **Caution — the timer can silently revert this.** The daily timer runs
> `chezmoi update --no-tty --force`. Any manual `$HOME` edit that hasn't been
> `add`ed back into the source gets overwritten at the next automated run. Run
> `chezmoi add` promptly, or better, skip hand-editing `$HOME` entirely and use
> `chezmoi edit ~/.zshrc` + `chezmoi apply --force`.

### 5.3 Receiving changes pushed from another machine

```bash
chezmoi update --force      # or: ujust dotfiles sync
```

This is also what the timer does automatically 5 minutes after boot and daily. On a
brand-new machine the image's `chezmoi-init.service` handles it on first login; to do
it manually: `chezmoi init --apply --force aahsnr-configs/dotfiles`.

### 5.4 Discard local source edits and match the remote exactly

```bash
git -C ~/.local/share/chezmoi restore .
chezmoi update --force      # apply remote state to $HOME
```

Destructive to those local edits, naturally.

### 5.5 Stop managing a file

```bash
chezmoi forget ~/.zshrc     # file survives in $HOME, no longer tracked
chezmoi remove ~/.zshrc     # deletes both source entry and $HOME file
```

(Then commit & push as usual — forgetting/removing are changes to the source state.)

## 6. Gotchas worth knowing

- **First apply is destructive where it's managed, nowhere else.** If `$HOME` already
  has a `.zshrc` that differs from the source, `chezmoi apply --force` overwrites it
  in favor of the source. Unmanaged files are never touched. Always `chezmoi diff`
  first when adopting a dotfiles repo on an existing machine.
- **Manual `$HOME` edits get reverted** by the daily timer unless you `add` them back
  (see §5.2).
- **Update conflicts** mean git rebase/merge conflicts inside the source dir: resolve
  them with git (`chezmoi cd`), commit, push, then `chezmoi apply --force`.
- **Deleting `~/.local/share/chezmoi`** is not eternal — next login,
  `chezmoi-init.service` re-clones and force-applies, matching the remote.
- **Secrets**: don't `chezmoi add` a file with plaintext keys/secrets — it goes into
  the git repo verbatim. Use `chezmoi add --encrypt` (age/GPG) or keep secrets in a
  password manager referenced from templates (see chezmoi.io — beyond this manual).
- **chezmoi is not a system manager.** It owns `$HOME` only. Machine-level
  configuration (packages, services, kernel) belongs to this image's build files, not
  to your dotfiles repo. Scripts (`run_*`) are the sanctioned escape hatch.

## 7. The `ujust dotfiles` menu

| Option    | What runs                                        |
| --------- | ------------------------------------------------ |
| `status`  | `chezmoi status` + latest commit in the source dir |
| `sync`    | `chezmoi update --force` (pull + apply)           |
| `diff`    | `chezmoi diff`                                    |
| `edit`    | Opens `~/.local/share/chezmoi` in your `$EDITOR`  |

## 8. Quick cheat sheet

```bash
alias cm='chezmoi'                  # most users' first quality-of-life tweak

cm status                          # pending changes (what apply would touch)
cm diff                            # detailed pending diff vs $HOME
cm apply --force                   # make $HOME match the source
cm diff                            # empty → in sync

cm add ~/.zshrc                    # track/update a file from $HOME
cm re-add                          # bulk snapshot edited $HOME files
cm chattr template ~/.zshrc        # toggle attributes (template, private, …)

cm edit ~/.zshrc                   # edit the managed source copy
cm edit --apply ~/.zshrc           # …and apply on save (files only)

cm update --force                  # pull remote commits + apply
cm managed                         # everything chezmoi tracks
cm doctor                          # health check

cm cd                              # shell in the source dir for git work
cm git -- commit -m "Update"       # git passthrough from anywhere
cm source-path                     # print the source directory

# Periodic sanity checks
systemctl --user list-timers chezmoi-update.timer
journalctl --user -u chezmoi-update.service -e
```

## 9. Going further

- **Templates** — any `*.tmpl` file is rendered; e.g. machine-specific bits:
  `{{ if eq .chezmoi.hostname "alcyone" }}export EDITOR=nano{{ end }}`
- **Variable data** — define `data` in `~/.config/chezmoi/chezmoi.toml`
  (edit with `chezmoi edit-config`) for templates to use.
- **`.chezmoiignore`** — patterns of files (per machine) that chezmoi should leave alone.
- **Scripts** — `run_once_`/`run_onchange_` scripts (§3) for package installs and other
  imperative setup, applied on every `apply` in alphabetical order.
- **Encryption** — `chezmoi add --encrypt` with age/GPG for private material.
- Official user guide: <https://chezmoi.io/user-guide/>; command reference:
  <https://chezmoi.io/reference/>.
