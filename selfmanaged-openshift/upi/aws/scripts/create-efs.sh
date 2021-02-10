#!/bin/bash

REGION=$1
VPC_CIDR=$2
VPC_ID=$3
PERFORMANCE_MODE=$4
PRIVATE_SUBNET_TAG_NAME=$5
PRIVATE_SUBNET_TAG_VALUE=$6
VAR=`date '+%F-%H-%M-%S'`

#Install aws CLI
curl -O https://bootstrap.pypa.io/get-pip.py > /dev/null
python3 get-pip.py --user > /dev/null
export PATH="~/.local/bin:$PATH"
source ~/.bash_profile > /dev/null
pip install awscli --upgrade --user > /dev/null
pip install pssh > /dev/null

EFS_SG_GROUPID=`aws ec2 create-security-group --group-name EFSSecutityGroup-${VAR} --description "EFS security group" --vpc-id $VPC_ID | awk -F':' '{print $2}' | awk '{print $1}' | xargs | tr -d '"'`
aws ec2 authorize-security-group-ingress --group-id $EFS_SG_GROUPID --protocol tcp --port 2049 --cidr $VPC_CIDR
aws ec2 authorize-security-group-ingress --group-id $EFS_SG_GROUPID --protocol tcp --port 22 --cidr $VPC_CIDR

FILESYSTEM_ID=`aws efs create-file-system --performance-mode $PERFORMANCE_MODE --tags "Key=Name,Value=cp4d-openshift-efs" --region $REGION --encrypted --query 'FileSystemId' | tr -d '"'`
sleep 30

aws efs put-lifecycle-configuration --file-system-id $FILESYSTEM_ID --lifecycle-policies "TransitionToIA=AFTER_30_DAYS" --region $REGION

SUBNET_IDS=`aws ec2 describe-subnets --filters Name=tag:$PRIVATE_SUBNET_TAG_NAME,Values=$PRIVATE_SUBNET_TAG_VALUE --query 'Subnets[*].SubnetId' --output text`
for subnets in ${SUBNET_IDS[@]}; do
    aws efs create-mount-target --file-system-id $FILESYSTEM_ID --subnet-id $subnets --security-group $EFS_SG_GROUPID
done
