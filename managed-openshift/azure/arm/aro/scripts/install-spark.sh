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


## AE Catalog Source and Subscription
echo "Deploying catalogsources and operator subscriptions for Analytics Engine"
runuser -l $SUDOUSER -c "sudo $CPDTEMPLATES/cpd-cli manage apply-olm --release=${VERSION} --components=analyticsengine"

if [ $? -ne 0 ]
then
    echo "**********************************"
    echo "Deploying catalog Sources & subscription failed for AE"
    echo "**********************************"
    exit 1
fi


## AE CR
echo "Applying CR for AE"
if [[ "$STORAGEOPTION" != "portworx" ]]
then
    runuser -l $SUDOUSER -c "sudo $CPDTEMPLATES/cpd-cli manage apply-cr --release=${VERSION} --components=analyticsengine  --license_acceptance=true --cpd_instance_ns=${CPDNAMESPACE} --file_storage_class=${STORAGECLASS_VALUE} --block_storage_class=${STORAGECLASS_RWO_VALUE}"
else
    runuser -l $SUDOUSER -c "sudo $CPDTEMPLATES/cpd-cli manage apply-cr --release=${VERSION} --components=analyticsengine  --license_acceptance=true --cpd_instance_ns=$CPDNAMESPACE --storage_vendor=portworx"
fi
if [ $? -ne 0 ]
then
    echo "**********************************"
    echo "Applying CR for CDE failed"
    echo "**********************************"
    exit 1
fi

# # WOS subscription and CR creation 

# runuser -l $SUDOUSER -c "cat > $CPDTEMPLATES/ibm-spark-sub.yaml <<EOF
# apiVersion: operators.coreos.com/v1alpha1
# kind: Subscription
# metadata:
#   labels:
#     app.kubernetes.io/instance: ibm-cpd-ae-operator-subscription
#     app.kubernetes.io/managed-by: ibm-cpd-ae-operator
#     app.kubernetes.io/name: ibm-cpd-ae-operator-subscription
#   name: ibm-cpd-ae-operator-subscription
#   namespace: $OPERATORNAMESPACE
# spec:
#     channel: $CHANNEL
#     installPlanApproval: Automatic
#     name: analyticsengine-operator
#     source: ibm-operator-catalog
#     sourceNamespace: openshift-marketplace
# EOF"

# runuser -l $SUDOUSER -c "cat > $CPDTEMPLATES/ibm-spark-cr.yaml <<EOF
# apiVersion: ae.cpd.ibm.com/v1
# kind: AnalyticsEngine
# metadata:
#   name: analyticsengine-cr
#   namespace: $CPDNAMESPACE
#   labels:
#     app.kubernetes.io/instance: ibm-analyticsengine-operator
#     app.kubernetes.io/managed-by: ibm-analyticsengine-operator
#     app.kubernetes.io/name: ibm-analyticsengine-operator
#     build: 4.0.0
# spec:
#   version: \"$VERSION\"
#   storageClass: $STORAGECLASS_VALUE
#   license:
#     accept: true
# EOF"

# ## Creating Subscription 

# runuser -l $SUDOUSER -c "oc create -f $CPDTEMPLATES/ibm-spark-sub.yaml"
# runuser -l $SUDOUSER -c "echo 'Sleeping for 2m' "
# runuser -l $SUDOUSER -c "sleep 2m"

# # Check ibm-cpd-ae-operator pod status

# podname="ibm-cpd-ae-operator"
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

# ## Creating ibm-spark cr

# runuser -l $SUDOUSER -c "oc project $CPDNAMESPACE; oc create -f $CPDTEMPLATES/ibm-spark-cr.yaml"

# # Check CR Status

# SERVICE="AnalyticsEngine"
# CRNAME="analyticsengine-cr"
# SERVICE_STATUS="analyticsengineStatus"

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