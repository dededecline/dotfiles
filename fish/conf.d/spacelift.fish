set -l _spacelift_env $HOME/.config/.system/sensitive/spacelift-api-key.fish
if test -r $_spacelift_env
    source $_spacelift_env
end
