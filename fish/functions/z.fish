function z --description "Connect to k8s cluster via zli"
    set -l zli_cmd_file "$HOME/.config/sensitive/zli-command"

    if not test -f "$zli_cmd_file"
        echo "ZLI command not configured. Run 'secrets' to inject from 1Password."
        return 1
    end

    set -l cmd_template (cat "$zli_cmd_file")
    # Replace placeholders with arguments: {1} = env, {2} = region
    set -l cmd (string replace -a '{1}' $argv[1] $cmd_template | string replace -a '{2}' $argv[2])
    eval $cmd
end
