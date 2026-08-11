#!/usr/bin/env bash
#
# Emits the Context7 API key header as JSON, for use as a Claude Code MCP
# `headersHelper`. The stdio transport took the key as `--api-key` on argv,
# where any local user could read it out of ps; the HTTP transport plus this
# helper keeps it in a 0600 file instead.
#
# Register with:
#   claude mcp add-json context7 --scope user '{
#     "type": "http",
#     "url": "https://mcp.context7.com/mcp",
#     "headersHelper": "'"$HOME"'/.config/.system/mcp/context7-header.sh"
#   }'

set -euo pipefail

key_file="${CONTEXT7_API_KEY_FILE:-$HOME/.config/.system/sensitive/context7-api-key}"

if [[ ! -r "$key_file" ]]; then
  echo "context7: cannot read $key_file; run 'secrets' to inject it" >&2
  exit 1
fi

key=$(tr -d '\n' <"$key_file")

if [[ -z "$key" ]]; then
  echo "context7: $key_file is empty; run 'secrets' to inject it" >&2
  exit 1
fi

printf '{"CONTEXT7_API_KEY":"%s"}\n' "$key"
