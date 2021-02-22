#!/bin/bash

#Install aws CLI
curl -O https://bootstrap.pypa.io/get-pip.py > /dev/null
python3 get-pip.py --user > /dev/null
export PATH="~/.local/bin:$PATH"
source ~/.bash_profile > /dev/null
pip install awscli --upgrade --user > /dev/null

VPC_PEERING_ID=`aws ec2 describe-vpc-peering-connections --filters "Name=tag:Name,Values=vpc-peering-cp4d-cluster" "Name=status-code,Values=active" --query 'VpcPeeringConnections[*].VpcPeeringConnectionId' --output text`
aws ec2 delete-vpc-peering-connection --vpc-peering-connection-id $VPC_PEERING_ID
