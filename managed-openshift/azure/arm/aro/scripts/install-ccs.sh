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

# Setup the storage class value

if [[ $STORAGEOPTION == "nfs" ]];then 
    export STORAGECLASS_VALUE="nfs"
    export STORAGECLASS_RWO_VALUE="nfs"
elif [[ $STORAGEOPTION == "ocs" ]];then 
    export STORAGECLASS_VALUE="ocs-storagecluster-cephfs"
    export STORAGECLASS_RWO_VALUE="ocs-storagecluster-ceph-rbd"
fi

# CPD CLI OCP Login
runuser -l $SUDOUSER -c "sudo $CPDTEMPLATES/cpd-cli manage login-to-ocp --server \"https://api.${SUBURL}:6443\" -u $OPENSHIFTUSER -p $OPENSHIFTPASSWORD"


## CCS Catalog Source and Subscription
echo "Deploying catalogsources and operator subscriptions for CCS"
runuser -l $SUDOUSER -c "sudo $CPDTEMPLATES/cpd-cli manage apply-olm --release=${VERSION} --components=ccs"

if [ $? -ne 0 ]
then
    echo "**********************************"
    echo "Deploying catalog Sources & subscription failed for CCS"
    echo "**********************************"
    exit 1
fi


# CCS CR
echo "Applying CR for CCS"
if [[ "$STORAGEOPTION" != "portworx" ]]
then
    runuser -l $SUDOUSER -c "sudo $CPDTEMPLATES/cpd-cli manage apply-cr --release=${VERSION} --components=ccs  --license_acceptance=true --cpd_instance_ns=${CPDNAMESPACE} --file_storage_class=${STORAGECLASS_VALUE} --block_storage_class=${STORAGECLASS_RWO_VALUE}"
else
    runuser -l $SUDOUSER -c "sudo $CPDTEMPLATES/cpd-cli manage apply-cr --release=${VERSION} --components=ccs  --license_acceptance=true --cpd_instance_ns=$CPDNAMESPACE --storage_vendor=portworx"
fi
if [ $? -ne 0 ]
then
    echo "**********************************"
    echo "Applying CR for CCS failed"
    echo "**********************************"
    exit 1
fi

# CCS subscription and CR creation 

# runuser -l $SUDOUSER -c "cat > $CPDTEMPLATES/ibm-ccs-sub.yaml <<EOF
# apiVersion: operators.coreos.com/v1alpha1
# kind: Subscription
# metadata:
#   annotations: {}
#   name: ibm-cpd-ccs-operator
#   namespace: $OPERATORNAMESPACE
# spec:
#   channel: $CHANNEL
#   config:
#     resources: {}
#   installPlanApproval: Automatic
#   name: ibm-cpd-ccs
#   source: ibm-operator-catalog
#   sourceNamespace: openshift-marketplace
# EOF"


runuser -l $SUDOUSER -c "sudo bash -c 'cat > $CPDTEMPLATES/ibm-ccs-cr.yaml <<EOF
apiVersion: ccs.cpd.ibm.com/v1beta1
kind: CCS
metadata:
  name: ccs-cr
  namespace: $CPDNAMESPACE
spec:
  size: \"small\"
  REPLACE_VENDOR_OR_CLASS: REPLACE_SC
  license:
    accept: true
    license: Enterprise
  docker_registry_prefix: \"cp.icr.io/cp/cpd\"
EOF'"


# ## Creating Subscription 

# runuser -l $SUDOUSER -c "oc create -f $CPDTEMPLATES/ibm-ccs-sub.yaml"
# runuser -l $SUDOUSER -c "echo 'Sleeping for 5m' "
# runuser -l $SUDOUSER -c "sleep 5m"

# # Check ibm-cpd-ws-operator pod status

# podname="ibm-cpd-ccs-operator"
# name_space=$OPERATORNAMESPACE
# status="unknown"
# while [ "$status" != "Running" ]
# do
#   pod_name=$(oc get pods -n $name_space | grep $podname | awk '{print $1}' )
#   ready_status=$(oc get pods -n $name_space $pod_name  --no-headers | awk '{print $2}')
#   pod_status=$(oc get pods -n $name_space $pod_name --no-headers | awk '{print $3}')
#   echo $pod_name State - $ready_status, podstatus - $pod_status
#   if [ "$ready_status" == "1/1" ] && [ "$pod_status" == "Running" ]
#   then 
#   status="Running"
#   else
#   status="starting"
#   sleep 10 
#   fi
#   echo "$pod_name is $status"
# done

## Creating ibm-ccs cr
if [[ $STORAGEOPTION == "nfs" ]];then 
runuser -l $SUDOUSER -c "sudo sed -i -e s#REPLACE_VENDOR_OR_CLASS#storageClass#g $CPDTEMPLATES/ibm-ccs-cr.yaml"
runuser -l $SUDOUSER -c "sudo sed -i -e s#REPLACE_SC#nfs#g $CPDTEMPLATES/ibm-ccs-cr.yaml"
elif [[ $STORAGEOPTION == "ocs" ]];then 
runuser -l $SUDOUSER -c "sudo sed -i -e s#REPLACE_VENDOR_OR_CLASS#storageVendor#g $CPDTEMPLATES/ibm-ccs-cr.yaml"
runuser -l $SUDOUSER -c "sudo sed -i -e s#REPLACE_SC#ocs#g $CPDTEMPLATES/ibm-ccs-cr.yaml"
fi


runuser -l $SUDOUSER -c "oc project $CPDNAMESPACE; oc create -f $CPDTEMPLATES/ibm-ccs-cr.yaml"

# Check CR Status

SERVICE="CCS"
CRNAME="ccs-cr"
SERVICE_STATUS="ccsStatus"

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