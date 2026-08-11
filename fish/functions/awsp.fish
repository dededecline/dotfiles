function awsp --description "Switch the active AWS profile"
    if test (count $argv) -eq 0
        if set -q AWS_PROFILE
            echo "active: $AWS_PROFILE"
        else
            echo "active: default (AWS_PROFILE unset) -> dev admin"
        end
        echo
        __awsp_profiles | awk -F'\t' '{printf "  %-18s %s\n", $1, $2}'
        return 0
    end

    set -l target $argv[1]

    if contains -- $target - off none clear
        set -e AWS_PROFILE
        echo "AWS_PROFILE cleared, falling back to [default] (dev admin)"
        return 0
    end

    if not contains -- $target (__awsp_profiles | cut -f1)
        if not contains -- $target (aws configure list-profiles)
            echo "awsp: no such profile: $target" >&2
            echo "run 'awsp' with no arguments to list profiles" >&2
            return 1
        end
    end

    set -gx AWS_PROFILE $target
    echo "AWS_PROFILE = $target"
end
