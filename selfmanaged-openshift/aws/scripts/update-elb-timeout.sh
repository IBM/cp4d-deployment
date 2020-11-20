#!/bin/bash

#Install aws CLI
curl -O https://bootstrap.pypa.io/get-pip.py > /dev/null
python get-pip.py --user > /dev/null
export PATH="~/.local/bin:$PATH"
source ~/.bash_profile > /dev/null
pip install awscli --upgrade --user > /dev/null
pip install pssh > /dev/null

LOAD_BALANCER=`aws elb describe-load-balancers --output text | grep $1 | awk '{ print $5 }' | cut -d- -f1 | xargs`
for lbs in ${LOAD_BALANCER[@]}; do
aws elb modify-load-balancer-attributes --load-balancer-name $lbs --load-balancer-attributes "{\"ConnectionSettings\":{\"IdleTimeout\":600}}"
done
