#!/usr/bin/env bash

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

FIXTURE_DIR="$(mktemp -d)"
trap 'rm -rf "$FIXTURE_DIR"' EXIT

# shellcheck source=../setup/lib/tailnet.sh
source "$REPO_ROOT/.system/setup/lib/tailnet.sh"

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

echo "tailnet_active_profile_id: real CLI output"

LIST_TWO=$(
  cat <<'EOF'
ID    Tailnet             Account
edec  example.github      someone@github*
d0ll  dolls.example       someone@example.com
EOF
)
expect_eq "reads the ID column, not the marked column" \
  "edec" "$(tailnet_active_profile_id <<<"$LIST_TWO")"

LIST_SECOND_ACTIVE=$(
  cat <<'EOF'
ID    Tailnet             Account
edec  example.github      someone@github
d0ll  dolls.example       someone@example.com*
EOF
)
expect_eq "finds the active row wherever it appears" \
  "d0ll" "$(tailnet_active_profile_id <<<"$LIST_SECOND_ACTIVE")"

LIST_ONE=$(
  cat <<'EOF'
ID    Tailnet         Account
edec  example.github  someone@github*
EOF
)
expect_eq "handles a single profile" "edec" "$(tailnet_active_profile_id <<<"$LIST_ONE")"

echo "tailnet_active_profile_id: no active profile"

LIST_NONE=$(
  cat <<'EOF'
ID    Tailnet             Account
edec  example.github      someone@github
EOF
)
OUT=$(tailnet_active_profile_id <<<"$LIST_NONE")
expect_eq "exits non-zero when nothing is marked active" "1" "$?"
expect_eq "prints nothing when nothing is marked active" "" "$OUT"

OUT=$(tailnet_active_profile_id <<<"")
expect_eq "exits non-zero on empty input" "1" "$?"
expect_eq "prints nothing on empty input" "" "$OUT"

echo "tailnet_normalize"
expect_eq "lowercases" "dolls.example" "$(tailnet_normalize 'Dolls.Example')"
expect_eq "strips surrounding whitespace" "dolls.example" "$(tailnet_normalize '  dolls.example  ')"
expect_eq "strips a trailing newline" "dolls.example" "$(tailnet_normalize 'dolls.example
')"

echo "tailnet_name_matches"
tailnet_name_matches "dolls.example" "dolls.example"
expect_eq "matches identical names" "0" "$?"

tailnet_name_matches "Dolls.Example" "dolls.example  "
expect_eq "matches ignoring case and whitespace" "0" "$?"

tailnet_name_matches "dolls.example" "example.github"
expect_eq "does not match different names" "1" "$?"

tailnet_name_matches "" "example.github"
expect_eq "empty expected name never matches" "1" "$?"

tailnet_name_matches "" ""
expect_eq "empty expected name never matches an empty actual" "1" "$?"

tailnet_name_matches "dolls.example" ""
expect_eq "does not match an empty actual name" "1" "$?"

echo "tailnet_expected_name"
printf 'Dolls.Example\n' >"$FIXTURE_DIR/tailnet"
expect_eq "reads and normalizes the file" "dolls.example" "$(tailnet_expected_name "$FIXTURE_DIR/tailnet")"

tailnet_expected_name "$FIXTURE_DIR/does-not-exist" >/dev/null
expect_eq "exits non-zero when the file is missing" "1" "$?"

: >"$FIXTURE_DIR/empty"
OUT=$(tailnet_expected_name "$FIXTURE_DIR/empty")
expect_eq "an empty file yields an empty name" "" "$OUT"
tailnet_name_matches "$(tailnet_expected_name "$FIXTURE_DIR/empty")" "anything"
expect_eq "an empty file cannot satisfy a match" "1" "$?"

echo ""
printf 'passed: %d  failed: %d\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]]
