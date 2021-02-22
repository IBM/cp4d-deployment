#!/bin/bash

curl -O https://bootstrap.pypa.io/get-pip.py > /dev/null
python3 get-pip.py --user > /dev/null
export PATH="~/.local/bin:$PATH"
source ~/.bash_profile > /dev/null
pip install awscli --upgrade --user > /dev/null
pip install pssh > /dev/null

for ((i=0; i<7; i++))
do
aws cloudformation delete-stack --stack-name workernode-stack-$i
done
