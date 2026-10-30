 ▐▛███▛█   Claude Code v2.1.312
▝▜██████▀  Sonnet 5.5 · Claude Pro
 ▝▝   ▝▝   ~/Git/halcyon/base-image


❯ Now run a security audit of the project                                       

● Starting with a repo map and targeted greps.

  Searched for 2 patterns, ran 7 shell commands (ctrl+o to expand)

● Static review only. I ran no build, no shellcheck, and no boot. Audited: the
  workflow, signing, download paths, repo and GPG handling, and the shipped
  hardening config. I did not read all 200 files.

  Findings

  Medium
  1. Unsigned or unpinned payloads in the image (known debt A-008, CLAUDE.md
     rule 12).
     - Mutable GitHub downloads, no checksum: winetricks (master), bash-preexec
       (master), the Distrobox template (main), extest and ujust-picker
       (releases/latest). extest and ujust-picker end up as
       /usr/lib/extest/libextest.so and /usr/bin/ujust-picker.
     - extest is a .so that loads into Steam. A compromised upstream release
       ships code into your signed image.
     - Files: build_files/packages/install-gaming-stack:168,
       install-system-integration-files:13-24, install-common-packages:42-46,
       install-ujust-picker:11.
  2. cicpoffs RPM installed from a URL (install-common-packages:18-22). It comes
     from releases/latest with no explicit signature or checksum check. I did
     not confirm whether dnf5 checks a signature on URL packages here.
     localpkg_gpgcheck is not set anywhere in the repo.
  3. .github/pull.yml merges ublue-os:main into containerfile (mergeUnstable: 
     false). containerfile is the branch that builds, publishes and signs.
     Upstream changes reach a signed image unreviewed if the Pull app
     auto-merges. The daily cron then publishes it.
  4. Polkit rule gives passwordless root to wheel (20-privileged-ruser.rules).
     - The action's own default is auth_admin, but the rule overrides it with
       YES for wheel.
     - The target is /usr/bin/privileged-user-setup. I found no copy of that
       script in this repo, so it presumably comes from an RPM. I did not audit
       it.
     - verify checks only allow_any, not this override. Any wheel-level
       compromise, such as a session hijack, becomes root without a prompt.
  5. --nogpgcheck on the Terra bootstrap (setup-repositories:37). terra-release
     is fetched from repos.fyralabs.com with no GPG check, because the key isn't
     installed yet. The same repo then gets priority 1 and can override Fedora
     packages. Pinning the release RPM or its key hash would shrink the
     exposure.

  Low
  6. rpm --import "${repo_gpgkey}" || true (install-applications:127). A failed
  key import is silent. gpgcheck=1 still makes dnf fail, so this is not a
  bypass. The key is fetched over TLS with no fingerprint pin, so trust rests on
  TLS and the vendor host (Brave, Microsoft, VSCodium on GitLab, Chrome, Edge).
  7. ghcurl sends the token header on every request. It is sent only to GitHub
  hosts here, and curl drops it on cross-host redirects. The token is visible in
  the process list during the build only. -sSL follows redirects, so keep the
  call sites GitHub-only.
  8. Ujust recipes pull unpinned content at runtime. Examples: curl … | tar xJf 
  - for boxtron (82-bazzite-apps.just:689), Resilio from bazzite main, steamcmd,
  framegen builds. They run as the user, on demand.
  9. sshd is set to port 43210 but opens only dhcpv6-client and 43210. Hardening
  is solid: keys only, wheel only, no forwarding, fail2ban. A custom port is
  not a security control, so it is not a finding.

  Checked and fine
  - Workflow: permissions: {} at the top; scoped per job; actions pinned to full
    SHAs; push and sign both guarded by github.ref == refs/heads/containerfile;
    the cosign key is passed via env, not logged; no pull_request trigger, so
    no fork-secret exposure.
  - .containerignore and .dockerignore are identical. *.key is gitignored.
  - Sysctl, modprobe, cron permissions, audit rules, SELinux socket policies and
    faillock are all configured. I did not test them at runtime.

  Gaps (not verified)

  - Whether bootc container lint or the audit rules load at boot.
  - The contents of privileged-user-setup.
  - Whether the Pull app is installed and auto-merging on the GitHub repo.
  - The 17 truncated lines of external_repos in packages.json.

  Say which fixes you want. The cheapest wins: tighten the polkit rule to
  auth_admin, add a verify check for it, and pin extest, cicpoffs and
  ujust-picker to a release tag plus sha256. Both are within CLAUDE.md scope.
  The pull.yml change and anything in the workflows need your explicit go-ahead.

✻ Worked for 1m 4s · done 7:09 AM