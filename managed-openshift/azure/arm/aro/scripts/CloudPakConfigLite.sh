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
export CUSTOMDOMAIN=${10}
export CLUSTERNAME=${11}
export CHANNEL=${12}
export VERSION=${13}

export OPERATORNAMESPACE=ibm-common-services
export INSTALLERHOME=/home/$SUDOUSER/.ibm
export OCPTEMPLATES=/home/$SUDOUSER/.openshift/templates
export CPDTEMPLATES=/mnt/.cpd/templates

# runuser -l $SUDOUSER -c "mkdir -p $INSTALLERHOME"
# runuser -l $SUDOUSER -c "mkdir -p $OCPTEMPLATES"
# runuser -l $SUDOUSER -c "sudo mkdir -p $CPDTEMPLATES"

#CPD Config

# runuser -l $SUDOUSER -c "wget https://github.com/IBM/cloud-pak-cli/releases/download/v3.8.0/cloudctl-linux-amd64.tar.gz -O $CPDTEMPLATES/cloudctl-linux-amd64.tar.gz"
# runuser -l $SUDOUSER -c "https://github.com/IBM/cloud-pak-cli/releases/download/v3.8.0/cloudctl-linux-amd64.tar.gz.sig -O $CPDTEMPLATES/cloudctl-linux-amd64.tar.gz.sig"
# runuser -l $SUDOUSER -c "cd $CPDTEMPLATES && sudo tar -xvf cloudctl-linux-amd64.tar.gz -C /usr/bin"
# runuser -l $SUDOUSER -c "chmod +x /usr/bin/cloudctl-linux-amd64"
# runuser -l $SUDOUSER -c "sudo mv /usr/bin/cloudctl-linux-amd64 /usr/bin/cloudctl"

### Install Prereqs:  CPD CLI, JQ, and Podman
## Download & Install CPD CLI
# runuser -l $SUDOUSER -c "sudo wget https://github.com/IBM/cpd-cli/releases/download/v11.0.0/cpd-cli-linux-EE-11.0.0.tgz -O $CPDTEMPLATES/cpd-cli-linux-EE-11.0.0.tgz"
# runuser -l $SUDOUSER -c "cd $CPDTEMPLATES && sudo tar -xvf cpd-cli-linux-EE-11.0.0.tgz"
# # Move cpd-cli, plugins and license in the CPDTEMPLATES folder
# runuser -l $SUDOUSER -c "sudo mv $CPDTEMPLATES/cpd-cli-linux-EE-11.0.0-20/* $CPDTEMPLATES"
# runuser -l $SUDOUSER -c "sudo rm -rf $CPDTEMPLATES/cpd-cli-linux-EE-11.0.0*"

# # Service Account Token for CPD installation
# runuser -l $SUDOUSER -c "oc new-project $CPDNAMESPACE"

# # Service Account Token for CPD installation
# runuser -l $SUDOUSER -c "oc new-project $OPERATORNAMESPACE"

# ## Installing jq
# runuser -l $SUDOUSER -c "sudo wget https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64 -O $CPDTEMPLATES/jq"
# runuser -l $SUDOUSER -c "sudo mv $CPDTEMPLATES/jq /usr/bin"
# runuser -l $SUDOUSER -c "sudo chmod +x /usr/bin/jq"

# ## Installing Podman
# runuser -l $SUDOUSER -c "sudo yum install podman -y"

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

# CPD CLI OCP Login
runuser -l $SUDOUSER -c "sudo $CPDTEMPLATES/cpd-cli manage login-to-ocp --server \"https://api.${SUBURL}:6443\" -u $OPENSHIFTUSER -p $OPENSHIFTPASSWORD"

# Update global pull secret 

# export ENTITLEMENT_USER=cp
# export ENTITLEMENT_KEY=$APIKEY
# pull_secret=$(echo -n "$ENTITLEMENT_USER:$ENTITLEMENT_KEY" | base64 -w0)
# oc get secret/pull-secret -n openshift-config -o jsonpath='{.data.\.dockerconfigjson}' | base64 -d > $OCPTEMPLATES/dockerconfig.json
# sed -i -e 's|:{|:{"cp.icr.io":{"auth":"'$pull_secret'"\},|' $OCPTEMPLATES/dockerconfig.json
# oc set data secret/pull-secret -n openshift-config --from-file=.dockerconfigjson=$OCPTEMPLATES/dockerconfig.json

# # Check nodestatus if they are ready.

# while true; do
#     node_status=$(oc get nodes | grep -E "SchedulingDisabled|NotReady")
#     if [[ -z $node_status ]]; then
#         echo -e "\n******All nodes are running now.******"
#         break
#     fi
#         echo -e "\n******Waiting for nodes to get ready.******"
#         oc get nodes --no-headers | awk '{print $1 " " $2}'
#         echo -e "\n******sleeping for 60Secs******"
#         sleep 60
#     done

# Setup the storage class value

if [[ $STORAGEOPTION == "nfs" ]];then 
    export STORAGECLASS_VALUE="nfs"
    export STORAGECLASS_RWO_VALUE="nfs"
elif [[ $STORAGEOPTION == "ocs" ]];then 
    export STORAGECLASS_VALUE="ocs-storagecluster-cephfs"
    export STORAGECLASS_RWO_VALUE="ocs-storagecluster-ceph-rbd"
fi

echo "Deploy all catalog sources and operator subscriptions for cpfs,cpd_platform"
runuser -l $SUDOUSER -c "sudo $CPDTEMPLATES/cpd-cli manage apply-olm --release=${VERSION} --components=cpfs,cpd_platform"
if [ $? -ne 0 ]
then
    echo "**********************************"
    echo "Deploying catalog Sources & subscription failed for cpfs,cpd_platform"
    echo "**********************************"
    exit 1
fi

echo "Applying CR for cpfs,cpd_platform"
if [[ "$STORAGEOPTION" != "portworx" ]]
then
    runuser -l $SUDOUSER -c "sudo $CPDTEMPLATES/cpd-cli manage apply-cr --release=${VERSION} --components=cpfs,cpd_platform  --license_acceptance=true --cpd_instance_ns=${CPDNAMESPACE} --file_storage_class=${STORAGECLASS_VALUE} --block_storage_class=${STORAGECLASS_RWO_VALUE}"
else
    runuser -l $SUDOUSER -c "sudo $CPDTEMPLATES/cpd-cli manage apply-cr --release=${VERSION} --components=cpfs,cpd_platform  --license_acceptance=true --cpd_instance_ns=$CPDNAMESPACE --storage_vendor=portworx"
fi
if [ $? -ne 0 ]
then
    echo "**********************************"
    echo "Applying CR for cpfs,cpd_platform failed"
    echo "**********************************"
    exit 1
fi

echo "Enable CSV injector"
runuser -l $SUDOUSER -c "oc patch namespacescope common-service --type='json' -p='[{\"op\":\"replace\", \"path\": \"/spec/csvInjector/enable\", \"value\":true}]' -n ${OPERATORNAMESPACE}"

# CPD Bedrock and Platform operator install: 

# runuser -l $SUDOUSER -c "cat > $CPDTEMPLATES/ibm-operator-catalogsource.yaml <<EOF
# apiVersion: operators.coreos.com/v1alpha1
# kind: CatalogSource
# metadata:
#   name: ibm-operator-catalog
#   namespace: openshift-marketplace
# spec:
#   displayName: \"IBM Operator Catalog\" 
#   publisher: IBM
#   sourceType: grpc
#   image: icr.io/cpopen/ibm-operator-catalog:latest
#   updateStrategy:
#     registryPoll:
#       interval: 45m
# EOF"

# DB2u subscription and operator creation 

# runuser -l $SUDOUSER -c "cat > $CPDTEMPLATES/ibm-db2u-cs.yaml <<EOF
# apiVersion: operators.coreos.com/v1alpha1
# kind: CatalogSource
# metadata:
#   name: ibm-db2uoperator-catalog
#   namespace: openshift-marketplace
# spec:
#   displayName: IBM Db2U Catalog
#   image: docker.io/ibmcom/ibm-db2uoperator-catalog:latest
#   imagePullPolicy: Always
#   publisher: IBM
#   sourceType: grpc
#   updateStrategy:
#     registryPoll:
#       interval: 45m
# EOF"

# runuser -l $SUDOUSER -c "cat > $CPDTEMPLATES/ibm-operator-og.yaml <<EOF
# apiVersion: operators.coreos.com/v1alpha2
# kind: OperatorGroup
# metadata:
#   name: operatorgroup
#   namespace: ibm-common-services
# spec:
#   targetNamespaces:
#   - ibm-common-services
# EOF"

# runuser -l $SUDOUSER -c "cat > $CPDTEMPLATES/cpd-platform-operator-sub.yaml <<EOF
# apiVersion: operators.coreos.com/v1alpha1
# kind: Subscription
# metadata:
#   name: cpd-operator
#   namespace: ibm-common-services    # The project that contains the Cloud Pak for Data operator
# spec:
#   channel: $CHANNEL
#   installPlanApproval: Automatic
#   name: cpd-platform-operator
#   source: ibm-operator-catalog
#   sourceNamespace: openshift-marketplace
# EOF"

# runuser -l $SUDOUSER -c "cat > $CPDTEMPLATES/cpd-platform-operator-operandrequest.yaml <<EOF
# apiVersion: operator.ibm.com/v1alpha1
# kind: OperandRequest
# metadata:
#   name: empty-request
#   namespace: $CPDNAMESPACE        # Replace with the project where you will install Cloud Pak for Data
# spec:
#   requests: []
# EOF"


# # Run catalog source 

# runuser -l $SUDOUSER -c "oc create -f $CPDTEMPLATES/ibm-operator-catalogsource.yaml"
# runuser -l $SUDOUSER -c "echo 'Sleeping for 1m' "
# runuser -l $SUDOUSER -c "sleep 1m"

# # Check ibm-operator-catalog pod status

# podname="ibm-operator-catalog"
# name_space="openshift-marketplace"
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


# runuser -l $SUDOUSER -c "oc create -f $CPDTEMPLATES/ibm-operator-og.yaml"
# runuser -l $SUDOUSER -c "echo 'Sleeping for 1m' "
# runuser -l $SUDOUSER -c "sleep 1m"

# ## Creating db2u CS 

# runuser -l $SUDOUSER -c "oc create -f $CPDTEMPLATES/ibm-db2u-cs.yaml"
# runuser -l $SUDOUSER -c "echo 'Sleeping for 1m' "
# runuser -l $SUDOUSER -c "sleep 1m"


# # Creating CPD Platform operator subscription: 

# runuser -l $SUDOUSER -c "oc create -f $CPDTEMPLATES/cpd-platform-operator-sub.yaml"
# runuser -l $SUDOUSER -c "echo 'Sleeping for 2m' "
# runuser -l $SUDOUSER -c "sleep 2m"

# # Check cpd-platform-operator-manager pod status

# podname="cpd-platform-operator-manager"
# name_space=$OPERATORNAMESPACE
# status="unknown"
# while [ "$status" != "Running" ]
# do
#   pod_name=$(oc get pods -n $name_space | grep $podname | awk '{print $1}')
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

# runuser -l $SUDOUSER -c "oc create -f $CPDTEMPLATES/cpd-platform-operator-operandrequest.yaml"
# runuser -l $SUDOUSER -c "echo 'Sleeping for 2m' "
# runuser -l $SUDOUSER -c "sleep 2m"

# Install Lite-cr 

# Setup the storage class value

# if [[ $STORAGEOPTION == "nfs" ]];then 
#     export STORAGECLASS_VALUE="nfs"
#     export STORAGECLASS_RWO_VALUE="nfs"
# elif [[ $STORAGEOPTION == "ocs" ]];then 
#     export STORAGECLASS_VALUE="ocs-storagecluster-cephfs"
#     export STORAGECLASS_RWO_VALUE="ocs-storagecluster-ceph-rbd"
# fi

# runuser -l $SUDOUSER -c "cat > $CPDTEMPLATES/ibmcpd-cr.yaml <<EOF
# apiVersion: cpd.ibm.com/v1
# kind: Ibmcpd
# metadata:
#   name: ibmcpd-cr                                         # This is the recommended name, but you can change it
#   namespace: $CPDNAMESPACE                            # Replace with the project where you will install Cloud Pak for Data
# spec:
#   license:
#     accept: true
#     license: Enterprise                                   # Specify the Cloud Pak for Data license you purchased
#   storageClass: \"$STORAGECLASS_VALUE\"                    # Replace with the name of a RWX storage class
#   zenCoreMetadbStorageClass: \"$STORAGECLASS_RWO_VALUE\"       # (Recommended) Replace with the name of a RWO storage class
#   version: \"$VERSION\"
# EOF"

# runuser -l $SUDOUSER -c "oc project $CPDNAMESPACE; oc create -f $CPDTEMPLATES/ibmcpd-cr.yaml"
# sleep 240 

# # Check operand-deployment-lifecycle-manager pod status

# podname="operand-deployment-lifecycle-manager"
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


# # Check CR Status

# SERVICE="ibmcpd"
# CRNAME="ibmcpd-cr"
# SERVICE_STATUS="controlPlaneStatus"

# STATUS=$(oc get $SERVICE $CRNAME -n $CPDNAMESPACE -o json | jq .status.$SERVICE_STATUS | xargs) 

# while  [[ ! $STATUS =~ ^(Completed|Complete)$ ]]; do
#     echo "$CRNAME is Installing!!!!"
#     sleep 120 
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

# echo "$(date) - ############### Script Complete #############"
