#!/bin/bash

VAR=`date '+%F-%H-%M-%S'`

#Install aws CLI
curl -O https://bootstrap.pypa.io/get-pip.py > /dev/null
python3 get-pip.py --user > /dev/null
export PATH="~/.local/bin:$PATH"
source ~/.bash_profile > /dev/null
pip install awscli --upgrade --user > /dev/null

CLUSTERID=$(oc get machineset -n openshift-machine-api -o jsonpath='{.items[0].metadata.labels.machine\.openshift\.io/cluster-api-cluster}')
#Providing permissions for all the instances in the autoscaling cluster
INST_PROFILE_NAME=`aws ec2 describe-instances --query 'Reservations[*].Instances[*].[IamInstanceProfile.Arn]' --output text | cut -d ':' -f 6 | cut -d '/' -f 2 | grep "$CLUSTERID-worker-profile" | uniq`
ROLE_NAME=`aws iam get-instance-profile --instance-profile-name $INST_PROFILE_NAME --query 'InstanceProfile.Roles[*].[RoleName]' --output text`
POLICY_ARN=`aws iam create-policy --policy-name portworx-policy-${VAR} --policy-document file://policy.json --query 'Policy.Arn' --output text`
aws iam attach-role-policy --role-name $ROLE_NAME --policy-arn $POLICY_ARN

#Add rule for 17001-17020 port
WORKER_TAG=`aws ec2 describe-security-groups --query 'SecurityGroups[*].Tags[*][Value]' --output text | grep "$CLUSTERID-worker-sg"`
MASTER_TAG=`aws ec2 describe-security-groups --query 'SecurityGroups[*].Tags[*][Value]' --output text | grep "$CLUSTERID-master-sg"`
WORKER_GROUP_ID=`aws ec2 describe-security-groups --filters Name=tag:Name,Values=$WORKER_TAG --query "SecurityGroups[*].{Name:GroupId}" --output text`
MASTER_GROUP_ID=`aws ec2 describe-security-groups --filters Name=tag:Name,Values=$MASTER_TAG --query "SecurityGroups[*].{Name:GroupId}" --output text`
aws ec2 authorize-security-group-ingress --group-id $WORKER_GROUP_ID --protocol tcp --port 17001-17020 --source-group $MASTER_GROUP_ID
aws ec2 authorize-security-group-ingress --group-id $WORKER_GROUP_ID --protocol tcp --port 17001-17020 --source-group $WORKER_GROUP_ID
aws ec2 authorize-security-group-ingress --group-id $WORKER_GROUP_ID --protocol tcp --port 111 --source-group $MASTER_GROUP_ID
aws ec2 authorize-security-group-ingress --group-id $WORKER_GROUP_ID --protocol tcp --port 111 --source-group $WORKER_GROUP_ID
aws ec2 authorize-security-group-ingress --group-id $WORKER_GROUP_ID --protocol tcp --port 2049 --source-group $MASTER_GROUP_ID
aws ec2 authorize-security-group-ingress --group-id $WORKER_GROUP_ID --protocol tcp --port 2049 --source-group $WORKER_GROUP_ID
aws ec2 authorize-security-group-ingress --group-id $WORKER_GROUP_ID --protocol tcp --port 20048 --source-group $MASTER_GROUP_ID
aws ec2 authorize-security-group-ingress --group-id $WORKER_GROUP_ID --protocol tcp --port 20048 --source-group $WORKER_GROUP_ID
