# WarpStream
fish_add_path $HOME/.warpstream

set -l _warpstream_env $HOME/.config/.system/sensitive/warpstream.fish
if test -r $_warpstream_env
    source $_warpstream_env
end
