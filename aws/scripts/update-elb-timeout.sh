#!/bin/bash

#Install aws CLI
curl -O https://bootstrap.pypa.io/get-pip.py > /dev/null
python get-pip.py --user > /dev/null
export PATH="~/.local/bin:$PATH"
source ~/.bash_profile > /dev/null
pip install awscli --upgrade --user > /dev/null
pip install pssh > /dev/null

CLUSTERID=$(oc get machineset -n openshift-machine-api -o jsonpath='{.items[0].metadata.labels.machine\.openshift\.io/cluster-api-cluster}')
KEY=`echo $CLUSTERID | awk -F'-' '{print $1}'`
VPD_ID=`aws ec2 describe-vpcs --filters "Name=tag:Name,Values=$KEY-cluster-vpc" --output text --query 'Vpcs[*].VpcId'`
LOAD_BALANCER=`aws elb describe-load-balancers --output text | grep $VPD_ID | awk '{ print $2 }' | cut -d- -f1 | xargs`
aws elb modify-load-balancer-attributes --load-balancer-name $LOAD_BALANCER --load-balancer-attributes "{\"ConnectionSettings\":{\"IdleTimeout\":600}}"