#!/bin/bash

#Install aws CLI
curl -O https://bootstrap.pypa.io/get-pip.py > /dev/null
python3 get-pip.py --user > /dev/null
export PATH="~/.local/bin:$PATH"
source ~/.bash_profile > /dev/null
pip install awscli --upgrade --user > /dev/null

CLUSTERID=$(oc get machineset -n openshift-machine-api -o jsonpath='{.items[0].metadata.labels.machine\.openshift\.io/cluster-api-cluster}')
FILESYSTEMID=`aws efs describe-file-systems --query FileSystems[?Name==\'$CLUSTERID-efs\'].FileSystemId --output text`
MOUNT_TARGETID=`aws efs describe-mount-targets --file-system-id $FILESYSTEMID --query 'MountTargets[*].MountTargetId' --output text`
for ids in ${MOUNT_TARGETID[@]}; do
aws efs delete-mount-target --mount-target-id $ids
done
sleep 30
aws efs delete-file-system --file-system-id $FILESYSTEMID
sleep 30
SG_GROUPID=`aws ec2 describe-security-groups --filter "Name=group-name,Values=$CLUSTERID-EFSSecutityGroup" --output text --query 'SecurityGroups[*].GroupId'`
aws ec2 delete-security-group --group-id $SG_GROUPID
