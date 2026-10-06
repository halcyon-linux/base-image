fail=0
gate() {
  local desc="$1"
  shift
  if "$@" >/dev/null 2>&1; then echo "  PASS  $desc"; else
    echo "  FAIL  $desc"
    # shellcheck disable=SC2034 # sourcing verifier reads this latch
    fail=1
  fi
}
