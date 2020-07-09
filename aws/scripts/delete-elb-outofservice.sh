#!/bin/bash

#Install aws CLI
curl -O https://bootstrap.pypa.io/get-pip.py > /dev/null
python get-pip.py --user > /dev/null
export PATH="~/.local/bin:$PATH"
source ~/.bash_profile > /dev/null
pip install awscli --upgrade --user > /dev/null
pip install pssh > /dev/null

VPD_ID=`aws ec2 describe-vpcs --filters "Name=cidr,Values=$1" --query 'Vpcs[*].VpcId' --output text | xargs`
LOAD_BALANCER=`aws elb describe-load-balancers --output text | grep $VPD_ID | awk '{ print $5 }' | cut -d- -f1 | xargs`
INSTANCES=`aws elb describe-instance-health --load-balancer-name $LOAD_BALANCER --query 'InstanceStates[?State==\`OutOfService\`].InstanceId' --output text | xargs`
for inst in ${INSTANCES[@]}; do
aws elb deregister-instances-from-load-balancer --load-balancer-name $LOAD_BALANCER --instances $inst
done
