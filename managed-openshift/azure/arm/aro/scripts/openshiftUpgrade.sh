#!/bin/sh
set -x

export LOCATION=$1
export DOMAINNAME=$2
export SUDOUSER=$3
export WORKERNODECOUNT=$4
export CPDNAMESPACE=$5
export STORAGEOPTION=$6
export APIKEY=$7
export OPENSHIFTUSER=$8
export OPENSHIFTPASSWORD=$9
export CUSTOMDOMAIN=$10
export CLUSTERNAME=${11}

export INSTALLERHOME=/home/$SUDOUSER/.ibm
export OCPTEMPLATES=/home/$SUDOUSER/.openshift/templates
export CPDTEMPLATES=/mnt/.cpd/templates

# Set url
if [[ $CUSTOMDOMAIN == "true" || $CUSTOMDOMAIN == "True" ]];then
export SUBURL="${CLUSTERNAME}.${DOMAINNAME}"
else
export SUBURL="${DOMAINNAME}.${LOCATION}.aroapp.io"
fi

#Login
var=1
while [ $var -ne 0 ]; do
echo "Attempting to login $OPENSHIFTUSER to https://api.${SUBURL}:6443"
oc login "https://api.${SUBURL}:6443" -u $OPENSHIFTUSER -p $OPENSHIFTPASSWORD --insecure-skip-tls-verify=true
var=$?
echo "exit code: $var"
done

runuser -l $SUDOUSER -c "oc login https://api.${SUBURL}:6443 -u $OPENSHIFTUSER -p $OPENSHIFTPASSWORD --insecure-skip-tls-verify=true"

# install jq
runuser -l $SUDOUSER -c "sudo yum install jq -y"

# Set the upgrade channel to stable-4.10
runuser -l $SUDOUSER -c "oc adm upgrade channel stable-4.10"

runuser -l $SUDOUSER -c "sleep 2m"

# Check current installed ARO Openshift version
VERSION=$(oc get clusterversion | awk -v col=VERSION 'NR==1{for(i=1;i<=NF;i++){if($i==col){c=i;break}} print $c} NR>1{print $c}' | tail -n1)

echo "Check available ARO version 4.10.23 for Upgrade"
if [ $VERSION != "4.10.23" ] && [ $(oc adm upgrade | grep -c 4.10.23) == 1 ];then
  # Cluster update to the latest version
  runuser -l $SUDOUSER -c "oc adm upgrade --to=4.10.23"
  echo "ARO Version Upgrade 4.10.23 has been started.."

  # Check the ARO version and wait for upgrade to complete
  while [[ $VERSION != "4.10.23" ]]; do
    STATUS=$(oc get clusterversion | awk -v col=STATUS 'NR==1{for(i=1;i<=NF;i++){if($i==col){c=i;break}} print $c} NR>1{print $c}' | tail -n1)
    echo "ARO Upgrade STATUS: $STATUS"
    sleep 2m
    VERSION=$(oc get clusterversion | awk -v col=VERSION 'NR==1{for(i=1;i<=NF;i++){if($i==col){c=i;break}} print $c} NR>1{print $c}' | tail -n1)
  done

  echo "##### ARO Version is successfully upgraded to 4.10.23 #####"
fi


echo "$(date) - ############### Script Complete #############"