#!/bin/bash

# PostToolUse hook: formats, lints, and type-checks Python files after Edit/Write.
# Auto-applies `ruff format` and `ruff check --fix`, then blocks on any remaining
# lint violations or basedpyright type errors.
input=$(cat)
file_path=$(echo "$input" | jq -r '.tool_input.file_path')

# Only process .py/.pyi files
[[ "$file_path" =~ \.pyi?$ ]] || exit 0
[[ -f "$file_path" ]] || exit 0
command -v ruff >/dev/null 2>&1 || exit 0

issues=""

# Auto-format and auto-fix (these mutate the file)
ruff format "$file_path" >/dev/null 2>&1
ruff check --fix "$file_path" >/dev/null 2>&1

# Report any lint violations ruff could not fix automatically
if ! lint_out=$(ruff check "$file_path" 2>&1); then
  issues+="ruff:
${lint_out}

"
fi

# Type check (read-only): block on errors only, not warnings
if command -v basedpyright >/dev/null 2>&1; then
  type_json=$(basedpyright --outputjson "$file_path" 2>/dev/null)
  err_count=$(echo "$type_json" | jq -r '.summary.errorCount // 0')
  if [[ "$err_count" =~ ^[0-9]+$ ]] && ((err_count > 0)); then
    type_out=$(echo "$type_json" | jq -r '
      .generalDiagnostics[]
      | select(.severity == "error")
      | "  \(.file):\(.range.start.line + 1):\(.range.start.character + 1) - \(.message) (\(.rule))"')
    issues+="basedpyright (${err_count} error(s)):
${type_out}"
  fi
fi

if [[ -n "$issues" ]]; then
  jq -n --arg reason "$issues" --arg file "$file_path" '{
    decision: "block",
    reason: ("Python issues in " + $file + ":\n\n" + $reason)
  }'
fi
