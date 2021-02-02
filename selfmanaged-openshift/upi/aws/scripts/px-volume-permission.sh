#!/bin/bash

#Install aws CLI
curl -O https://bootstrap.pypa.io/get-pip.py > /dev/null
python3 get-pip.py --user > /dev/null
export PATH="~/.local/bin:$PATH"
source ~/.bash_profile > /dev/null
pip install awscli --upgrade --user > /dev/null

INFRANAME=$(jq -r .infraID $HOME/ocpfourx/metadata.json)
WORKER_INSTANCE_ID=`aws ec2 describe-instances --filters Name=tag:Name,Values=$INFRANAME-worker --output text --query 'Reservations[*].Instances[*].InstanceId'`
DEVICE_NAME=`aws ec2 describe-instances --filters Name=tag:Name,Values=$INFRANAME-worker --output text --query 'Reservations[*].Instances[*].BlockDeviceMappings[*].DeviceName' | uniq`
for winstance in ${WORKER_INSTANCE_ID[@]}; do
for device in ${DEVICE_NAME[@]}; do
aws ec2 modify-instance-attribute --instance-id $winstance --block-device-mappings "[{\"DeviceName\": \"$device\",\"Ebs\":{\"DeleteOnTermination\":true}}]"
done
done
