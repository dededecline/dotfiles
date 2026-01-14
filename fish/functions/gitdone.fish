function gitdone --description "Switch to default branch and pull"
    set default_branch (git remote show origin | grep 'HEAD branch' | sed 's/.*: //')
    git checkout $default_branch
    git pull
end
