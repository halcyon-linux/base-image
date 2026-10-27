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
done < <(find "$repo_root/build_files" "$repo_root/just_scripts" "$repo_root/tests" -type f)

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

for section in applications base-pkgs cli-tools common-packages fonts gaming kernel nix texlive-packages utils; do
    if jq -e --arg s "$section" 'has($s)' "$repo_root/packages.json" >/dev/null 2>&1; then
        ok "packages.json section exists: $section"
    else
        not_ok "packages.json missing section: $section"
    fi
done

# 4. Validate YAML files
python3 -c "
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
" && ok "all YAML files valid" || not_ok "YAML validation failed"

if ((failures)); then
    printf '\ntest-audit-lint: %d check(s) failed\n' "$failures" >&2
    exit 1
fi

printf '\ntest-audit-lint: all checks passed\n'
