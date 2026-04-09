function gitrefresh --description "Run gitdone in all subdirectories"
    for d in */
        cd $d
        gitdone
        cd ..
    end
end
