function awsall --description "Run AWS command across all regions"
    set -lx AWS_PAGER ""

    # Read from ~/.aws/config instead of hardcoding: this file is tracked in a
    # public repo. An unreadable config leaves this empty, which forces the
    # confirmation prompt below rather than silently disabling it.
    set -l prod_account (__awsp_account_id prod-admin)

    set -l confirmed no
    if contains -- --yes-prod $argv
        set confirmed yes
        set argv (string match -v -- --yes-prod $argv)
    end

    if string match -q -- '*--region*' "$argv"
        echo "You cannot use --region flag while using awsall"
        return 1
    end

    set -l caller (aws sts get-caller-identity --query '[Account,Arn]' --output text 2>/dev/null | string split \t)
    if test (count $caller) -lt 2
        echo "awsall: could not resolve AWS identity, try 'aws sso login --sso-session laurel'" >&2
        return 1
    end

    if test "$caller[1]" = "$prod_account" -o -z "$prod_account"; and test "$confirmed" = no
        if test -z "$prod_account"
            echo "awsall: cannot read prod-admin account from AWS config, confirming to be safe"
        else
            echo "awsall: this fans out across every region in PRODUCTION"
        end
        echo "  account: $caller[1]"
        echo "  role:    $caller[2]"
        if not status is-interactive
            echo "awsall: refusing non-interactively, pass --yes-prod to override" >&2
            return 1
        end
        read -l -P "continue? [y/N] " reply
        if not string match -qir '^y' -- $reply
            echo aborted
            return 1
        end
    end

    for region in (aws ec2 describe-regions --query "Regions[].RegionName" --output text | tr '\t' '\n' | sort -r)
        echo ------
        echo $region
        echo ------
        echo
        aws $argv --region $region
        sleep 2
    end
end
