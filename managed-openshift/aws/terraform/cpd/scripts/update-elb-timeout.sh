#!/bin/bash

VPC_ID=$1
CLASSIC_LB_TIMEOUT=$2

#Install aws CLI
if ! [ -x "$(command -v pip)" ]; then
    curl -O https://bootstrap.pypa.io/get-pip.py > /dev/null
    python3 get-pip.py --user > /dev/null
    rm -f get-pip.py
fi
if ! [ -x "$(command -v aws)" ]; then
    pip install awscli --upgrade --user > /dev/null
fi

LOAD_BALANCER=`aws elb describe-load-balancers --output text | grep $VPC_ID | awk '{ print $5 }' | cut -d- -f1 | xargs`
for lbs in ${LOAD_BALANCER[@]}; do
aws elb modify-load-balancer-attributes --load-balancer-name $lbs --load-balancer-attributes "{\"ConnectionSettings\":{\"IdleTimeout\":$CLASSIC_LB_TIMEOUT}}"
done
