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

# Setup the storage class value

if [[ $STORAGEOPTION == "nfs" ]];then 
    export STORAGECLASS_VALUE="nfs"
    export STORAGECLASS_RWO_VALUE="nfs"
elif [[ $STORAGEOPTION == "ocs" ]];then 
    export STORAGECLASS_VALUE="ocs-storagecluster-cephfs"
    export STORAGECLASS_RWO_VALUE="ocs-storagecluster-ceph-rbd"
fi

#Login
var=1
while [ $var -ne 0 ]; do
echo "Attempting to login $OPENSHIFTUSER to https://api.${SUBURL}:6443"
oc login "https://api.${SUBURL}:6443" -u $OPENSHIFTUSER -p $OPENSHIFTPASSWORD --insecure-skip-tls-verify=true
var=$?
echo "exit code: $var"
done

# CPD CLI OCP Login
runuser -l $SUDOUSER -c "sudo $CPDTEMPLATES/cpd-cli manage login-to-ocp --server \"https://api.${SUBURL}:6443\" -u $OPENSHIFTUSER -p $OPENSHIFTPASSWORD"


## Watson Discovery Catalog Source and Subscription
echo "Deploying catalogsources and operator subscriptions for Watson Discovery"
runuser -l $SUDOUSER -c "sudo $CPDTEMPLATES/cpd-cli manage apply-olm --release=${VERSION} --components=watson_discovery"

if [ $? -ne 0 ]
then
    echo "**********************************"
    echo "Deploying catalog Sources & subscription failed for Watson Discovery"
    echo "**********************************"
    exit 1
fi


## Watson Discovery CR
echo "Applying CR for Watson Discovery"
if [[ "$STORAGEOPTION" != "portworx" ]]
then
    runuser -l $SUDOUSER -c "sudo $CPDTEMPLATES/cpd-cli manage apply-cr --release=${VERSION} --components=watson_discovery  --license_acceptance=true --cpd_instance_ns=${CPDNAMESPACE} --file_storage_class=${STORAGECLASS_VALUE} --block_storage_class=${STORAGECLASS_RWO_VALUE}"
else
    runuser -l $SUDOUSER -c "sudo $CPDTEMPLATES/cpd-cli manage apply-cr --release=${VERSION} --components=watson_discovery  --license_acceptance=true --cpd_instance_ns=$CPDNAMESPACE --storage_vendor=portworx"
fi
if [ $? -ne 0 ]
then
    echo "**********************************"
    echo "Applying CR for Watson Discovery failed"
    echo "**********************************"
    exit 1
fi



echo "$(date) - ############### Script Complete #############"