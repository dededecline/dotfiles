function awsall --description "Run AWS command across all regions"
    set -lx AWS_PAGER ""

    if string match -q -- '*--region*' "$argv"
        echo "You cannot use --region flag while using awsall"
        return 1
    end

    for region in (aws ec2 describe-regions --query "Regions[].RegionName" --output text | tr '\t' '\n' | sort -r)
        echo "------"
        echo $region
        echo "------"
        echo
        aws $argv --region $region
        sleep 2
    end
end
