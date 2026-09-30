#!/usr/bin/env bash
# Shared ANSI log helpers for the halcyon GitHub Actions workflows.
# shellcheck disable=SC2034  # color vocabulary is sourced by workflow steps
# shellcheck shell=bash
#
# GitHub's log viewer renders the ANSI escapes these emit, so every workflow
# stage prints a distinct colored block — scrolling a long build log you can
# find stage boundaries instantly instead of hunting for step headers.
# Source it from any step after checkout:   source .github/log-helpers.sh

H_RESET=$'\033[0m'
H_DIM=$'\033[2m'
H_RED=$'\033[1;31m'
H_GRN=$'\033[1;32m'
H_YLW=$'\033[1;33m'
H_BLU=$'\033[1;34m'
H_MAG=$'\033[1;35m'
H_CYA=$'\033[1;36m'
H_WHT=$'\033[1;37m'

rule()   { printf '%s\n' "${H_DIM}────────────────────────────────────────────────────────────────────────${H_RESET}"; }
banner() {
  printf '\n%s\n' "${H_MAG}╔══════════════════════════════════════════════════════════════════════╗${H_RESET}"
  printf '%s\n'   "${H_MAG}║  ▶ ${*}${H_RESET}"
  printf '%s\n\n' "${H_MAG}╚══════════════════════════════════════════════════════════════════════╝${H_RESET}"
}
step()   { printf '%s\n' "${H_CYA}  ● ${*}${H_RESET}"; }
ok()     { printf '%s\n' "${H_GRN}  ✔ ${*}${H_RESET}"; }
warn()   { printf '%s\n' "${H_YLW}  ⚠ ${*}${H_RESET}"; }
fail()   { printf '%s\n' "${H_RED}  ✖ ${*}${H_RESET}" >&2; }
die()    { fail "${*}"; exit 1; }
