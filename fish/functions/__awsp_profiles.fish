function __awsp_profiles --description "List AWS profiles with account and role"
    set -l config $AWS_CONFIG_FILE
    test -n "$config"; or set config $HOME/.aws/config
    test -r "$config"; or return 1

    awk '
        /^\[default\]/ { p = "default"; next }
        /^\[profile /  { p = $2; sub(/\]$/, "", p); next }
        /^\[/          { p = ""; next }
        p != "" && $1 == "sso_account_id" { acct[p] = $3 }
        p != "" && $1 == "sso_role_name"  { role[p] = $3; order[++n] = p }
        END {
            for (i = 1; i <= n; i++)
                printf "%s\t%s %s\n", order[i], acct[order[i]], role[order[i]]
        }
    ' $config
end
