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

# DB2u subscription and operator creation 

runuser -l $SUDOUSER -c "cat > $CPDTEMPLATES/ibm-db2u-cs.yaml <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: ibm-db2uoperator-catalog
  namespace: openshift-marketplace
spec:
  displayName: IBM Db2U Catalog
  image: docker.io/ibmcom/ibm-db2uoperator-catalog:latest
  imagePullPolicy: Always
  publisher: IBM
  sourceType: grpc
  updateStrategy:
    registryPoll:
      interval: 45m
EOF"

## Creating CS and sub

runuser -l $SUDOUSER -c "oc create -f $CPDTEMPLATES/ibm-db2u-cs.yaml"
runuser -l $SUDOUSER -c "echo 'Sleeping for 1m' "
runuser -l $SUDOUSER -c "sleep 1m"

#runuser -l $SUDOUSER -c "oc create -f $CPDTEMPLATES/ibm-db2u-sub.yaml"
#runuser -l $SUDOUSER -c "echo 'Sleeping for 3m' "
#runuser -l $SUDOUSER -c "sleep 3m"

# Check ibm-cpd-ws-operator pod status

# podname="db2u-operator"
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

# echo "$(date) - ############### Script Complete #############"