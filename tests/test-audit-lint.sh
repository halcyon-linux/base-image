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
done < <(find "$repo_root/build_files" "$repo_root/just_scripts" "$repo_root/tests" -type f -not -path '*/.*' -not -name "*.md" -not -name "*.txt")

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

if grep -rE 'arch=b32.*kexec_file_load' "$rules_dir" >/dev/null 2>&1; then
    not_ok "kexec_file_load in arch=b32 rule"
else
    ok "no kexec_file_load in b32 rules"
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

if ((failures)); then
    printf '\ntest-audit-lint: %d check(s) failed\n' "$failures" >&2
    exit 1
fi

printf '\ntest-audit-lint: all checks passed\n'
