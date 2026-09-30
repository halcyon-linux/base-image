#!/usr/bin/env bash
# verify/verify-github.sh — HOST-side audit of the .github folder.
# Checks: required files, retired files stay retired, YAML parses, cron syntax,
# every `uses:` is pinned (vN tag or full SHA — Renovate rewrites tags to SHAs,
# so no specific major is hardcoded here), runners are pinned, the cosign
# legacy-format guard is present, and the log helper sources cleanly.
# Optional: runs actionlint if it is on PATH.
set -uo pipefail

fail=0
pass()  { printf '  PASS  %s\n' "$1"; }
failf() { printf '  FAIL  %s\n' "$1"; fail=1; }
info()  { printf '  INFO  %s\n' "$1"; }
warnf() { printf '  WARN  %s\n' "$1"; }

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GH="${ROOT}/.github"
WF=("${GH}"/workflows/*.yml)

echo "::group::verify-github — required files"
for f in workflows/build.yml workflows/lint.yml workflows/clean.yml \
         workflows/semantic-pr.yml dependabot.yml renovate.json5 \
         log-helpers.sh pull_request_template.md CODEOWNERS; do
  if [ -f "${GH}/${f}" ]; then pass ".github/${f}"; else failf ".github/${f} missing"; fi
done
if [ -e "${GH}/semantic.yml" ]; then
  failf ".github/semantic.yml present — it configures a service that no longer runs; use workflows/semantic-pr.yml"
else
  pass "no dead .github/semantic.yml"
fi
echo "::endgroup::"

echo "::group::verify-github — YAML parse + workflow structure"
if python3 -c 'import yaml' 2>/dev/null; then
  for wf in "${WF[@]}"; do
    name="$(basename "${wf}")"
    if python3 - "${wf}" <<'PY'
import sys, yaml
docs = list(yaml.safe_load_all(open(sys.argv[1])))
sys.exit(0 if docs and docs[0] else 1)
PY
    then pass "${name}: YAML parses"; else failf "${name}: YAML does not parse"; fi
    grep -q '^name:' "${wf}" || failf "${name}: missing name:"
    grep -q '^on:'   "${wf}" || failf "${name}: missing on: trigger"
    grep -q '^jobs:' "${wf}" || failf "${name}: missing jobs:"
  done
else
  info "PyYAML unavailable — skipped parse checks (pip install pyyaml)"
fi
echo "::endgroup::"

echo "::group::verify-github — cron expressions"
cron_ok() {
  python3 - "$1" <<'PY'
import re, sys
c = sys.argv[1].split()
sys.exit(0 if len(c) == 5 and all(re.fullmatch(r'[\d*,/\-A-Za-z]+', f) for f in c) else 1)
PY
}
while IFS= read -r c; do
  if cron_ok "${c}"; then pass "cron '${c}' well-formed"; else failf "cron '${c}' malformed"; fi
done < <(grep -hoP 'cron:[[:space:]]*"\K[^"#]*' "${WF[@]}" | sed 's/[[:space:]]*$//')
echo "::endgroup::"

echo "::group::verify-github — action references + runners"
while IFS= read -r ref; do
  case "${ref}" in ./*|docker://*) continue ;; esac
  if [[ "${ref}" =~ ^[^@]+@([0-9a-f]{40}|v[0-9]+(\.[0-9]+){0,2})$ ]]; then
    pass "${ref}"
  else
    failf "${ref} — pin to a vN tag or a full commit SHA, never a branch"
  fi
done < <(grep -hoP 'uses:\s*\K[^\s#]+' "${WF[@]}" | sort -u)

if grep -nE 'runs-on:[[:space:]]*ubuntu-latest' "${WF[@]}" >/dev/null; then
  failf "runs-on: ubuntu-latest found — pin ubuntu-24.04 (latest migrates to 26.04 Oct–Nov 2026)"
else
  pass "no unpinned ubuntu-latest runners"
fi
if grep -nE 'uses:[[:space:]]*blue-build/' "${WF[@]}" >/dev/null; then
  failf "a workflow uses the blue-build action — this branch builds with podman via the Justfile"
else
  pass "no blue-build action in workflows"
fi
echo "::endgroup::"

echo "::group::verify-github — build.yml invariants"
B="${GH}/workflows/build.yml"
# The build driver is the bluebuild CLI, installed in CI from the pinned
# versioned installer tag — never from a moving install script.
if grep -q 'ghcr.io/blue-build/cli:v0.9.37-installer' "${B}"; then
  pass "bluebuild CLI install pinned to v0.9.37-installer"
else
  failf "build.yml must install bluebuild from ghcr.io/blue-build/cli:v0.9.37-installer (pinned)"
fi
if grep -q -- '--new-bundle-format=false' "${B}"; then
  pass "cosign signs in the legacy format containers/image reads"
else
  failf "build.yml lacks --new-bundle-format=false — signed rebases will not verify"
fi
grep -q 'cosign verify --key cosign.pub --new-bundle-format=false' "${B}" \
  && pass "legacy-format verify step present" \
  || failf "legacy-format verify step missing (default verify accepts both formats and cannot catch this)"
grep -q 'PUBLISH_BRANCH' "${B}" \
  && pass "explicit publish gate present" \
  || failf "publish gate missing — scheduled/dispatch runs would not push"
if grep -q 'id-token:[[:space:]]*write' "${B}"; then
  failf "id-token: write present — key-based signing needs no OIDC"
else
  pass "no unnecessary id-token permission"
fi
for copr in "aahsnr-work/halcyon" "aahsnr-work/halcyon-cli" "aahsnr-work/halcyon-apps" "aahsnr-work/halcyon-fonts" "aahsnr-work/halcyon-texlive" "catpieleaf/kernel-p03" "ublue-os/packages"; do
  grep -q "${copr}" "${B}" && pass "monitors ${copr}" || failf "missing COPR monitor for ${copr}"
done
echo "::endgroup::"

echo "::group::verify-github — default branch (informational)"
# Scheduled workflows run only from the repository's default branch.
default_ref="$(git -C "${ROOT}" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null || true)"
if [ -z "${default_ref}" ]; then
  info "default branch unknown locally — confirm it is 'container' (Settings → Branches), or the daily cron will not run this workflow"
elif [ "${default_ref}" = "origin/container" ]; then
  pass "default branch is container — cron and manual dispatch use this workflow"
else
  warnf "default branch is ${default_ref#origin/}: the daily cron runs THAT branch's workflow, not this one"
fi
echo "::endgroup::"

echo "::group::verify-github — log helpers"
if bash -n "${GH}/log-helpers.sh" 2>/dev/null; then pass "log-helpers.sh: bash -n clean"; else failf "log-helpers.sh: bash -n FAILED"; fi
if bash -c 'source "'"${GH}"'/log-helpers.sh" && banner t && step s && ok o && warn w >/dev/null 2>&1'; then
  pass "log-helpers.sh sources and helpers are callable"
else
  failf "log-helpers.sh: sourcing failed"
fi
echo "::endgroup::"

echo "::group::verify-github — actionlint (optional)"
if command -v actionlint >/dev/null 2>&1; then
  if actionlint -color=never -shellcheck= "${WF[@]}"; then pass "actionlint clean"; else failf "actionlint reported problems"; fi
else
  info "actionlint not installed — skipped"
fi
echo "::endgroup::"

if [ "${fail}" -eq 0 ]; then
  echo "--- verify-github: ALL CHECKS PASSED ---"
  exit 0
fi
echo "::error::verify-github FAILED"
exit 1
