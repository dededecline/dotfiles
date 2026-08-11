#!/usr/bin/env bash
#
# Integration tests for setup.sh's run_brew_sync: the `brew bundle` flags and the
# terminal-state guard around it.
#
# The flag assertions guard a regression whose symptom is scrambled terminal
# output. Passing --verbose to `brew bundle` makes it shell out via
# Kernel#system instead of IO.popen, so up to four parallel child installs
# inherit the real TTY and each enables Homebrew's in-place download redraw. The
# redraw's cursor arithmetic then desyncs and overwrites earlier output.
#
# The tty assertions cover the second, independent mechanism: interactive cask
# and pkg installers can exit leaving ONLCR disabled, which staircases every
# later line.
#
# Run: bash .system/tests/test-brew-sync.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# Read from the environment by the pty subprocess below.
export REPO_ROOT

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

# setup.sh runs main() on load; strip that one line so we can source its
# functions. Guarded below so a restructure fails loudly instead of silently.
eval "$(sed '/^main "\$@"$/d' "$REPO_ROOT/setup.sh")"

# setup.sh sets `-e`; these tests assert on non-zero exits, so turn it back off.
set +e

PASS=0
FAIL=0

ok() {
  printf '  \033[0;32m✓\033[0m %s\n' "$1"
  PASS=$((PASS + 1))
}

no() {
  printf '  \033[0;31m✗\033[0m %s\n      %s\n' "$1" "$2"
  FAIL=$((FAIL + 1))
}

expect_ok() {
  local desc="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    ok "$desc"
  else
    no "$desc" "[$*] returned non-zero"
  fi
}

for fn in run_brew_sync save_tty_state restore_tty_state; do
  if ! declare -f "$fn" >/dev/null; then
    echo "FATAL: $fn not defined after sourcing setup.sh" >&2
    exit 1
  fi
done

# =============================================================================
# Terminal state helpers, as defined by setup.sh
# =============================================================================

echo "save_tty_state / restore_tty_state"

# Callers pass the snapshot through unconditionally, so the no-tty case (curl
# installs, CI, launchd) must be a silent no-op rather than an error.
expect_ok "restore_tty_state is a no-op on an empty snapshot" restore_tty_state ""
expect_ok "save_tty_state succeeds with or without a tty" save_tty_state
expect_ok "restore_tty_state swallows an unusable snapshot" \
  restore_tty_state "not-a-valid-stty-snapshot"

# Round-trip against a real pty: disabling ONLCR is exactly what a cask
# installer leaves behind, so this proves the guard reverses that specific
# damage rather than merely running without error.
pty_roundtrip() {
  # shellcheck disable=SC2016
  # Single quotes are required: every expansion in this script must be
  # evaluated by the bash running inside the pty, not by this shell.
  python3 -c '
import pty
script = """
eval "$(sed \x27/^main "\\$@"$/d\x27 "$REPO_ROOT/setup.sh")"
set +e
before=$(stty -g </dev/tty)
snap=$(save_tty_state)
stty -onlcr </dev/tty
mangled=$(stty -g </dev/tty)
restore_tty_state "$snap"
after=$(stty -g </dev/tty)
if [ "$before" = "$mangled" ]; then echo PTY_SETUP_FAILED
elif [ "$before" = "$after" ]; then echo PTY_OK
else echo PTY_FAIL
fi
"""
pty.spawn(["bash", "-c", script])
' 2>/dev/null | tr -d '\r'
}

PTY_DESC="restores ONLCR after an installer disables it (real pty)"
if command -v python3 >/dev/null 2>&1; then
  PTY_RESULT="$(pty_roundtrip)"
  case "$PTY_RESULT" in
  *PTY_OK*)
    ok "$PTY_DESC"
    ;;
  *PTY_SETUP_FAILED*)
    no "$PTY_DESC" "could not disable ONLCR, so the test proved nothing"
    ;;
  *)
    no "$PTY_DESC" "terminal modes differ after restore; got [$PTY_RESULT]"
    ;;
  esac
else
  no "$PTY_DESC" "python3 not available"
fi

# =============================================================================
# run_brew_sync
# =============================================================================

BREW_LOG="$WORK_DIR/brew-args"
RESTORE_LOG="$WORK_DIR/restore-calls"
BREW_BUNDLE_RC=0

# Record every brew invocation instead of running it. `brew tap` yielding
# nothing leaves the tap cleanup loops empty.
brew() {
  printf '%s\n' "$*" >>"$BREW_LOG"
  [[ "$1" == "bundle" ]] && return "$BREW_BUNDLE_RC"
  return 0
}

# Brewfile generation is covered by test-profiles.sh, and stubbing it keeps this
# suite from writing into .system/profiles/machines/.
prepare_brewfile() {
  echo "$WORK_DIR/Brewfile"
}

# Tap cleanup shells out to git and the network; neither is under test here.
check_and_remove_broken_taps() { :; }
cleanup_undeclared_taps() { :; }

# Skips the work-group 1Password branch so the test never touches `op`.
is_machine_in_group() { return 1; }

# Observe the guard without depending on a tty being present in this process.
save_tty_state() { echo "SNAPSHOT"; }
restore_tty_state() { printf '%s\n' "${1:-<empty>}" >>"$RESTORE_LOG"; }

# Read as a global by run_brew_sync, same as setup.sh does.
export MACHINE_HOSTNAME="test-host"

run_sync() {
  BREW_BUNDLE_RC="$1"
  : >"$BREW_LOG"
  : >"$RESTORE_LOG"
  run_brew_sync >"$WORK_DIR/out" 2>&1
}

echo "run_brew_sync: brew bundle invocation"

run_sync 0
BUNDLE_CMD="$(grep '^bundle ' "$BREW_LOG")"

if [[ -n "$BUNDLE_CMD" ]]; then
  ok "invokes brew bundle"
else
  no "invokes brew bundle" "no 'brew bundle' call recorded; stubs or run_brew_sync changed shape"
fi

if [[ "$BUNDLE_CMD" != *"--verbose"* ]]; then
  ok "does not pass --verbose"
else
  no "does not pass --verbose" \
    "--verbose makes parallel child installs write cursor motion to the TTY, garbling output"
fi

if [[ "$BUNDLE_CMD" == *"--force-cleanup"* ]]; then
  ok "still passes --force-cleanup"
else
  no "still passes --force-cleanup" "declarative sync dropped; unlisted packages would survive"
fi

if [[ "$BUNDLE_CMD" == *"--file="* ]]; then
  ok "still passes --file="
else
  no "still passes --file=" "would fall back to a global Brewfile instead of the generated one"
fi

echo "run_brew_sync: terminal state guard"

if grep -q '^SNAPSHOT$' "$RESTORE_LOG"; then
  ok "restores the saved terminal state after a successful sync"
else
  no "restores the saved terminal state after a successful sync" \
    "restore_tty_state not called with the save_tty_state snapshot"
fi

if grep -q "Homebrew packages synced" "$WORK_DIR/out"; then
  ok "reports success when brew bundle succeeds"
else
  no "reports success when brew bundle succeeds" "success message missing"
fi

# A failing bundle is the case most likely to leave the tty mangled, so the
# restore must not sit on the success branch.
run_sync 1

if grep -q '^SNAPSHOT$' "$RESTORE_LOG"; then
  ok "restores the saved terminal state after a failed sync"
else
  no "restores the saved terminal state after a failed sync" \
    "restore_tty_state not called on the failure path"
fi

if grep -q "may have failed to install" "$WORK_DIR/out"; then
  ok "warns when brew bundle fails"
else
  no "warns when brew bundle fails" "failure warning missing; a non-zero bundle was swallowed"
fi

echo ""
printf 'passed: %d  failed: %d\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]]
