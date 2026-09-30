#!/usr/bin/env bash
# halcyon build step — install-built-apps (halcyon RPM apps + texlive + python)
#
# The four scratch scripts (Obsidian AppImage, Zotero tarball, Pyprland venv,
# TeX Live CTAN installer) are retired: the halcyon-packages monorepo ships
# obsidian, zotero, pyprland, distroshelf, onlyoffice-desktopeditors,
# bitwarden, ticktick (COPR aahsnr-work/halcyon-apps, priority=1) and
# texlive-meta (COPR aahsnr-work/halcyon-texlive, covers latexmk/biber — no
# tlmgr step needed). The repos were staged in Stage 01; resolution is
# priority-arbitrated like every other halcyon install.
#
# The 11 python helpers stay script-built (not in the monorepo): their
# sources are staged from the ctx mount to /usr/src/python-packages and
# installed into ONE shared venv by install_python_packages() below (absorbed
# from apps/install-python-packages in the 2026-09-29 one-file-per-stage
# consolidation, together with the built-apps-verify gates at the bottom).
set -euo pipefail

echo "████ STAGE 07/13 · built-apps · halcyon apps + texlive + python ████"
# shellcheck source=files/scripts/lib/packages-lib
source /tmp/files/scripts/lib/packages-lib
packages_validate

# Install every staged Python package under /usr/src/python-packages into ONE
# shared venv at /usr/lib/halcyon-python (all packages are stdlib-only, so a
# shared venv has no dependency conflicts), then symlink each console script
# separately into /usr/bin — 11 independent binaries, one venv. Per-binary
# verification lives in the built-apps-verify section at the bottom of this
# script.
install_python_packages() {
  STAGED_ROOT="/usr/src/python-packages"
  VENV_DIR="/usr/lib/halcyon-python"
  # package dir name : console script name (identical for this family)
  readonly EXPECTED=(
    dump-to-markdown
    fconf
    fe
    ff
    fkill
    fp
    fssh
    rmi
    rmtmp
    screenshot
    se
  )

  echo "::group::install-python-packages — staged packages check"
  missing=()
  for pkg in "${EXPECTED[@]}"; do
    if [ ! -f "${STAGED_ROOT}/${pkg}/pyproject.toml" ]; then
      missing+=("${pkg}")
    fi
  done
  if [ "${#missing[@]}" -gt 0 ]; then
    echo "  FAIL  missing staged packages: ${missing[*]} — files-module staging did not run"
    echo "::endgroup::"
    exit 1
  fi
  echo "  OK    all ${#EXPECTED[@]} staged packages present"
  echo "::endgroup::"

  # Snapshot the staged tree into /var/tmp before building: pip's egg_info
  # step writes into the source tree, and this keeps the installer working
  # even if the staging mount is read-only. Also removed wholesale at cleanup,
  # so nothing ever deletes the module-staged original through a mount.
  echo "::group::install-python-packages — snapshot staged sources"
  install -d -m 1777 /var/tmp  # 1777 like the base/tmp.conf: the built image
                               # strips /var, so create it canonically — a plain
                               # mkdir would leave a non-sticky 0755 dir behind
  WORK_ROOT="$(mktemp -d /var/tmp/python-packages.XXXXXX)"
  mv "${STAGED_ROOT}"/* "${WORK_ROOT}/"
  echo "  OK    staged sources snapshotted to ${WORK_ROOT}"
  echo "::endgroup::"

  echo "::group::install-python-packages — shared virtualenv"
  echo "--- Creating virtualenv at ${VENV_DIR} ---"
  rm -rf "${VENV_DIR}"
  python3 -m venv "${VENV_DIR}"
  echo "  OK    virtualenv created ($(python3 --version))"

  echo "--- Upgrading pip / build tools ---"
  "${VENV_DIR}/bin/pip" install --no-cache-dir --upgrade pip setuptools wheel
  echo "  OK    pip/setuptools/wheel up to date"
  echo "::endgroup::"

  echo "::group::install-python-packages — pip install (11 packages)"
  for pkg in "${EXPECTED[@]}"; do
    echo "--- Installing ${pkg} ---"
    "${VENV_DIR}/bin/pip" install --no-cache-dir "${WORK_ROOT}/${pkg}" \
      || { echo "  FAIL  pip install ${pkg}"; echo "::endgroup::"; exit 1; }
    echo "  OK    ${pkg} installed"
  done
  echo "::endgroup::"

  echo "::group::install-python-packages — console script symlinks"
  for pkg in "${EXPECTED[@]}"; do
    script="${VENV_DIR}/bin/${pkg}"
    if [ ! -x "${script}" ]; then
      echo "  FAIL  console script ${script} missing after install"
      echo "::endgroup::"
      exit 1
    fi
    ln -sf "${script}" "/usr/bin/${pkg}"
    echo "  OK    /usr/bin/${pkg} → ${script}"
  done
  echo "::endgroup::"

  echo "::group::install-python-packages — secure virtualenv permissions"
  chown -R root:root "${VENV_DIR}"
  chmod -R go-w "${VENV_DIR}"
  echo "  OK    ${VENV_DIR} permissions secured (root:root, non-world-writable)"
  echo "::endgroup::"

  echo "::group::install-python-packages — smoke tests"
  dump_version="$(dump-to-markdown --version)"
  echo "  OK    dump-to-markdown ${dump_version}"

  # Some tools need fd/bat/rg/fzf at runtime — these are RPMs installed by
  # Stage 06 devtools (the brew payload is retired),
  # so the plain PATH is enough. Run each binary and fail the build on a
  # real problem.
  failed=()
  for pkg in fconf fe ff fkill fp fssh rmi rmtmp screenshot se; do
    if "/usr/bin/${pkg}" -h >/dev/null 2>&1 || "/usr/bin/${pkg}" --version >/dev/null 2>&1; then
      echo "  OK    ${pkg} smoke"
    else
      failed+=("${pkg}")
    fi
  done
  if [ "${#failed[@]}" -gt 0 ]; then
    echo "  FAIL  ${failed[*]} — -h/--version failed"
    echo "::endgroup::"
    exit 1
  fi
  echo "  OK    all 10 helper smokes passed"
  echo "::endgroup::"

  echo "::group::install-python-packages — cleanup staged sources"
  rm -rf "${WORK_ROOT}"
  rm -rf "${STAGED_ROOT}" 2>/dev/null || true
  echo "  INFO  removed snapshot ${WORK_ROOT} and staged source ${STAGED_ROOT} (installed copies live in ${VENV_DIR})"
  echo "--- install-python-packages complete: ${#EXPECTED[@]} binaries in /usr/bin ---"
  echo "::endgroup::"
}

echo "::group::install-built-apps — halcyon apps + texlive (RPMs, priority 1)"
rm -rf /usr/src/python-packages
cp -a /tmp/files/python-packages /usr/src/python-packages

readarray -t APP_PKGS < <(packages_for halcyon-apps)
dnf5 -y --setopt=install_weak_deps=False install \
  "${APP_PKGS[@]}"

readarray -t TL_PKGS < <(packages_for halcyon-texlive)
dnf5 -y --setopt=install_weak_deps=False install \
  "${TL_PKGS[@]}"
echo "::endgroup::"

# the python installer emits its own ::group:: folds
install_python_packages
rm -rf /usr/src/python-packages

# --- verification (absorbed from built-apps-verify in the 2026-09-29
# one-file-per-stage consolidation; same RUN, gate-fail semantics unchanged:
# any FAIL sets fail=1 and the script exits 1 with a ::error:: annotation).
# Everything here is an RPM from COPR aahsnr-work/halcyon-apps / -texlive —
# the AppImage/tarball/venv/CTAN scripts were retired (2026-09-29).
fail=0
gate() { local desc="$1"; shift; if "$@" >/dev/null 2>&1; then echo "  PASS  $desc"; else echo "  FAIL  $desc"; fail=1; fi; }

echo "::group::built-apps-verify — halcyon-apps RPMs"
gate "obsidian launcher"                 test -x /usr/bin/obsidian
gate "obsidian desktop entry"            test -f /usr/share/applications/obsidian.desktop
gate "zotero launcher"                   test -x /usr/bin/zotero
gate "zotero desktop entry"              test -f /usr/share/applications/zotero.desktop
gate "zotero autoupdate disabled"        grep -q 'DisableAppUpdate' /usr/lib/zotero/distribution/policies.json 2>/dev/null
gate "distroshelf installed"             rpm -q distroshelf
gate "onlyoffice installed"              rpm -q onlyoffice-desktopeditors
gate "bitwarden installed"               rpm -q bitwarden
gate "ticktick installed"                rpm -q ticktick
echo "::endgroup::"

echo "::group::built-apps-verify — pyprland (RPM + shipped unit)"
gate "pypr console script"               test -x /usr/bin/pypr
gate "pyprland RPM installed"            rpm -q pyprland
gate "pyprland user unit"                test -f /usr/lib/systemd/user/pyprland.service
gate "Hyprland condition drop-in"        grep -rq 'XDG_CURRENT_DESKTOP=Hyprland' /usr/lib/systemd/user/pyprland.service.d/ 2>/dev/null
echo "::endgroup::"

echo "::group::built-apps-verify — texlive + python helpers"
gate "texlive-meta installed"            rpm -q texlive-meta
gate "pdflatex on PATH"                  test -x /usr/bin/pdflatex
gate "latexmk present"                   rpm -q texlive-latexextra
gate "shared venv present"               test -d /usr/lib/halcyon-python
for b in dump-to-markdown fconf fe ff fkill fp fssh rmi rmtmp screenshot se; do
  gate "python helper: $b"               test -e "/usr/bin/$b"
done
echo "::endgroup::"

[ "$fail" = 0 ] || { echo "::error::built-apps-verify failed"; exit 1; }
echo "--- built-apps-verify: all checks passed ---"
/tmp/files/scripts/lib/cleanup.sh
echo "--- built-apps complete ---"
