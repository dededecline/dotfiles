function clone --description "Clone a work repo with archive check"
    set repo $argv[1]
    set org "{{ op://Private/work-cli/org }}"
    set isArchived (gh repo view $org/$repo --json isArchived | jq .isArchived)

    if test "$isArchived" = "true"
        read -P "Repo is archived, do you want to proceed? (y/n) " ans
        set ans (string lower $ans)
        if string match -qr '^(no|n)$' $ans
            echo 'exiting'
            return
        else if not string match -qr '^(yes|y)$' $ans
            echo 'invalid input, exiting'
            return
        end
    end

    git clone git@github.com:$org/$repo.git

    read -P "Would you like to open this repo? (y/n) " ans
    set ans (string lower $ans)
    if string match -qr '^(yes|y)$' $ans
        nvim $repo
    end
end
