#!/usr/bin/env bash
#
# Structural invariants for the credential system.
#
# These are static assertions rather than behavioural tests, because every
# injection path needs a live 1Password session. They exist to pin the specific
# regressions found in the credential audit, each of which was silent in normal
# use and would not be caught by any other suite.
#
# Run: bash .system/tests/test-secrets-invariants.sh

# Assertions are grep patterns matching literal shell source, so `$output` and
# friends must reach grep unexpanded. Single quotes are correct throughout.
# shellcheck disable=SC2016

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

SECRETS="$REPO_ROOT/.system/setup/secrets.sh"
TEMPLATES="$REPO_ROOT/.system/templates"

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

expect_absent() {
  local desc="$1" pattern="$2" file="$3"
  if grep -qE "$pattern" "$file"; then
    no "$desc" "found [$pattern] in $(basename "$file")"
  else
    ok "$desc"
  fi
}

expect_present() {
  local desc="$1" pattern="$2" file="$3"
  if grep -qE "$pattern" "$file"; then
    ok "$desc"
  else
    no "$desc" "missing [$pattern] in $(basename "$file")"
  fi
}

echo ""
echo "an unanswered [l/r] prompt must not push to 1Password"
# `l | L | *)` meant a bare Enter silently overwrote the remote document.
expect_absent "no 'l | L | *' case fallthrough" '^\s*l \| L \| \*\)' "$SECRETS"
expect_present "a bare '*' arm exists to absorb unrecognised input" '^\s*\*\)' "$SECRETS"

echo ""
echo "the [l/r] prompt exists in exactly one place"
# It was duplicated three times, and the bare-Enter bug appeared in two of those
# copies independently. A fourth caller must reuse the helper, not re-inline it.
prompt_copies=$(grep -c 'Action \[l/r\]' "$SECRETS")
if [[ "$prompt_copies" -eq 1 ]]; then
  ok "exactly 1 copy of the prompt"
else
  no "exactly 1 copy of the prompt" "found $prompt_copies; extract into sync_op_document instead"
fi
expect_present "sync_op_document exists" '^sync_op_document\(\)' "$SECRETS"

echo ""
echo "work-specific Claude rules come from 1Password, not the repo"
expect_present "inject_claude_rules exists" '^inject_claude_rules\(\)' "$SECRETS"
expect_present "inject_secrets calls inject_claude_rules" 'inject_claude_rules' "$SECRETS"
if git -C "$REPO_ROOT" check-ignore -q claude/rules/pr-lint.md; then
  ok "claude/rules/pr-lint.md is not committable"
else
  no "claude/rules/pr-lint.md is not committable" "it names real ticket prefixes and internal services"
fi
for generic in claude/rules/code-comments.md claude/rules/context7.md; do
  if git -C "$REPO_ROOT" check-ignore -q "$generic"; then
    no "$generic is tracked" "generic rules should survive a fresh clone"
  else
    ok "$generic is tracked"
  fi
done

echo ""
echo "credentials are never written at the ambient umask"
expect_present "inject_template stages through mktemp" 'staged=\$\(mktemp\)' "$SECRETS"
expect_present "inject_template applies umask 077" 'umask 077' "$SECRETS"
# op inject writing straight to the destination both raced chmod and truncated
# a working credential when the 1Password lookup failed.
expect_absent "op inject never targets the destination directly" '\-o "\$output"' "$SECRETS"

echo ""
echo "the sensitive directory is not world-listable"
expect_present "inject_secrets chmods SENSITIVE_DIR to 700" 'chmod 700 "\$SENSITIVE_DIR"' "$SECRETS"
expect_present "claude-skills subdirs are chmodded 700" 'chmod 700 "\$output_dir"' "$SECRETS"

echo ""
echo "a skill archive cannot be lost to a failed extract"
expect_present "archive extracts to a staging dir" 'staging="\$\{output_dir\}\.incoming"' "$SECRETS"

echo ""
echo "an unknown hostname fails loudly instead of skipping every secret"
expect_present "inject_secrets validates the hostname" 'get_machine_groups "\$MACHINE_HOSTNAME"' "$SECRETS"

echo ""
echo "every template referenced by secrets.sh exists"
# The gh-hosts.tpl branch guarded a template that had never existed, so the
# whole path was silently dead.
while IFS= read -r tpl; do
  if [[ -f "$TEMPLATES/$tpl" ]]; then
    ok "$tpl exists"
  else
    no "$tpl exists" "referenced by secrets.sh but not present in .system/templates/"
  fi
done < <(grep -oE '\$TEMPLATES_DIR/[A-Za-z0-9._-]+\.tpl' "$SECRETS" | sed 's|\$TEMPLATES_DIR/||' | sort -u)

echo ""
echo "every template carrying an op:// reference is actually used"
while IFS= read -r tpl; do
  name="$(basename "$tpl")"
  if grep -q "$name" "$SECRETS"; then
    ok "$name is referenced"
  else
    no "$name is referenced" "has op:// refs but nothing in secrets.sh injects it"
  fi
done < <(grep -rlE 'op://' "$TEMPLATES" --include='*.tpl' | sort)

echo ""
echo "every op:// token in a template is a full vault/item/field reference"
bad_refs=$(grep -rnoE 'op://[^"}]*' "$TEMPLATES" --include='*.tpl' |
  grep -vE ':op://[^/"}]+/[^/"}]+/[^/"}]+' || true)
if [[ -z "$bad_refs" ]]; then
  ok "no malformed op:// token in .system/templates"
else
  no "no malformed op:// token in .system/templates" "$(echo "$bad_refs" | tr '\n' ' ')"
fi

echo ""
echo "no AWS account id is hardcoded in tracked shell or fish sources"
# awsall.fish carried the production account id in a public repo.
# Word boundaries, not [^0-9] on both sides: an id at end-of-line has no
# trailing character, which is the common case (`set -l acct 123456789012`).
acct_hits=$(
  git -C "$REPO_ROOT" grep -lE '\b[0-9]{12}\b' -- \
    '*.fish' '*.sh' 2>/dev/null | grep -v 'tests/' || true
)
if [[ -z "$acct_hits" ]]; then
  ok "no 12-digit account ids in tracked *.fish or *.sh"
else
  no "no 12-digit account ids in tracked *.fish or *.sh" "check: $(echo "$acct_hits" | tr '\n' ' ')"
fi

echo ""
echo "MCP header helpers exist and are executable"
for h in context7-header.sh warpstream-header.sh; do
  path="$REPO_ROOT/.system/mcp/$h"
  if [[ -x "$path" ]]; then
    ok "$h is executable"
  else
    no "$h is executable" "missing or not executable: $path"
  fi
done
# A helper holding a literal credential would defeat the whole point.
for h in context7-header.sh warpstream-header.sh; do
  expect_absent "$h contains no literal key" 'ctx7sk-[A-Za-z0-9]|[A-Za-z0-9]{40,}' "$REPO_ROOT/.system/mcp/$h"
done

echo ""
echo "the gitignore allowlist does not ignore any tracked file"
ignored_tracked=$(git -C "$REPO_ROOT" ls-files | git -C "$REPO_ROOT" check-ignore --stdin 2>/dev/null || true)
if [[ -z "$ignored_tracked" ]]; then
  ok "no tracked file is matched by .gitignore"
else
  no "no tracked file is matched by .gitignore" "$(echo "$ignored_tracked" | head -5 | tr '\n' ' ')"
fi

echo ""
echo "known credential paths stay ignored"
for p in \
  .system/sensitive/github-pat \
  .system/sensitive/warpstream.fish \
  .system/sensitive/context7-api-key \
  git/config \
  gh/hosts.yml \
  fish/functions/clone.fish \
  claude/settings.json \
  context7/credentials.json \
  somenewtool/token.json; do
  if git -C "$REPO_ROOT" check-ignore -q "$p"; then
    ok "$p is ignored"
  else
    no "$p is ignored" "would be committable"
  fi
done

echo ""
printf 'passed: %d  failed: %d\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]]
