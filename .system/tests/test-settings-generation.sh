#!/usr/bin/env bash
#
# Integration tests for setup.sh's @machine marker filtering, run against the
# real claude/settings.jsonc and .system/profiles/profiles.toml.
#
# These pin which machine gets which gated block. Auth in particular:
# apiKeyHelper is a server (nyx) concept; laptops use claude.ai login auth.
#
# Run: bash .system/tests/test-machine-markers.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

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

if ! declare -f preprocess_machine_markers >/dev/null; then
  echo "FATAL: preprocess_machine_markers not defined after sourcing setup.sh" >&2
  exit 1
fi

# Filters the real settings.jsonc as the given machine, echoing the result path.
filter_as() {
  local host="$1"
  # Read as a global by preprocess_machine_markers, same as setup.sh does.
  export MACHINE_HOSTNAME="$host"
  preprocess_machine_markers "$REPO_ROOT/claude/settings.jsonc" "$WORK_DIR/$host.jsonc" "//"
}

expect_has() {
  local host="$1" needle="$2"
  if grep -q -- "$needle" "$WORK_DIR/$host.jsonc"; then
    ok "$host has $needle"
  else
    no "$host has $needle" "not found in filtered output"
  fi
}

expect_lacks() {
  local host="$1" needle="$2"
  if grep -q -- "$needle" "$WORK_DIR/$host.jsonc"; then
    no "$host lacks $needle" "unexpectedly present in filtered output"
  else
    ok "$host lacks $needle"
  fi
}

for host in nyx MacBook-Pro-HF7C7K3WJX athena; do
  filter_as "$host" || {
    echo "FATAL: filtering failed for $host" >&2
    exit 1
  }
done

# Match the JSON key, not a bare word: comments legitimately mention the name.
API_KEY_HELPER='"apiKeyHelper"'

echo "auth: apiKeyHelper is server-only"
expect_has nyx "$API_KEY_HELPER"
expect_lacks MacBook-Pro-HF7C7K3WJX "$API_KEY_HELPER"
expect_lacks athena "$API_KEY_HELPER"

WORK_PLUGIN='"Laurel@Laurel"'

echo "work-gated blocks stay on the work machine"
expect_has MacBook-Pro-HF7C7K3WJX "$WORK_PLUGIN"
expect_has MacBook-Pro-HF7C7K3WJX 'slack@claude-plugins-official'
expect_lacks nyx "$WORK_PLUGIN"
expect_lacks athena "$WORK_PLUGIN"

# Removing a gated block can strand a trailing comma, and athena/nyx output
# cannot be exercised any other way from this machine.
echo "every machine's filtered output survives the generation pipeline"
for host in nyx MacBook-Pro-HF7C7K3WJX athena; do
  if sed -E 's/,([[:space:]]*[]{}])/\1/g' "$WORK_DIR/$host.jsonc" | jq -e . >/dev/null 2>&1; then
    ok "$host produces valid JSON"
  else
    no "$host produces valid JSON" "jq rejected the generated settings"
  fi
done

# configure_claude redirects with `>`, which truncates on open. A failing jq
# must not be allowed to leave an empty settings.json behind.
echo "a failed generation leaves the existing settings.json intact"
FAKE_DOTFILES="$WORK_DIR/fake"
mkdir -p "$FAKE_DOTFILES/claude"
printf '{ this is not valid json ]]]\n' >"$FAKE_DOTFILES/claude/settings.jsonc"
printf '{"kept": true}\n' >"$FAKE_DOTFILES/claude/settings.json"

(
  # Both read as globals by configure_claude.
  export DOTFILES="$FAKE_DOTFILES"
  export MACHINE_HOSTNAME="athena"
  configure_claude
) >/dev/null 2>&1
GEN_RC=$?

if [[ "$GEN_RC" -ne 0 ]]; then
  ok "configure_claude reports failure"
else
  no "configure_claude reports failure" "returned 0 for a malformed source file"
fi

if [[ "$(cat "$FAKE_DOTFILES/claude/settings.json")" == '{"kept": true}' ]]; then
  ok "previous settings.json is preserved"
else
  no "previous settings.json is preserved" "got [$(cat "$FAKE_DOTFILES/claude/settings.json")]"
fi

echo ""
printf 'passed: %d  failed: %d\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]]
