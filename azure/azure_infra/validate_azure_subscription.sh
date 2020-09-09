#!/bin/bash
#
# Validate your Azure subscription and check if enough roles are assigned to the principal name.
# To be executed after az login.

read -p "Enter the first part of your user principal name (e.g. john.doe): " principal_name

echo Hello $principal_name!
echo Your Azure Subscriptions are as follows...
az account list --all --output table

read -p "Is the default subscription correct? (y/n): " answer

if [[ "$answer" = "y" ]]; then
  export output_filename=Roles_table_$(date -u +"%Y%m%d-%H%M%S").txt
  az role assignment list --output table  >> $output_filename
  echo "These assigned roles can be found in file $output_filename: "
  grep $principal_name $output_filename

else
  echo "Please set the correct subscription with az account set -s <desired_subscription_id> and start this script again!"
fi

