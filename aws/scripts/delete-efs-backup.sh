#!/bin/bash

#Install aws CLI
curl -O https://bootstrap.pypa.io/get-pip.py > /dev/null
python get-pip.py --user > /dev/null
export PATH="~/.local/bin:$PATH"
source ~/.bash_profile > /dev/null
pip install awscli --upgrade --user > /dev/null

BACKUP_PLAN_ID=`aws backup list-backup-plans --query 'BackupPlansList[*].BackupPlanId' --output text`
SELECTION_ID=`aws backup list-backup-selections --backup-plan-id $BACKUP_PLAN_ID --query 'BackupSelectionsList[*].SelectionId' --output text`
aws backup delete-backup-selection --backup-plan-id $BACKUP_PLAN_ID --selection-id $SELECTION_ID
aws backup delete-backup-plan --backup-plan-id $BACKUP_PLAN_ID
