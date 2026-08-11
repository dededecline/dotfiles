#!/usr/bin/env bash

tailnet_active_profile_id() {
  awk 'NF >= 2 && $NF ~ /\*$/ { print $1; found = 1 } END { exit !found }'
}

tailnet_normalize() {
  printf '%s' "${1:-}" | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]'
}

tailnet_name_matches() {
  local expected actual
  expected=$(tailnet_normalize "${1:-}")
  actual=$(tailnet_normalize "${2:-}")
  [[ -n "$expected" && "$expected" == "$actual" ]]
}

tailnet_expected_name() {
  local file="${1:?expected-name file required}"
  [[ -f "$file" ]] || return 1
  tailnet_normalize "$(cat "$file")"
}
