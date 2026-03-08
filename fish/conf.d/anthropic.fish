set -l api_key_file "$HOME/.config/.system/sensitive/anthropic-api-key"
if test -f "$api_key_file"
    set -gx ANTHROPIC_API_KEY (string trim (cat $api_key_file))
end
