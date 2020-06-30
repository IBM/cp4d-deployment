#Install aws CLI
curl -O https://bootstrap.pypa.io/get-pip.py > /dev/null
python get-pip.py --user > /dev/null
export PATH="~/.local/bin:$PATH"
source ~/.bash_profile > /dev/null
pip install awscli --upgrade --user > /dev/null

IAM_ACCOUNT_ID=$1
CLUSTERID=$(oc get machineset -n openshift-machine-api -o jsonpath='{.items[0].metadata.labels.machine\.openshift\.io/cluster-api-cluster}')
BACKUP_PLAN_ID=`aws backup create-backup-plan \
--backup-plan "{\"BackupPlanName\":\"EFS-Backup-Plan\",\"Rules\":[{\"RuleName\":\"DailyBackups\",\"ScheduleExpression\":\"cron(0 5 ? * * *)\",\"StartWindowMinutes\":480,\"TargetBackupVaultName\":\"Default\",\"Lifecycle\":{\"DeleteAfterDays\":35}}]}" \
| grep BackupPlanId | awk -F':' '{print $2}' | xargs | tr -d '"'`
aws backup create-backup-selection --backup-plan-id $BACKUP_PLAN_ID --backup-selection "{\"SelectionName\": \"EFS-resource\",\"IamRoleArn\": \"arn:aws:iam::$IAM_ACCOUNT_ID:role\/service-role\/AWSBackupDefaultServiceRole\",\"ListOfTags\": [{\"ConditionType\": \"STRINGEQUALS\",\"ConditionKey\": \"Name\",\"ConditionValue\": \"$CLUSTERID-efs\"}]}"
