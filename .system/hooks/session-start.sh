#!/bin/bash

cat <<EOF
## Project State

Branch: $(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "N/A")
Changes: $(git status --short 2>/dev/null | wc -l) files modified

## Recent Commits
$(git log --oneline -5 2>/dev/null)
EOF
