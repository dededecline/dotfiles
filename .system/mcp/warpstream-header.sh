#!/usr/bin/env bash
#
# Emits the WarpStream MCP API key header as JSON, for use as a Claude Code MCP
# `headersHelper`. Reads .system/sensitive/warpstream.fish, which stays the
# single rotation point, so WARPSTREAM_MCP_API_KEY no longer has to be exported
# into every shell just so ${VAR} interpolation could reach it.
#
# Register with:
#   claude mcp add-json warpstream --scope user '{
#     "type": "http",
#     "url": "https://console.warpstream.com/api/v1/mcp",
#     "headersHelper": "'"$HOME"'/.config/.system/mcp/warpstream-header.sh"
#   }'

set -euo pipefail

creds="${WARPSTREAM_CREDS_FILE:-$HOME/.config/.system/sensitive/warpstream.fish}"

if [[ ! -r "$creds" ]]; then
  echo "warpstream: cannot read $creds" >&2
  exit 1
fi

# Sourced with fish rather than parsed with sed: the file is fish syntax, so
# fish is the only thing that resolves its quoting correctly.
if ! key=$(fish -c "source '$creds'; printf '%s' \$WARPSTREAM_MCP_API_KEY" 2>/dev/null); then
  echo "warpstream: failed to source $creds" >&2
  exit 1
fi

if [[ -z "$key" ]]; then
  echo "warpstream: WARPSTREAM_MCP_API_KEY not set in $creds" >&2
  exit 1
fi

printf '{"warpstream-api-key":"%s"}\n' "$key"
