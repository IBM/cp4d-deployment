#!/bin/bash

#Install aws CLI
curl -O https://bootstrap.pypa.io/get-pip.py > /dev/null
python3 get-pip.py --user > /dev/null
export PATH="~/.local/bin:$PATH"
source ~/.bash_profile > /dev/null
pip install awscli --upgrade --user > /dev/null

INST_PROFILE_NAME=`aws ec2 describe-instances --query 'Reservations[*].Instances[*].[IamInstanceProfile.Arn]' --output text | cut -d ':' -f 6 | cut -d '/' -f 2 | grep sg-role-stack-WorkerInstanceProfile* | uniq`
ROLE_NAME=`aws iam get-instance-profile --instance-profile-name $INST_PROFILE_NAME --query 'InstanceProfile.Roles[*].[RoleName]' --output text`
POLICY_ARN=`aws iam list-attached-role-policies --role-name $ROLE_NAME  | grep PolicyArn | xargs | awk -F' ' '{print $2}'`
aws iam detach-role-policy --role-name $ROLE_NAME --policy-arn $POLICY_ARN
aws iam delete-policy --policy-arn $POLICY_ARN
