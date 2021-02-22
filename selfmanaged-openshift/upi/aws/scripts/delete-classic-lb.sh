#!/bin/bash

#Install aws CLI
curl -O https://bootstrap.pypa.io/get-pip.py > /dev/null
python3 get-pip.py --user > /dev/null
export PATH="~/.local/bin:$PATH"
source ~/.bash_profile > /dev/null
pip install awscli --upgrade --user > /dev/null
pip install pssh > /dev/null

LOAD_BALANCER=`aws elb describe-load-balancers --query 'LoadBalancerDescriptions[*].LoadBalancerName' --output text | xargs`
for lbs in ${LOAD_BALANCER[@]}; do
aws elb delete-load-balancer --load-balancer-name $lbs
done
sleep 90
SG_GROUPID=`aws ec2 describe-security-groups --filter "Name=group-name,Values=k8s-elb-*" --output text --query 'SecurityGroups[*].GroupId'`
for sg in ${SG_GROUPID[@]}; do
aws ec2 delete-security-group --group-id $sg
done
