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
export CHANNEL=${12}
export VERSION=${13}

export OPERATORNAMESPACE=ibm-common-services
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

# UG CR creation 

runuser -l $SUDOUSER -c "sudo bash -c 'cat > $CPDTEMPLATES/ibm-ug-ocs-cr.yaml <<EOF
apiVersion: wkc.cpd.ibm.com/v1beta1
kind: UG
metadata:
  name: ug-cr
  namespace: $CPDNAMESPACE
spec:
  version: \"$VERSION\"
  size: \"small\"
  storageVendor: \"ocs\"
  license:
    accept: true
    license: \"Enterprise\"
  docker_registry_prefix: cp.icr.io/cp/cpd
EOF'"

runuser -l $SUDOUSER -c "sudo bash -c 'cat > $CPDTEMPLATES/ibm-ug-nfs-cr.yaml <<EOF
apiVersion: wkc.cpd.ibm.com/v1beta1
kind: UG
metadata:
  name: ug-cr
  namespace: $CPDNAMESPACE
spec:
  version: \"$VERSION\"
  size: \"small\"
  storageClass: \"nfs-client\"
  license:
    accept: true
    license: \"Enterprise\"
  docker_registry_prefix: cp.icr.io/cp/cpd
EOF'"


## Creating ibm-ug cr

if [[ $STORAGEOPTION == "nfs" ]];then 

    runuser -l $SUDOUSER -c "oc project $CPDNAMESPACE; oc create -f $CPDTEMPLATES/ibm-ug-nfs-cr.yaml"

elif [[ $STORAGEOPTION == "ocs" ]];then 

    runuser -l $SUDOUSER -c "oc project $CPDNAMESPACE; oc create -f $CPDTEMPLATES/ibm-ug-ocs-cr.yaml"
fi

# Check CR Status

SERVICE="UG"
CRNAME="ug-cr"
SERVICE_STATUS="ugStatus"

STATUS=$(oc get $SERVICE $CRNAME -n $CPDNAMESPACE -o json | jq .status.$SERVICE_STATUS | xargs) 

while  [[ ! $STATUS =~ ^(Completed|Complete)$ ]]; do
    echo "$CRNAME is Installing!!!!"
    sleep 60 
    STATUS=$(oc get $SERVICE $CRNAME -n $CPDNAMESPACE -o json | jq .status.$SERVICE_STATUS | xargs) 
    if [ "$STATUS" == "Failed" ]
    then
        echo "**********************************"
        echo "$CRNAME Installation Failed!!!!"
        echo "**********************************"
        exit
    fi
done 
echo "*************************************"
echo "$CRNAME Installation Finished!!!!"
echo "*************************************"

echo "$(date) - ############### Script Complete #############"