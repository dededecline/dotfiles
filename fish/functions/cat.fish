# Smart cat: uses glow for markdown, bat for everything else
function cat --wraps=bat --description "View files with glow for markdown, bat for others"
    set -l md_files
    set -l other_files
    set -l flags

    for arg in $argv
        if string match -q -- '-*' $arg
            set -a flags $arg
        else if string match -qri '\.md$|\.markdown$' $arg
            set -a md_files $arg
        else
            set -a other_files $arg
        end
    end

    # Render markdown files with glow
    for file in $md_files
        glow $file
    end

    # Render other files with bat
    if test (count $other_files) -gt 0
        bat --paging=never $flags $other_files
    end

    # If no files provided, pass through to bat (for piped input)
    if test (count $md_files) -eq 0 -a (count $other_files) -eq 0
        bat --paging=never $flags
    end
end
