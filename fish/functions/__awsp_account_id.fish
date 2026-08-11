function __awsp_account_id --description "Print the sso_account_id for one AWS profile"
    set -l profile $argv[1]
    test -n "$profile"; or return 1

    set -l config $AWS_CONFIG_FILE
    test -n "$config"; or set config $HOME/.aws/config
    test -r "$config"; or return 1

    awk -v want="$profile" '
        /^\[default\]/ { p = "default"; next }
        /^\[profile /  { p = $2; sub(/\]$/, "", p); next }
        /^\[/          { p = ""; next }
        p == want && $1 == "sso_account_id" { print $3; exit }
    ' $config
end
