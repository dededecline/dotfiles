#!/bin/bash

# PreToolUse hook: enforce git workflow rules
# - All repos: no Co-Authored-By trailers or --author overrides
# - Pinginc repos: conventional commit format with Linear ID
# - Pinginc repos: no pushing directly to main/master

input=$(cat)
command=$(echo "$input" | jq -r '.tool_input.command // empty')

# Only process git commit and git push commands
[[ "$command" =~ ^git\ (commit|push) ]] || exit 0

cwd=$(echo "$input" | jq -r '.cwd // empty')
cwd="${cwd:-$PWD}"

# Detect pinginc repo
is_pinginc=false
if git -C "$cwd" remote -v 2>/dev/null | grep -qi 'pinginc'; then
  is_pinginc=true
fi

# Check 1 (all repos): block Co-Authored-By trailers
if [[ "$command" =~ ^git\ commit ]]; then
  if echo "$command" | grep -qi 'co-authored-by'; then
    jq -n '{
      decision: "block",
      reason: "Do not add Co-Authored-By trailers. Use the users own git identity exclusively."
    }'
    exit 0
  fi

  # Check 1b (all repos): block --author overrides
  if echo "$command" | grep -qi '\-\-author'; then
    jq -n '{
      decision: "block",
      reason: "Do not use --author overrides. Use the users own git identity exclusively."
    }'
    exit 0
  fi

  # Check 2 (pinginc repos): conventional commit format with Linear ID
  if [[ "$is_pinginc" == "true" ]]; then
    # Extract the commit message from -m flag
    msg=""
    if [[ "$command" =~ -m\ \" ]]; then
      # Double-quoted message: extract between first " after -m and closing "
      msg=$(echo "$command" | sed -n 's/.*-m "\([^"]*\)".*/\1/p')
    elif [[ "$command" =~ -m\ \' ]]; then
      # Single-quoted message: extract between first ' after -m and closing '
      msg=$(echo "$command" | sed -n "s/.*-m '\\([^']*\\)'.*/\\1/p")
    elif [[ "$command" =~ -m\ \$\( ]]; then
      # HEREDOC-style: -m "$(cat <<'EOF' ... EOF )" — extract first line of content
      msg=$(echo "$command" | sed -n '/cat <</{n;s/^[[:space:]]*//;p;}' | head -1)
    fi

    if [[ -n "$msg" ]]; then
      # First line must match: type: LINEAR-ID: description
      first_line=$(echo "$msg" | head -1)
      if ! echo "$first_line" | grep -qE '^(feat|fix|chore|docs|test|refactor|ci|build|perf|style|revert): [A-Z]+-[0-9]+: .+'; then
        jq -n --arg msg "$first_line" '{
          decision: "block",
          reason: ("Commit message must follow: type: LINEAR-ID: description\nGot: " + $msg + "\nExample: feat: ENG-123: add user authentication")
        }'
        exit 0
      fi
    fi
  fi
fi

# Check 3 (pinginc repos): no pushing to main/master
if [[ "$command" =~ ^git\ push ]] && [[ "$is_pinginc" == "true" ]]; then
  # Explicit push to main/master
  if echo "$command" | grep -qE 'git push .*([ ]|:)(main|master)(\s|$)'; then
    jq -n '{
      decision: "block",
      reason: "Do not push directly to main/master in work repos. Create a feature branch and open a PR instead."
    }'
    exit 0
  fi

  # Implicit push (no refspec) — check current branch
  if ! echo "$command" | grep -qE 'git push \S+ \S+'; then
    current_branch=$(git -C "$cwd" rev-parse --abbrev-ref HEAD 2>/dev/null)
    if [[ "$current_branch" == "main" || "$current_branch" == "master" ]]; then
      jq -n '{
        decision: "block",
        reason: "You are on main/master. Do not push directly to main/master in work repos. Create a feature branch and open a PR instead."
      }'
      exit 0
    fi
  fi
fi
