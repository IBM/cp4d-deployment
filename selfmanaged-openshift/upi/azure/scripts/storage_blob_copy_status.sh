#! /bin/bash

cluster_sa=$1
account_key=$2

status="unknown"
while [ "$status" != "success" ]
do
  status=`az storage blob show --container-name vhd --name "rhcos.vhd" --account-name $cluster_sa --account-key $account_key -o tsv --query properties.copy.status`
  echo $status
done