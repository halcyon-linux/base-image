#!/usr/bin/bash
# Proposed read-only review. No patch application to Halcyon, no network.
set -Eeuo pipefail
umask 077
export PATH=/usr/bin:/bin LC_ALL=C
if [[ $# != 1 || $EUID == 0 ]]; then
  printf 'Usage as ordinary user: bash pi-halcyon-entry184-review-proposed.sh /absolute/path/to/Halcyon-checkout\n' >&2; exit 2
fi
[[ $1 == /* ]] || { printf 'Use an absolute checkout path.\n' >&2; exit 2; }
repo=$(cd -- "$1" && pwd -P)
out=$(pwd -P)
[[ "$out" != "$repo" && "$out" != "$repo/"* ]] || { printf 'Run from a directory outside the checkout.\n' >&2; exit 2; }
report=$(mktemp "$out/pi-halcyon-entry184.XXXXXXXX.txt")
printf 'Report: %s\n' "$report"
exec 3>>"$report"
log(){ printf '%s\n' "$*" >&3; printf '%s\n' "$*"; }
stop(){ log "STOP: $*"; exit 1; }
work=$(mktemp -d /tmp/pi-halcyon-entry184.XXXXXXXX)
trap 'rm -rf -- "$work"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
log 'Entry184: local checkout review only; no apply, build or deployment'
[[ -d "$repo/.git" && ! -L "$repo/.git" ]] || stop 'ordinary Git checkout required; linked worktrees unsupported'
[[ -f "$repo/Containerfile" && ! -L "$repo/Containerfile" && -d "$repo/build_files" && ! -L "$repo/build_files" ]] || stop 'expected regular source paths missing'
[[ $(stat -c %s -- "$repo/Containerfile") -le 2097152 ]] || stop 'Containerfile exceeds size cap'
mkdir -m 700 "$work/home" "$work/tree" "$work/tree/build_files"
# Git only reads local repository metadata and the selected blob, using no user config or tokens.
git_clean(){ /usr/bin/env -i PATH=/usr/bin:/bin LC_ALL=C HOME="$work/home" XDG_CONFIG_HOME="$work/home" GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null GIT_OPTIONAL_LOCKS=0 GIT_TERMINAL_PROMPT=0 GIT_NO_LAZY_FETCH=1 /usr/bin/timeout 30 /usr/bin/git -c core.hooksPath=/dev/null -c core.fsmonitor=false "$@"; }
head=$(git_clean -C "$repo" rev-parse --verify HEAD 2>/dev/null) || stop 'cannot determine local HEAD'
[[ $head =~ ^[0-9a-f]{40}$ ]] || stop 'unexpected commit identifier'
log "head=$head"
[[ $head == 9c7b9798b4024253f085f33d65933158373f322f ]] && log 'pinned_candidate_revision=match' || log 'pinned_candidate_revision=different; review required'
blob_size=$(git_clean -C "$repo" cat-file -s HEAD:Containerfile 2>/dev/null) || stop 'HEAD Containerfile unavailable'
[[ $blob_size =~ ^[0-9]+$ && $blob_size -le 2097152 ]] || stop 'unexpected HEAD blob size'
git_clean -C "$repo" cat-file blob HEAD:Containerfile >"$work/head-containerfile" 2>/dev/null || stop 'HEAD Containerfile blob unavailable'
cp -- "$repo/Containerfile" "$work/tree/Containerfile"
[[ $(stat -c %s "$work/tree/Containerfile") -le 2097152 ]] || stop 'snapshot exceeds cap'
log "containerfile_sha256=$(sha256sum "$work/tree/Containerfile" | cut -d' ' -f1)"
cmp -s "$work/head-containerfile" "$work/tree/Containerfile" || stop 'working Containerfile differs from HEAD; no patch check'
log 'containerfile_matches_head=yes'
if [[ -e "$repo/build_files/pi-security" || -L "$repo/build_files/pi-security" ]]; then
  [[ -d "$repo/build_files/pi-security" && ! -L "$repo/build_files/pi-security" ]] || stop 'pi-security ancestor not a regular directory'
fi
[[ ! -e "$repo/build_files/pi-security/entry183" && ! -L "$repo/build_files/pi-security/entry183" ]] || stop 'candidate path collision'
log 'candidate_payload_path_absent=yes'
count=$(grep -Fxc '    /ctx/packages/install-system-integration-files && \' "$work/tree/Containerfile" || true)
[[ $count == 1 ]] || stop 'integration hook is not unique'
log 'integration_hook_unique=yes'
cat >"$work/add.patch" <<'ENTRY183_ADD_PATCH'
diff --git a/build_files/pi-security/entry183/README.md b/build_files/pi-security/entry183/README.md
new file mode 100644
index 0000000..022890c
--- /dev/null
+++ b/build_files/pi-security/entry183/README.md
@@ -0,0 +1,7 @@
+# Entry183 — inert build payload candidate
+
+This add-only patch does not modify Containerfile, an enablement list, sysusers, tmpfiles, existing state, or any real installation. It is NOT an install or activation patch. Do not apply, build, deploy, or run it. A separately proposed integration hunk is based on a later recovered pinned source excerpt, not the full repository. Proposed repository paths are illustrative and must be checked against the target revision. No privileged helper or independent operator channel is implemented here.
+
+Proposed future mapping, only after review and separate authorization: the service file to `/usr/lib/systemd/system/pi-entry183-synthetic.service`, and the profile, probe, three text markers and admission intent JSON to `/usr/share/pi-security/entry183/`. Root:root 0755 directory; regular files root:root 0644 (the Bash fixture is invoked through `/usr/bin/bash`, no executable mode required); no ACL grant to desktop/author, no symlinks/hard links, no pre-existing target replacement. Verify effective SELinux labels, immutable source and `/etc` overrides. Do not provision the absent activation sentinel; it is an inert safety condition, not an approval mechanism. A future reviewed delta would remove both startup inhibits only after independent approval and preflight; no enablement or automatic dependency may be added. No existing assets or identities modified. State is only a proposed fresh `/run/pi-entry183-synthetic` runtime directory, not persistent storage. Before activation verify that directory is absent, preventing systemd from recursively fixing ownership of existing content. No host commands in this document.
+
+The synthetic Bash fixture is not a protected admission verifier, approval controller or credential broker. It tests only fixed synthetic markers and a child shell; no OpenCode, Pi, real credentials, direct network probes or real home paths. It expects previously observed Nono continuity digest, checks static UID/GID, requires a fresh runtime directory and uses a sanitized environment for Nono. The Nono profile shape follows earlier reviewed synthetic examples, but narrow library grants, implicit profile grants, namespace nesting and the target systemd compatibility are untested. Failure must not trigger weakened policy or a retry. Evidence markers in journald are observations, not proof of independent integrity. No real authentication until G1–G5 and separate approval.
diff --git a/build_files/pi-security/entry183/admission-intent.json b/build_files/pi-security/entry183/admission-intent.json
new file mode 100644
index 0000000..3d2c5eb
--- /dev/null
+++ b/build_files/pi-security/entry183/admission-intent.json
@@ -0,0 +1,35 @@
+{
+  "status": "offline-candidate-not-an-admission-grant",
+  "author_identity": {
+    "name": "pi-author",
+    "uid": 947,
+    "gid": 947
+  },
+  "future_runtime_identity": {
+    "name": "pi-runtime",
+    "uid": 948,
+    "gid": 948,
+    "activate": false
+  },
+  "existing_opencode": {
+    "path_relative_to_desktop_home": ".opencode/bin/opencode",
+    "version": "2.4.2",
+    "uid": 1000,
+    "size_bytes": 275282096,
+    "sha256": "523b1502d1d556998b0904235cef65eb1d8cf8362b4e2faa7ae7a170c9a44cd4",
+    "release_association": "Entry180 satisfied; not build provenance",
+    "execute": false,
+    "modify": false
+  },
+  "nono": {
+    "version": "0.82.0",
+    "sha256": "dfa2b2730dc77f3f3b529a56444dc094b5768258997821b70b42b1e70474a903",
+    "continuity_only": true
+  },
+  "activation_authorized": false,
+  "approval_channel": "unqualified; no implementation",
+  "credential_route": "unqualified; no OAuth",
+  "fsverity_real_binary": "not authorized",
+  "repo_revision_candidate": "9c7b9798b4024253f085f33d65933158373f322f",
+  "repo_revision_content_verified": false
+}
diff --git a/build_files/pi-security/entry183/allowed.txt b/build_files/pi-security/entry183/allowed.txt
new file mode 100644
index 0000000..4a752cc
--- /dev/null
+++ b/build_files/pi-security/entry183/allowed.txt
@@ -0,0 +1 @@
+ALLOWED
diff --git a/build_files/pi-security/entry183/nono-denied.txt b/build_files/pi-security/entry183/nono-denied.txt
new file mode 100644
index 0000000..b2c82c7
--- /dev/null
+++ b/build_files/pi-security/entry183/nono-denied.txt
@@ -0,0 +1 @@
+NONO_SYNTHETIC
diff --git a/build_files/pi-security/entry183/nono-profile.json b/build_files/pi-security/entry183/nono-profile.json
new file mode 100644
index 0000000..bfb9c5f
--- /dev/null
+++ b/build_files/pi-security/entry183/nono-profile.json
@@ -0,0 +1,30 @@
+{
+  "meta": {
+    "name": "entry183-synthetic",
+    "description": "Offline candidate, fixed inert shell fixture only"
+  },
+  "groups": {
+    "include": []
+  },
+  "filesystem": {
+    "read": [
+      "/usr/lib64"
+    ],
+    "read_file": [
+      "/usr/bin/bash",
+      "/etc/ld.so.cache",
+      "/usr/share/pi-security/entry183/probe.sh",
+      "/usr/share/pi-security/entry183/allowed.txt"
+    ],
+    "allow": [
+      "/run/pi-entry183-synthetic/work"
+    ]
+  },
+  "workdir": {
+    "access": "none"
+  },
+  "security": {
+    "capability_elevation": false,
+    "signal_mode": "isolated"
+  }
+}
diff --git a/build_files/pi-security/entry183/pi-entry183-synthetic.service b/build_files/pi-security/entry183/pi-entry183-synthetic.service
new file mode 100644
index 0000000..d0e5adc
--- /dev/null
+++ b/build_files/pi-security/entry183/pi-entry183-synthetic.service
@@ -0,0 +1,44 @@
+# Offline candidate only. No install target, no build hook, no activation sentinel shipped.
+[Unit]
+Description=Pi Entry183 disabled synthetic author containment candidate
+RefuseManualStart=yes
+ConditionPathExists=/usr/share/pi-security/entry183/activation-not-provisioned
+
+[Service]
+Type=oneshot
+User=pi-author
+Group=pi-author
+UMask=0077
+WorkingDirectory=/
+RuntimeDirectory=pi-entry183-synthetic
+RuntimeDirectoryMode=0700
+RuntimeDirectoryPreserve=no
+Environment=PATH=/usr/bin:/bin LC_ALL=C
+UnsetEnvironment=BASH_ENV ENV LD_PRELOAD LD_LIBRARY_PATH DBUS_SESSION_BUS_ADDRESS SSH_AUTH_SOCK DISPLAY WAYLAND_DISPLAY XDG_RUNTIME_DIR GH_TOKEN GITHUB_TOKEN OPENAI_API_KEY
+ExecStart=/usr/bin/env -i PATH=/usr/bin:/bin LC_ALL=C HOME=/run/pi-entry183-synthetic INVOCATION_ID=${INVOCATION_ID} /usr/bin/bash --noprofile --norc /usr/share/pi-security/entry183/probe.sh outer
+StandardInput=null
+StandardOutput=journal
+StandardError=journal
+ProtectSystem=strict
+ProtectHome=yes
+PrivateTmp=yes
+PrivateNetwork=yes
+PrivateIPC=yes
+PrivateDevices=yes
+NoNewPrivileges=yes
+CapabilityBoundingSet=
+AmbientCapabilities=
+ProtectKernelTunables=yes
+ProtectKernelModules=yes
+ProtectControlGroups=yes
+ProtectProc=invisible
+RestrictSUIDSGID=yes
+InaccessiblePaths=/usr/share/pi-security/entry183/systemd-denied.txt
+ReadWritePaths=/run/pi-entry183-synthetic
+Delegate=no
+KillMode=control-group
+TimeoutStartSec=60s
+TimeoutStopSec=10s
+Restart=no
+TasksMax=64
+MemoryMax=512M
diff --git a/build_files/pi-security/entry183/probe.sh b/build_files/pi-security/entry183/probe.sh
new file mode 100644
index 0000000..cc029cd
--- /dev/null
+++ b/build_files/pi-security/entry183/probe.sh
@@ -0,0 +1,56 @@
+#!/bin/bash
+# Offline image-build candidate; never invoke directly on the host.
+set -euo pipefail
+umask 077
+readonly base=/usr/share/pi-security/entry183
+readonly run=/run/pi-entry183-synthetic
+fail() { printf 'STOP: %s\n' "$1" >&2; exit 1; }
+read_marker() { local value; IFS= read -r value < "$1" && [[ $value == "$2" ]]; }
+case ${1:-} in
+outer)
+    [[ $EUID == 947 && $(/usr/bin/id -g) == 947 && $(/usr/bin/id -G) == 947 ]] || fail identity
+    [[ -n ${INVOCATION_ID:-} && -d $run && ! -L $run && -O $run ]] || fail service-context
+    [[ $(/usr/bin/stat -c '%a' -- "$run") == 700 ]] || fail runtime-mode
+    # Only a new, empty runtime directory is allowed. No recursive cleanup.
+    shopt -s nullglob dotglob
+    entries=("$run"/*)
+    ((${#entries[@]} == 0)) || fail runtime-not-empty
+    read_marker "$base/allowed.txt" ALLOWED || fail allowed-positive
+    read_marker "$base/nono-denied.txt" NONO_SYNTHETIC || fail nono-denial-positive
+    if { : < "$base/systemd-denied.txt"; } 2>/dev/null; then fail systemd-denial; fi
+    # Positive fixture contents must also be checked independently before activation.
+    printf 'S03=OBSERVED (systemd marker not readable)\n'
+    [[ -f /usr/bin/nono && ! -L /usr/bin/nono ]] || fail nono-file
+    [[ $(/usr/bin/stat -c '%u:%a' /usr/bin/nono) == 0:755 ]] || fail nono-metadata
+    measured=$(/usr/bin/sha256sum /usr/bin/nono)
+    [[ ${measured%% *} == dfa2b2730dc77f3f3b529a56444dc094b5768258997821b70b42b1e70474a903 ]] || fail nono-continuity
+    /usr/bin/mkdir -m 700 -- "$run/work" "$run/supervisor"
+    for sub in config data state cache runtime tmp; do /usr/bin/mkdir -m 700 -- "$run/supervisor/$sub"; done
+    # No network, no real user home, no credentials; exact profile, no fallback.
+    /usr/bin/env -i PATH=/usr/bin:/bin LC_ALL=C HOME="$run/supervisor" \
+      XDG_CONFIG_HOME="$run/supervisor/config" XDG_DATA_HOME="$run/supervisor/data" \
+      XDG_STATE_HOME="$run/supervisor/state" XDG_CACHE_HOME="$run/supervisor/cache" \
+      XDG_RUNTIME_DIR="$run/supervisor/runtime" TMPDIR="$run/supervisor/tmp" \
+      /usr/bin/nono run --profile "$base/nono-profile.json" --block-net --isolate net,ipc,uts -- \
+      /usr/bin/bash --noprofile --norc "$base/probe.sh" inner
+    read_marker "$run/work/result.txt" SYNTHETIC_OUTPUT || fail output-check
+    read_marker "$base/allowed.txt" ALLOWED || fail input-integrity
+    read_marker "$base/nono-denied.txt" NONO_SYNTHETIC || fail outside-integrity
+    printf 'S01-S07=observations only; independent review required\n'
+    ;;
+inner)
+    read_marker "$base/allowed.txt" ALLOWED || fail inner-positive
+    printf 'S04=OBSERVED\n'
+    if { : < "$base/nono-denied.txt"; } 2>/dev/null; then fail nono-denial; fi
+    printf 'S05=OBSERVED\n'
+    if { : >> "$base/allowed.txt"; } 2>/dev/null; then fail input-write; fi
+    printf 'S06=OBSERVED\n'
+    /usr/bin/bash --noprofile --norc "$base/probe.sh" child
+    printf '%s\n' SYNTHETIC_OUTPUT > "$run/work/result.txt"
+    printf 'S07=OBSERVED\n'
+    ;;
+child)
+    if { : < "$base/nono-denied.txt"; } 2>/dev/null; then fail child-denial; fi
+    ;;
+*) fail invalid-mode ;;
+esac
diff --git a/build_files/pi-security/entry183/systemd-denied.txt b/build_files/pi-security/entry183/systemd-denied.txt
new file mode 100644
index 0000000..b3d560f
--- /dev/null
+++ b/build_files/pi-security/entry183/systemd-denied.txt
@@ -0,0 +1 @@
+SYSTEMD_SYNTHETIC
ENTRY183_ADD_PATCH
cat >"$work/integration.patch" <<'ENTRY183_INTEGRATION_PATCH'
diff --git a/Containerfile b/Containerfile
--- a/Containerfile
+++ b/Containerfile
@@ -1,4 +1,28 @@
 RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
     --mount=type=bind,from=downloads,source=/out,target=/downloads \
     /ctx/packages/install-system-integration-files && \
     /ctx/finalization/verify integration-files
+
+# Pi Entry183: dormant synthetic fixture only. No enablement or activation.
+RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
+    set -eu; \
+    src=/ctx/pi-security/entry183; \
+    parent=/usr/share/pi-security; \
+    dst="$parent/entry183"; \
+    unit=/usr/lib/systemd/system/pi-entry183-synthetic.service; \
+    for d in /usr/share /usr/lib/systemd/system; do \
+        test -d "$d"; test ! -L "$d"; test "$(stat -c '%u:%g:%a' "$d")" = 0:0:755; \
+    done; \
+    if test -e "$parent" || test -L "$parent"; then \
+        test -d "$parent"; test ! -L "$parent"; test "$(stat -c '%u:%g:%a' "$parent")" = 0:0:755; \
+    else install -d -o 0 -g 0 -m 0755 "$parent"; fi; \
+    test ! -e "$dst"; test ! -L "$dst"; test ! -e "$unit"; test ! -L "$unit"; \
+    for f in probe.sh nono-profile.json admission-intent.json allowed.txt nono-denied.txt systemd-denied.txt pi-entry183-synthetic.service; do \
+        test -f "$src/$f"; test ! -L "$src/$f"; \
+    done; \
+    install -d -o 0 -g 0 -m 0755 "$dst"; \
+    for f in probe.sh nono-profile.json admission-intent.json allowed.txt nono-denied.txt systemd-denied.txt; do \
+        install -o 0 -g 0 -m 0644 "$src/$f" "$dst/$f"; \
+    done; \
+    install -o 0 -g 0 -m 0644 "$src/pi-entry183-synthetic.service" "$unit"; \
+    test ! -e "$dst/activation-not-provisioned"; test ! -L "$dst/activation-not-provisioned"
ENTRY183_INTEGRATION_PATCH
[[ $(sha256sum "$work/add.patch" | cut -d' ' -f1) == 5d1e7d5aaf7083f814b98b2b348467839367ed6d40f1af1abbf37edddb6282b6 ]] || stop 'embedded add patch hash mismatch'
[[ $(sha256sum "$work/integration.patch" | cut -d' ' -f1) == 0315855fdcdfa78ba8c7194e0c2039edf05bbaea384ad059d320523666237f23 ]] || stop 'embedded integration patch hash mismatch'
# Run apply --check only in disposable scratch tree. Never apply to actual checkout.
git_clean -C "$work/tree" apply --check "$work/add.patch" 2>/dev/null || stop 'add-only patch scratch check failed'
log 'add_only_patch_check=pass'
git_clean -C "$work/tree" apply --check "$work/integration.patch" 2>/dev/null || stop 'integration patch scratch check failed'
log 'integration_patch_full_containerfile_check=pass'
[[ $(git_clean -C "$repo" rev-parse --verify HEAD 2>/dev/null) == "$head" ]] && cmp -s "$repo/Containerfile" "$work/tree/Containerfile" || stop 'checkout changed during review'
log 'RESULT: preliminary source applicability only; no protected operator, deployment, admission or runtime qualification'
