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

#Login
var=1
while [ $var -ne 0 ]; do
echo "Attempting to login $OPENSHIFTUSER to https://api.${SUBURL}:6443"
oc login "https://api.${SUBURL}:6443" -u $OPENSHIFTUSER -p $OPENSHIFTPASSWORD --insecure-skip-tls-verify=true
var=$?
echo "exit code: $var"
done

# WOS subscription and CR creation 

runuser -l $SUDOUSER -c "cat > $CPDTEMPLATES/ibm-wml-sub.yaml <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  labels:
    app.kubernetes.io/instance: ibm-cpd-wml-operator
    app.kubernetes.io/managed-by: ibm-cpd-wml-operator
    app.kubernetes.io/name: ibm-cpd-wml-operator
  name: ibm-cpd-wml-operator
  namespace: $OPERATORNAMESPACE
spec:
    channel: $CHANNEL
    installPlanApproval: Automatic
    name: ibm-cpd-wml-operator
    source: ibm-operator-catalog
    sourceNamespace: openshift-marketplace
EOF"

runuser -l $SUDOUSER -c "cat > $CPDTEMPLATES/ibm-wml-ocs-cr.yaml <<EOF
apiVersion: wml.cpd.ibm.com/v1beta1
kind: WmlBase
metadata:
  name: wml-cr
  namespace: $CPDNAMESPACE
  labels:
    app.kubernetes.io/instance: wml
    app.kubernetes.io/managed-by: ibm-cpd-wml-operator
    app.kubernetes.io/name: ibm-cpd-wml-operator
spec:
  scaleConfig: small
  is_35_upgrade: false
  ignoreForMaintenance: false
  docker_registry_prefix: \"cp.icr.io/cp/cpd\"
  storageClass: ocs-storagecluster-cephfs
  storageVendor: ocs
  version: \"$VERSION\"
  license:
    accept: true
    license: \"Enterprise\"
EOF"

runuser -l $SUDOUSER -c "cat > $CPDTEMPLATES/ibm-wml-nfs-cr.yaml <<EOF
apiVersion: wml.cpd.ibm.com/v1beta1
kind: WmlBase
metadata:
  name: wml-cr
  namespace: $CPDNAMESPACE
  labels:
    app.kubernetes.io/instance: wml
    app.kubernetes.io/managed-by: ibm-cpd-wml-operator
    app.kubernetes.io/name: ibm-cpd-wml-operator
spec:
  scaleConfig: small
  is_35_upgrade: false
  ignoreForMaintenance: false
  docker_registry_prefix: \"cp.icr.io/cp/cpd\"
  storageClass: nfs
  version: \"$VERSION\"
  license:
    accept: true
    license: \"Enterprise\"
EOF"

## Creating Subscription 

runuser -l $SUDOUSER -c "oc create -f $CPDTEMPLATES/ibm-wml-sub.yaml"
runuser -l $SUDOUSER -c "echo 'Sleeping for 5m' "
runuser -l $SUDOUSER -c "sleep 5m"

# Check ibm-cpd-wml-operator pod status

podname="ibm-cpd-wml-operator"
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

## Creating ibm-wml cr

if [[ $STORAGEOPTION == "nfs" ]];then 
    runuser -l $SUDOUSER -c "oc project $CPDNAMESPACE; oc create -f $CPDTEMPLATES/ibm-wml-nfs-cr.yaml"
elif [[ $STORAGEOPTION == "ocs" ]];then
    runuser -l $SUDOUSER -c "oc project $CPDNAMESPACE; oc create -f $CPDTEMPLATES/ibm-wml-ocs-cr.yaml"
fi


# Check CR Status

SERVICE="WmlBase"
CRNAME="wml-cr"
SERVICE_STATUS="wmlStatus"

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
        exit
    fi
done 
echo "*************************************"
echo "$CRNAME Installation Finished!!!!"
echo "*************************************"

echo "$(date) - ############### Script Complete #############"