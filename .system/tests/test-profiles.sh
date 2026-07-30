#!/usr/bin/env bash
#
# Unit tests for .system/setup/lib/profiles.sh
#
# Run: bash .system/tests/test-profiles.sh

# Deliberately no `set -e`: these tests assert on non-zero exit statuses.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

FIXTURE_DIR="$(mktemp -d)"
trap 'rm -rf "$FIXTURE_DIR"' EXIT

cat >"$FIXTURE_DIR/profiles.toml" <<'EOF'
[athena]
groups = ["all", "laptop", "personal"]

[nyx]
groups = ["all", "server"]

[groupless]
EOF

export PROFILES_TOML="$FIXTURE_DIR/profiles.toml"
# shellcheck source=../setup/lib/profiles.sh
source "$REPO_ROOT/.system/setup/lib/profiles.sh"

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

expect_eq() {
  local desc="$1" want="$2" got="$3"
  if [[ "$want" == "$got" ]]; then
    ok "$desc"
  else
    no "$desc" "want [$want], got [$got]"
  fi
}

expect_contains() {
  local desc="$1" needle="$2" haystack="$3"
  if [[ "$haystack" == *"$needle"* ]]; then
    ok "$desc"
  else
    no "$desc" "[$haystack] does not contain [$needle]"
  fi
}

# Runs get_machine_groups, capturing stdout/stderr/status separately.
run_groups() {
  RG_OUT="$(get_machine_groups "$1" 2>"$FIXTURE_DIR/stderr")"
  RG_RC=$?
  RG_ERR="$(cat "$FIXTURE_DIR/stderr")"
}

echo "get_machine_groups: known hostnames"
run_groups athena
expect_eq "returns groups plus the hostname" "all laptop personal athena" "$RG_OUT"
expect_eq "exits zero" "0" "$RG_RC"
expect_eq "writes nothing to stderr" "" "$RG_ERR"

run_groups groupless
expect_eq "known host with no groups line defaults to all" "all groupless" "$RG_OUT"
expect_eq "known host with no groups line exits zero" "0" "$RG_RC"

echo "get_machine_groups: unknown hostnames"
run_groups ghost-machine
expect_eq "unknown hostname exits non-zero" "1" "$RG_RC"
expect_eq "unknown hostname writes nothing to stdout" "" "$RG_OUT"
expect_contains "error names the unknown hostname" "ghost-machine" "$RG_ERR"
expect_contains "error names the profiles file" "profiles.toml" "$RG_ERR"

run_groups ""
expect_eq "empty hostname exits non-zero" "1" "$RG_RC"
expect_eq "empty hostname writes nothing to stdout" "" "$RG_OUT"

echo "is_machine_in_group"
is_machine_in_group athena laptop
expect_eq "true when known host is in the group" "0" "$?"

is_machine_in_group athena server
expect_eq "false when known host is not in the group" "1" "$?"

is_machine_in_group ghost-machine work 2>"$FIXTURE_DIR/stderr"
expect_eq "non-zero for an unknown host" "1" "$?"
expect_contains "propagates the unknown-host error" "ghost-machine" "$(cat "$FIXTURE_DIR/stderr")"

echo ""
printf 'passed: %d  failed: %d\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]]
