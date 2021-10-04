#!/bin/sh
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
export CPDTEMPLATES=/home/$SUDOUSER/.cpd/templates

# Set url
if [[ $CUSTOMDOMAIN == "true" || $CUSTOMDOMAIN == "True" ]];then
export SUBURL="${CLUSTERNAME}.${DOMAINNAME}"
else
export SUBURL="${DOMAINNAME}.${LOCATION}.aroapp.io"
fi


if [[ $STORAGEOPTION == "nfs" ]];then 
    export STORAGECLASS_VALUE="nfs"
elif [[ $STORAGEOPTION == "ocs" ]];then 
    export STORAGECLASS_VALUE="ocs-storagecluster-cephfs"
fi

#Login
var=1
while [ $var -ne 0 ]; do
echo "Attempting to login $OPENSHIFTUSER to https://api.${SUBURL}:6443"
oc login "https://api.${SUBURL}:6443" -u $OPENSHIFTUSER -p $OPENSHIFTPASSWORD --insecure-skip-tls-verify=true
var=$?
echo "exit code: $var"
done

runuser -l $SUDOUSER -c "cat > $CPDTEMPLATES/ibm-dmc-operator-catalogsource.yaml <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: ibm-dmc-operator-catalog
  namespace: openshift-marketplace
spec:
  displayName: \"IBM DMC Operator Catalog\" 
  publisher: IBM
  sourceType: grpc
  image: icr.io/cpopen/ibm-operator-catalog:latest
  updateStrategy:
    registryPoll:
      interval: 45m
EOF"


runuser -l $SUDOUSER -c "cat > $CPDTEMPLATES/ibm-dv-sub.yaml <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: ibm-dv-operator-subscription
  namespace: $OPERATORNAMESPACE
spec:
    channel: $CHANNEL
    installPlanApproval: Automatic
    name: ibm-dv-operator
    source: ibm-operator-catalog
    sourceNamespace: openshift-marketplace
EOF"

runuser -l $SUDOUSER -c "cat > $CPDTEMPLATES/ibm-dv-cr.yaml <<EOF
apiVersion: db2u.databases.ibm.com/v1
kind: DvService
metadata:
  name: dv-service-cr
  namespace: $CPDNAMESPACE
spec:
  license:
    accept: true
    license: Enterprise
  version: \"$VERSION\"
  storageClass: $STORAGECLASS_VALUE
  docker_registry_prefix: cp.icr.io/cp/cpd
EOF"

runuser -l $SUDOUSER -c "oc create -f $CPDTEMPLATES/ibm-dmc-operator-catalogsource.yaml"
runuser -l $SUDOUSER -c "echo 'Sleeping for 1m' "
runuser -l $SUDOUSER -c "sleep 1m"

runuser -l $SUDOUSER -c "oc create -f $CPDTEMPLATES/ibm-dv-sub.yaml"
runuser -l $SUDOUSER -c "echo 'Sleeping for 2m' "
runuser -l $SUDOUSER -c "sleep 2m"

# Check ibm-dv-operator pod status

podname="ibm-dv-operator"
name_space=$OPERATORNAMESPACE
status="unknown"
while [ "$status" != "Running" ]
do
  pod_name=$(oc get pods -n $name_space | grep $podname | awk '{print $1}' )
  ready_status=$(oc get pods -n $name_space $pod_name  --no-headers | awk '{print $2}')
  pod_status=$(oc get pods -n $name_space $pod_name --no-headers | awk '{print $3}')
  echo $pod_name State - $ready_status, podstatus - $pod_status
  if [ "$ready_status" == "1/1" ] && [ "$pod_status" == "Running" ]
  then 
  status="Running"
  else
  status="starting"
  sleep 10 
  fi
  echo "$pod_name is $status"
done

## Creating ibm-DV cr

runuser -l $SUDOUSER -c "oc project $CPDNAMESPACE; oc create -f $CPDTEMPLATES/ibm-dv-cr.yaml"


# Check CR Status

SERVICE="dvservice"
CRNAME="dv-service-cr"
SERVICE_STATUS="reconcileStatus"

STATUS=$(oc get $SERVICE $CRNAME -n $CPDNAMESPACE -o json | jq .status.$SERVICE_STATUS | xargs) 

while  [[ ! $STATUS =~ ^(Completed|Complete)$ ]]; do
    echo "$CRNAME is Installing!!!!"
    sleep 120
    STATUS=$(oc get $SERVICE $CRNAME -n $CPDNAMESPACE -o json | jq .status.$SERVICE_STATUS | xargs) 
    if [ "$STATUS" == "Failed" ]
    then
        echo "**********************************"
        echo "$CRNAME Installation Failed!!!!"
        echo "**********************************"
        exit 1
    fi
done 
echo "*************************************"
echo "$CRNAME Installation Finished!!!!"
echo "*************************************"

echo "$(date) - ############### Script Complete #############"