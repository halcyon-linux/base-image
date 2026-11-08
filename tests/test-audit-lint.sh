#!/usr/bin/env bash
# Repo-wide audit and lint verification test.
# Validates shell script syntax, permissions, JSON schemas, YAML files, and just syntax.

set -euo pipefail

failures=0
not_ok() {
    printf 'FAIL: %s\n' "$*" >&2
    failures=$((failures + 1))
}

ok() {
    printf 'OK: %s\n' "$*"
}

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# 1. Check bash syntax for all shell scripts
while IFS= read -r script; do
    if head -n 1 "$script" | grep -qE '^#!.*(bash|sh)'; then
        if bash -n "$script"; then
            ok "syntax: $script"
        else
            not_ok "syntax error in: $script"
        fi
    fi
done < <(find "$repo_root/build_files" "$repo_root/just_scripts" "$repo_root/tests" "$repo_root/system_files" -type f)

# 2. Check executable permissions on build scripts and tooling
while IFS= read -r script; do
    if [[ -x "$script" ]]; then
        ok "executable: $script"
    else
        not_ok "not executable: $script"
    fi
done < <(find "$repo_root/build_files" "$repo_root/just_scripts" "$repo_root/tests" -type f -not -path '*/.*' \
    -not -name "*.md" -not -name "*.txt" -not -name "*.tsv" -not -path "$repo_root/build_files/keys/*")

# Static data (download manifest, vendored keys) must not be executable.
while IFS= read -r data; do
    not_ok "static data file is executable: $data"
done < <(find "$repo_root/build_files/keys" "$repo_root/build_files/downloads" -type f \
    \( -name "*.tsv" -o -path "$repo_root/build_files/keys/*" \) -perm /111)

# 3. Validate packages.json
if jq . "$repo_root/packages.json" >/dev/null 2>&1; then
    ok "packages.json is valid JSON"
else
    not_ok "packages.json syntax error"
fi

for section in applications base-pkgs cli-tools common-packages fonts gaming kernel nix security texlive-packages utils; do
    if jq -e --arg s "$section" 'has($s)' "$repo_root/packages.json" >/dev/null 2>&1; then
        ok "packages.json section exists: $section"
    else
        not_ok "packages.json missing section: $section"
    fi
done

if jq -e '."common-packages".packages | index("virtiofsd")' "$repo_root/packages.json" >/dev/null; then
    ok "virtiofsd is installed from common-packages"
else
    not_ok "common-packages must install virtiofsd"
fi

if jq -e '
    .["common-packages"].packages as $common
    | .security.packages as $security
    | ($common | index("setools-console") | not)
      and ($common | index("setroubleshoot") | not)
      and ($common | index("lynis") | not)
      and ($security | index("setools-console") != null)
      and ($security | index("setroubleshoot") != null)
      and ($security | index("lynis") != null)
      and ($common | index("gdu") != null)
      and ($common | index("perl") != null)
      and ($common | index("nautilus") != null)
      and ($common | index("file-roller") != null)
      and ($common | index("ScopeBuddy") | not)
      and ($common | map(select(test("(?i)^thunar$|^thunar-"))) | length == 0)
      and ([.gaming.packages[] | select(. == "dmemcg-booster")] | length == 0)
      and ([.. | strings | select(test("bazzite-multilib|i686"))] | length == 0)
' "$repo_root/packages.json" >/dev/null; then
    ok "requested package metadata is consistent"
else
    not_ok "requested package metadata is inconsistent"
fi

if grep -Fq 'reinstall --from-repo=fedora,updates bluez xorg-x11-server-Xwayland' \
    "$repo_root/build_files/packages/install-common-packages" \
    && grep -Fq "require_rpms_from_repo 'fedora,updates' bluez xorg-x11-server-Xwayland" \
        "$repo_root/build_files/finalization/verify"; then
    ok "BlueZ and Xwayland are installed and verified from Fedora repos"
else
    not_ok "BlueZ and Xwayland must be installed and verified from Fedora repos"
fi

if ! grep -Eiq 'vscodium|codium|microsoft-edge|vivaldi|firefox' \
    "$repo_root/packages.json" \
    "$repo_root/build_files/packages/install-applications" \
    "$repo_root/build_files/system/configure-system-policy" \
    "$repo_root/system_files/desktop/usr/share/ublue-os/bazaar/main.yaml" \
    "$repo_root/system_files/desktop/usr/share/ublue-os/bazaar/hooks.py" \
    "$repo_root/system_files/desktop/usr/share/yafti/yafti.yml"; then
    ok "removed browsers absent from app metadata and integration"
else
    not_ok "a removed browser remains configured"
fi
if ! grep -Fq 'forbid_rpms codium firefox microsoft-edge-stable vivaldi-stable' \
    "$repo_root/build_files/finalization/verify"; then
    not_ok "final verification must forbid removed browsers"
fi
if [[ -e "$repo_root/system_files/desktop/usr/share/ublue-os/bazaar/content.yaml" || \
      -L "$repo_root/system_files/desktop/usr/share/ublue-os/bazaar/content.yaml" ]] || \
   grep -Fq '/usr/share/ublue-os/bazaar/content.yaml' \
       "$repo_root/system_files/desktop/usr/share/ublue-os/bazaar/main.yaml"; then
    not_ok "redundant Bazaar content file or reference remains"
else
    ok "redundant Bazaar content file and reference absent"
fi

if grep -Fq '[[ -e /usr/lib64/libdrm.so ]]' "$repo_root/build_files/finalization/verify" \
    && ! grep -Fq '/usr/lib/libdrm.so' "$repo_root/build_files/finalization/verify"; then
    ok "DRM verification requires only the native 64-bit development library"
else
    not_ok "DRM verification must not require the 32-bit /usr/lib/libdrm.so"
fi

if grep -Fq 'rm -rf /etc/fish /usr/share/fish' "$repo_root/build_files/packages/global-remove"; then
    ok "global-remove removes inherited fish configuration and files"
else
    not_ok "global-remove must remove inherited /usr/share/fish artifacts"
fi

if grep -Fq 'pinentry-qt firefox; do' "$repo_root/build_files/packages/global-remove" \
    && grep -Fq 'pinentry-qt firefox' "$repo_root/build_files/finalization/verify"; then
    ok "global-remove removes inherited Firefox and verifies its absence"
else
    not_ok "global-remove must remove inherited Firefox and verify its absence"
fi

if grep -Fq '/usr/bin/fish$|d' "$repo_root/build_files/packages/global-remove" \
    && grep -Fq 'grep -qxF /usr/bin/fish /etc/shells' "$repo_root/build_files/finalization/verify"; then
    ok "global-remove deletes and verifies the fish shell registration"
else
    not_ok "global-remove must delete the fish entry from /etc/shells"
fi

if grep -Fq 'find /home/linuxbrew' "$repo_root/build_files/packages/install-brew-files"; then
    not_ok "install-brew-files must not chmod the absent first-boot Brew tree"
else
    ok "install-brew-files does not chmod the absent first-boot Brew tree"
fi

if grep -Fq 'glaze noctalia-git xdg-desktop-portal-hyprland' "$repo_root/build_files/finalization/verify"; then
    ok "verification requires noctalia-git from base-pkgs"
else
    not_ok "verification must require noctalia-git from base-pkgs"
fi
if jq -e '."base-pkgs".packages | index("noctalia-git")' "$repo_root/packages.json" >/dev/null; then
    ok "noctalia-git is installed from base-pkgs"
else
    not_ok "base-pkgs must install noctalia-git"
fi
if jq -e '."base-pkgs".packages | index("noctalia")' "$repo_root/packages.json" >/dev/null; then
    not_ok "noctalia must not remain in base-pkgs"
else
    ok "noctalia removed from base-pkgs"
fi

if grep -Eq '/usr/bin/(protonplus|winetricks)' "$repo_root/build_files/finalization/verify"; then
    not_ok "final verification must not require removed gaming commands"
else
    ok "final verification does not require ProtonPlus or Winetricks"
fi

if awk -F '\t' '$1 == "winetricks" { found = 1 } END { exit !found }' \
    "$repo_root/build_files/downloads/manifest.tsv"; then
    not_ok "removed Winetricks must not be fetched"
else
    ok "Winetricks download removed"
fi

if jq -e '.gaming.external_downloads // [] | any(startswith("winetricks"))' \
    "$repo_root/packages.json" >/dev/null; then
    not_ok "removed Winetricks must not remain in package metadata"
else
    ok "Winetricks removed from package metadata"
fi

# 4. Validate YAML files
if python3 -c "
import os, glob, sys
try:
    import yaml
except ImportError:
    # If PyYAML is not available in the environment, skip YAML validation
    sys.exit(0)

err = 0
paths = set(glob.glob('$repo_root/**/*.y*ml', recursive=True) + glob.glob('$repo_root/.github/**/*.y*ml', recursive=True))
for path in sorted(paths):
    # Skip symlinks that point to absolute target paths in the image (e.g. /usr/share/...)
    if os.path.islink(path):
        continue
    try:
        with open(path) as f:
            yaml.safe_load(f)
    except Exception as e:
        print(f'YAML error in {path}: {e}', file=sys.stderr)
        err += 1
sys.exit(err)
"; then
    ok "all YAML files valid"
else
    not_ok "YAML validation failed"
fi

# 5. Validate static audit rules and configuration
rules_dir="$repo_root/system_files/overrides/etc/audit/rules.d"
audit_conf="$repo_root/system_files/overrides/etc/audit/auditd.conf"

if [[ -e "$rules_dir/audit.rules" ]]; then
    not_ok "stock audit.rules must not be present"
else
    ok "stock audit.rules absent"
fi

if [[ -e "$rules_dir/99-zz-lock.rules" ]]; then
    not_ok "99-zz-lock.rules must not be shipped"
else
    ok "99-zz-lock.rules not shipped"
fi

for f in 10-base-config 12-cont-fail 20-dont-audit 30-identity 32-power-abuse \
         40-kernel 41-persistence 44-installers 50-security-config 60-access-denied 99-finalize; do
    if [[ -f "$rules_dir/$f.rules" ]]; then
        ok "audit rules file exists: $f.rules"
    else
        not_ok "audit rules file missing: $rules_dir/$f.rules"
    fi
done

if grep -rqE '^[[:space:]]*-[wW][[:space:]]' "$rules_dir" 2>/dev/null; then
    not_ok "deprecated -w watch rule found in $rules_dir"
else
    ok "no deprecated -w watch rules"
fi

if grep -rEq '^[[:space:]]*-a[[:space:]]+(task,never|never,task)' "$rules_dir" 2>/dev/null; then
    not_ok "audit rule disables syscall auditing (task,never) in $rules_dir"
else
    ok "no rule disables syscall auditing"
fi

if grep -rE 'arch=b32.*kexec(_file)?_load' "$rules_dir" >/dev/null 2>&1; then
    not_ok "unsupported kexec syscall in arch=b32 rule"
else
    ok "no unsupported kexec syscall in b32 rules"
fi

dup_rules=$(cat "$rules_dir"/*.rules 2>/dev/null | grep -E '^-' | sort | uniq -d || true)
if [[ -n "$dup_rules" ]]; then
    not_ok "duplicate audit rules found: $dup_rules"
else
    ok "no duplicate audit rules"
fi

d_count=$(cat "$rules_dir"/*.rules 2>/dev/null | grep -cxF -- '-D' || true)
if [[ "$d_count" == 1 ]]; then
    ok "exactly one -D rule"
else
    not_ok "expected 1 -D rule, found $d_count"
fi

if grep -qxF -- '-b 8192' "$rules_dir/10-base-config.rules" 2>/dev/null && \
   grep -qxF -- '--loginuid-immutable' "$rules_dir/10-base-config.rules" 2>/dev/null; then
    ok "10-base-config sets -b 8192 and --loginuid-immutable"
else
    not_ok "10-base-config missing -b 8192 or --loginuid-immutable"
fi

if grep -qxF -- '-c' "$rules_dir/12-cont-fail.rules" 2>/dev/null && \
   ! grep -rqxF -- '-i' "$rules_dir" 2>/dev/null; then
    ok "audit rules continue on error with -c and never use -i"
else
    not_ok "12-cont-fail.rules must contain -c and no rules file may contain -i"
fi

last_rule=$(grep -hvE '^[[:space:]]*(#|$)' "$rules_dir/99-finalize.rules" 2>/dev/null | tail -n1 || true)
if [[ "$last_rule" == "-e 1" ]]; then
    ok "audit rules end enabled with -e 1"
else
    not_ok "99-finalize.rules must end with -e 1 (found: ${last_rule:-nothing})"
fi

if [[ -f "$audit_conf" ]]; then
    if grep -qE '^log_format[[:space:]]*=[[:space:]]*ENRICHED' "$audit_conf" 2>/dev/null; then
        ok "auditd.conf logs in ENRICHED format"
    else
        not_ok "auditd.conf must set log_format = ENRICHED"
    fi
    if grep -qE '^[a-z_]+_action[[:space:]]*=[[:space:]]*(SINGLE|HALT|EXEC)' "$audit_conf" 2>/dev/null; then
        not_ok "auditd.conf uses a SINGLE/HALT/EXEC action"
    else
        ok "auditd.conf has no SINGLE/HALT/EXEC action"
    fi
else
    not_ok "auditd.conf missing: $audit_conf"
fi

if python3 - "$repo_root" <<'PY'
import json
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

root = Path(sys.argv[1])
script = (root / 'build_files/system/configure-security-hardening').read_text()
assert 'authselect check' in script, 'authselect integrity must be checked'
assert 'authselect current --raw' in script, 'local authentication profile must be checked'
assert 'for pam_stack in system-auth password-auth' in script, 'both PAM stacks must be checked'
assert 'firewall-offline-cmd --set-default-zone=FedoraWorkstation' in script, 'explicit firewall default required'
assert 'firewall-offline-cmd --check-config' in script, 'firewall configuration must be validated'
assert 'systemctl enable firewalld.service' in script, 'firewalld must be enabled'
assert 'firewalld' in json.loads((root / 'packages.json').read_text())['security']['packages']
zone = ET.parse(root / 'system_files/overrides/etc/firewalld/zones/FedoraWorkstation.xml').getroot()
assert zone.get('target', 'default') == 'default', 'preserve default ICMP and reject behavior'
assert [s.get('name') for s in zone.findall('service')] == ['dhcpv6-client']
assert [(p.get('port'), p.get('protocol')) for p in zone.findall('port')] == [('47', 'tcp')]
assert not any(zone.findall(tag) for tag in ('rule', 'source-port', 'protocol', 'masquerade', 'forward-port', 'icmp-block', 'icmp-block-inversion'))
ssh = (root / 'system_files/overrides/etc/ssh/sshd_config.d/10-halcyon-hardening.conf').read_text()
assert 'Port 47' in ssh.splitlines(), 'firewall must match SSH port'
rules = (root / 'system_files/overrides/etc/audit/rules.d/60-access-denied.rules').read_text().splitlines()
b64 = [r for r in rules if r.startswith('-a ') and 'arch=b64' in r]
b32 = [r for r in rules if r.startswith('-a ') and 'arch=b32' in r]
assert b64 and {r.replace('arch=b64', 'arch=b32') for r in b64} == set(b32), 'failed-access rules must cover both ABIs'
PY
then
    ok "Fedora desktop authentication, firewall and audit invariants"
else
    not_ok "Fedora desktop authentication, firewall or audit invariant failed"
fi

# 6. Supply-chain guards (security audit: pinned downloads, token isolation, GPG)
# GITHUB_TOKEN may be mounted only in the package-free `downloads` stage.
token_leaks=$(awk '
    toupper($1) == "FROM" { stage = ""; for (i = 1; i <= NF; i++) if (toupper($i) == "AS") stage = $(i + 1) }
    /id=GITHUB_TOKEN/ && stage != "downloads" { printf "%s:%d (stage %s)\n", FILENAME, FNR, stage }
' "$repo_root/Containerfile")
if [[ -n "$token_leaks" ]]; then
    not_ok "GITHUB_TOKEN mounted outside the downloads stage: $token_leaks"
else
    ok "GITHUB_TOKEN mounted only in the downloads stage"
fi

system_policy="$repo_root/build_files/system/configure-system-policy"
if grep -qE '^[[:space:]]*dnf5 -y config-manager setopt terra\.enabled=0 terra-extras\.enabled=0$' \
    "$system_policy"; then
    ok "Terra repositories are explicitly disabled"
else
    not_ok "configure-system-policy must explicitly disable terra and terra-extras"
fi

if grep -rnE 'releases/latest|/(master|main)/|refs/heads/' "$repo_root/build_files" \
    --include='*' -l 2>/dev/null | grep -v '/keys/'; then
    not_ok "mutable download ref (releases/latest, master, main) in build_files"
else
    ok "no mutable download refs in build_files"
fi

if grep -rnE -- '--nogpgcheck|rpm --import[^|]*\|\|[[:space:]]*true' "$repo_root/build_files" 2>/dev/null; then
    not_ok "build_files bypasses or ignores GPG verification"
else
    ok "no --nogpgcheck or ignored rpm --import"
fi

manifest="$repo_root/build_files/downloads/manifest.tsv"
bad_rows=$(awk -F'\t' '!/^#/ && NF && (NF != 4 || $2 !~ /^https:\/\// || $3 !~ /^[0-9a-f]{64}$/ || $4 ~ /\//) { print FNR }' "$manifest")
if [[ -n "$bad_rows" ]]; then
    not_ok "malformed download manifest rows (line $bad_rows)"
else
    ok "download manifest rows are pinned (https URL, sha256, flat dest)"
fi

if jq -e '[.applications.external_repos[] | select((.gpg_fingerprints // []) | length == 0)] | length == 0' \
    "$repo_root/packages.json" >/dev/null; then
    ok "every external repo pins its GPG key fingerprints"
else
    not_ok "external repo without gpg_fingerprints in packages.json"
fi

if ((failures)); then
    printf '\ntest-audit-lint: %d check(s) failed\n' "$failures" >&2
    exit 1
fi

printf '\ntest-audit-lint: all checks passed\n'
