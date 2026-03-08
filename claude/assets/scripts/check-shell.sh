#!/bin/bash

# PostToolUse hook: runs shellcheck and shfmt on shell scripts after Edit/Write
input=$(cat)
file_path=$(echo "$input" | jq -r '.tool_input.file_path')

# Only process .sh/.bash files
[[ "$file_path" =~ \.(sh|bash)$ ]] || exit 0
[[ -f "$file_path" ]] || exit 0

issues=""

# Shellcheck
if ! sc_out=$(shellcheck "$file_path" 2>&1); then
  issues+="shellcheck:
${sc_out}

"
fi

# shfmt (diff mode)
if ! fmt_out=$(shfmt -d "$file_path" 2>&1); then
  issues+="shfmt:
${fmt_out}"
fi

if [[ -n "$issues" ]]; then
  jq -n --arg reason "$issues" --arg file "$file_path" '{
    decision: "block",
    reason: ("Shell script issues in " + $file + ":\n\n" + $reason)
  }'
fi
