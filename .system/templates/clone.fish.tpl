function clone --description "Clone work repos with archive and existence checks"
    argparse h/help s/silent -- $argv
    or return 1

    set -l org "{{ op://Private/work-cli/org }}"

    if set -q _flag_help
        echo "usage: clone [-s|--silent] <repo>..."
        echo
        echo "Clones git@github.com:$org/<repo>.git for each name given."
        echo
        echo "  -s, --silent  clone archived repos without asking, and do not"
        echo "                offer to open the result in zed"
        echo
        echo "The editor prompt is only offered when a single repo is cloned."
        return 0
    end

    if not command -q gh
        echo "clone: gh is not installed, run 'brew install gh'" >&2
        return 1
    end

    # Rejects an uninjected template without matching on op://, which op inject scans for.
    if not string match -qr -- '^[A-Za-z0-9._-]+$' "$org"
        echo "clone: work org is not configured, run 'secrets'" >&2
        return 1
    end

    if test (count $argv) -eq 0
        echo "clone: no repository given" >&2
        echo "usage: clone [-s|--silent] <repo>..." >&2
        return 1
    end

    set -l repos
    set -l failed
    set -l seen

    for arg in $argv
        set -l name $arg
        if string match -q -- "$org/*" $name
            set name (string replace -- "$org/" "" $name)
        end
        set name (string replace -r -- '\.git$' '' $name)

        # Dedupe before validating: a repeated bad name is otherwise reported and counted twice.
        if contains -- "$name" $seen
            continue
        end
        set -a seen "$name"

        if test -z "$name"; or string match -q -- '*/*' $name
            echo "clone: not a $org repo: $arg" >&2
            set -a failed $arg
        else if test -e $name
            echo "clone: already present in "(pwd)": $name" >&2
            set -a failed $name
        else
            set -a repos $name
        end
    end

    set -l resolved
    set -l archived

    for repo in $repos
        set -l out (gh repo view $org/$repo --json isArchived -q .isArchived 2>&1)
        set -l gh_status $status

        if test $gh_status -ne 0
            # A 404 and a rejected token both exit 1, so they are told apart by gh's own text.
            if string match -q -- '*Could not resolve to a Repository*' "$out"
                echo "clone: no such repo, or no access to it: $org/$repo" >&2
            else
                echo "clone: gh repo view failed for $org/$repo (exit $gh_status)" >&2
                for line in $out
                    echo "  $line" >&2
                end
            end
            set -a failed $repo
            continue
        end

        # gh's stderr shares this capture, so the flag is matched as a whole line.
        if contains -- true $out
            set -a archived $repo
        end
        set -a resolved $repo
    end

    set -l to_clone $resolved

    if test (count $archived) -gt 0; and not set -q _flag_silent
        echo "clone: archived: $archived"
        set -l consent no
        if status is-interactive
            read -l -P "clone anyway? [y/N] " reply
            if string match -qir '^y' -- $reply
                set consent yes
            end
        else
            echo "clone: skipping archived repos non-interactively, pass --silent to clone them" >&2
        end

        if test "$consent" = no
            set to_clone
            for repo in $resolved
                if contains -- $repo $archived
                    set -a failed $repo
                else
                    set -a to_clone $repo
                end
            end
        end
    end

    set -l cloned
    for repo in $to_clone
        if git clone git@github.com:$org/$repo.git
            set -a cloned $repo
        else
            echo "clone: git clone failed: $org/$repo" >&2
            set -a failed $repo
        end
    end

    set -l total (math (count $cloned) + (count $failed))
    if test $total -gt 1
        echo "clone: cloned "(count $cloned)" of $total"
        if test (count $failed) -gt 0
            echo "clone: failed: $failed" >&2
        end
    end

    if test (count $cloned) -eq 1; and not set -q _flag_silent
        if status is-interactive; and command -q zed
            read -l -P "open $cloned in zed? [y/N] " reply
            if string match -qir '^y' -- $reply
                zed $cloned
            end
        end
    end

    if test (count $failed) -gt 0
        return 1
    end
    return 0
end
