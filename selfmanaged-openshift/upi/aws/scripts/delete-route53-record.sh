#!/bin/bash

#Install aws CLI
curl -O https://bootstrap.pypa.io/get-pip.py > /dev/null
python3 get-pip.py --user > /dev/null
export PATH="~/.local/bin:$PATH"
source ~/.bash_profile > /dev/null
pip install awscli --upgrade --user > /dev/null

set -e
VERBOSE=true

hosted_zone_id=$(aws cloudformation describe-stacks --stack-name nlb-stack --query Stacks[0].Outputs[?OutputKey==\'PrivateHostedZoneId\'].OutputValue --output text)

aws route53 list-resource-record-sets \
--hosted-zone-id $hosted_zone_id |
jq -c '.ResourceRecordSets[]' |
while read -r resourcerecordset; do
read -r name type <<<$(jq -r '.Name,.Type' <<<"$resourcerecordset")
if [ $type == "NS" -o $type == "SOA" ]; then
    $VERBOSE && echo "SKIPPING: $type $name"
else
    change_id=$(aws route53 change-resource-record-sets \
    --hosted-zone-id $hosted_zone_id \
    --change-batch '{"Changes":[{"Action":"DELETE","ResourceRecordSet":
        '"$resourcerecordset"'
        }]}' \
    --output text \
    --query 'ChangeInfo.Id')
    $VERBOSE && echo "DELETING: $type $name $change_id"
fi
done

change_id=$(aws route53 delete-hosted-zone \
--id $hosted_zone_id \
--output text \
--query 'ChangeInfo.Id')
