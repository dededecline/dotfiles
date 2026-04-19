function code-audit --description "Running codebase audit"
    if not git rev-parse --is-inside-work-tree &>/dev/null
        set_color e78284
        echo "Not a git repository"
        set_color normal
        return 1
    end

    set -l hdr (set_color --bold babbf1)
    set -l cnt (set_color e5c890)
    set -l txt (set_color c6d0f5)
    set -l hsh (set_color ca9ee6)
    set -l rst (set_color normal)

    echo $hdr"Most frequently changed files in the last year"$rst
    git log --format=format: --name-only --since="1 year ago" \
        | sed '/^$/d' | sort | uniq -c | sort -nr | head -20 \
        | awk -v c="$cnt" -v t="$txt" -v r="$rst" '{printf "%s%7d  %s%s%s\n", c, $1, t, $2, r}'
    echo

    echo $hdr"Contributors by commit count (excluding merges)"$rst
    git --no-pager shortlog -sn --no-merges \
        | awk -F'\t' -v c="$cnt" -v t="$txt" -v r="$rst" '{printf "%s%7d  %s%s%s\n", c, $1+0, t, $2, r}'
    echo

    echo $hdr"Files most associated with bug fixes"$rst
    git log -i -E --grep="fix|bug|broken" --name-only --format='' \
        | sed '/^$/d' | sort | uniq -c | sort -nr | head -20 \
        | awk -v c="$cnt" -v t="$txt" -v r="$rst" '{printf "%s%7d  %s%s%s\n", c, $1, t, $2, r}'
    echo

    echo $hdr"Commit activity by month"$rst
    git log --format='%ad' --date=format:'%Y-%m' | sort | uniq -c \
        | awk -v c="$cnt" -v t="$txt" -v r="$rst" '{printf "%s%7d  %s%s%s\n", c, $1, t, $2, r}'
    echo

    echo $hdr"Emergency commits (last year)"$rst
    git log --oneline --since="1 year ago" \
        | grep -iE 'revert|hotfix|emergency|rollback' \
        | awk -v h="$hsh" -v t="$txt" -v r="$rst" '{id=$1; $1=""; printf "%s%9s  %s%s%s\n", h, id, t, substr($0,2), r}'
end
