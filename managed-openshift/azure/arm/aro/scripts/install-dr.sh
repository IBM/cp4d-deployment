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


if [[ $STORAGEOPTION == "nfs" ]];then 
    export STORAGECLASS_VALUE="nfs-client"
    export STORAGECLASS_RWO_VALUE="nfs-client"
elif [[ $STORAGEOPTION == "ocs" ]];then 
    export STORAGECLASS_VALUE="ocs-storagecluster-cephfs"
    export STORAGECLASS_RWO_VALUE="ocs-storagecluster-ceph-rbd"
fi


# CPD CLI OCP Login
runuser -l $SUDOUSER -c "sudo $CPDTEMPLATES/cpd-cli manage login-to-ocp --server \"https://api.${SUBURL}:6443\" -u $OPENSHIFTUSER -p $OPENSHIFTPASSWORD"


## DR Catalog Source and Subscription
echo "Deploying catalogsources and operator subscriptions for Data Refinery"
runuser -l $SUDOUSER -c "sudo $CPDTEMPLATES/cpd-cli manage apply-olm --release=${VERSION} --components=datarefinery"

if [ $? -ne 0 ]
then
    echo "**********************************"
    echo "Deploying catalog Sources & subscription failed for Data Refinery"
    echo "**********************************"
    exit 1
fi


## DR CR
echo "Applying CR for DR"
if [[ "$STORAGEOPTION" != "portworx" ]]
then
    runuser -l $SUDOUSER -c "sudo $CPDTEMPLATES/cpd-cli manage apply-cr --release=${VERSION} --components=datarefinery  --license_acceptance=true --cpd_instance_ns=${CPDNAMESPACE} --file_storage_class=${STORAGECLASS_VALUE} --block_storage_class=${STORAGECLASS_RWO_VALUE}"
else
    runuser -l $SUDOUSER -c "sudo $CPDTEMPLATES/cpd-cli manage apply-cr --release=${VERSION} --components=datarefinery  --license_acceptance=true --cpd_instance_ns=$CPDNAMESPACE --storage_vendor=portworx"
fi
if [ $? -ne 0 ]
then
    echo "**********************************"
    echo "Applying CR for Data Refinery failed"
    echo "**********************************"
    exit 1
fi

# # dr operator and CR creation 

# runuser -l $SUDOUSER -c "cat > $CPDTEMPLATES/ibm-dr-sub.yaml <<EOF
# apiVersion: operators.coreos.com/v1alpha1
# kind: Subscription
# metadata:
#   name: ibm-cpd-datarefinery-operator
#   namespace: $OPERATORNAMESPACE
# spec:
#   channel: $CHANNEL
#   name: ibm-cpd-datarefinery
#   installPlanApproval: Automatic
#   source: ibm-operator-catalog
#   sourceNamespace: openshift-marketplace
# EOF"

# runuser -l $SUDOUSER -c "cat > $CPDTEMPLATES/ibm-dr-cr.yaml <<EOF
# apiVersion: datarefinery.cpd.ibm.com/v1beta1
# kind: DataRefinery
# metadata:
#   name: datarefinery-sample
#   namespace: $CPDNAMESPACE
# spec:
#   docker_registry_prefix: cp.icr.io/cp/cpd
#   ignoreForMaintenance: false
#   license:
#     accept: true
#     license: Standard
#   scaleConfig: small
#   storageClass: $STORAGECLASS_VALUE
#   storageVendor: ocs
# EOF"

# # Create Catalogsource and subscription. 

# runuser -l $SUDOUSER -c "oc create -f $CPDTEMPLATES/ibm-dr-sub.yaml"
# runuser -l $SUDOUSER -c "echo 'Sleeping 2m for sub to be created'"
# runuser -l $SUDOUSER -c "sleep 2m"

# podname="ibm-cpd-datarefinery-operator"
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

# ## Creating ibm-dr cr

# runuser -l $SUDOUSER -c "oc project $CPDNAMESPACE; oc create -f $CPDTEMPLATES/ibm-dr-cr.yaml"

# # Check CR Status

# SERVICE="DataRefinery"
# CRNAME="datarefinery-sample"
# SERVICE_STATUS="datarefineryStatus"

# STATUS=$(oc get $SERVICE $CRNAME -n $CPDNAMESPACE -o json | jq .status.$SERVICE_STATUS | xargs) 

# while  [[ ! $STATUS =~ ^(Completed|Complete)$ ]]; do
#     echo "$CRNAME is Installing!!!!"
#     sleep 60 
#     STATUS=$(oc get $SERVICE $CRNAME -n $CPDNAMESPACE -o json | jq .status.$SERVICE_STATUS | xargs) 
#     if [ "$STATUS" == "Failed" ]
#     then
#         echo "**********************************"
#         echo "$CRNAME Installation Failed!!!!"
#         echo "**********************************"
#         exit 1
#     fi
# done 
# echo "*************************************"
# echo "$CRNAME Installation Finished!!!!"
# echo "*************************************"

echo "$(date) - ############### Script Complete #############"