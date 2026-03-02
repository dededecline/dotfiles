function empty --description "Create empty commit for CI"
    set -l ci_file "$HOME/.config/.system/sensitive/ci-identity"

    if not test -f "$ci_file"
        echo "CI identity not configured. Run 'secrets' to inject from 1Password."
        return 1
    end

    set -l ci_name (head -1 "$ci_file")
    set -l ci_email (tail -1 "$ci_file")

    git -c user.name="$ci_name" -c user.email="$ci_email" commit -m 'empty' --allow-empty
    git push
end
