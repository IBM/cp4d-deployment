#!/bin/bash

OPERATOR_NAMESPACE="ibm-common-services"
# Set up image mirroring. Adding bootstrap artifactory so that the cluster can pull un-promoted catalog images (and zen images)

echo  '*************************************'
echo  'setting up imagecontentsource policy for bedrock'
echo  '*************************************'

#echo '*** executing **** oc create -f bedrock-edge-mirror.yaml'


# result=$(oc create -f bedrock-edge-mirror.yaml)
# echo $result
# sleep 5m

# Setup global_pull secret 
./setup-global-pull-secret-bedrock.sh ${ENTITLEMENT_USER} ${ENTITLEMENT_KEY}

ibmcloud login --apikey ${IBMCLOUD_APIKEY} -g ${IBMCLOUD_RG_NAME} -r ${REGION}

./roks-update.sh ${CLUSTER_NAME}


# # create bedrock catalog source 

echo '*** executing **** oc create -f bedrock-catalog-source.yaml'

result=$(oc create -f bedrock-catalog-source.yaml)
echo $result
sleep 1m


# Creating the ibm-common-services namespace: 

oc new-project ibm-common-services
oc project ibm-common-services

# Create bedrock operator group: 

echo '*** executing **** oc create -f bedrock-operator-group.yaml'


result=$(oc create -f bedrock-operator-group.yaml)
echo $result
sleep 1m


# Create bedrock subscription. This will deploy the bedrock: 

echo '*** executing **** oc create -f bedrock-sub.yaml'


result=$(oc create -f bedrock-sub.yaml)
echo $result
sleep 1m


#for reinstall, namespace-scope configmap will be deleted when ibm-common-service-operator first running. need to delete this pod to force recreate Configmap namespace-scope.
while true; do
# local cm_ns_status=$(oc get cm namespace-scope -n ibm-common-services)
cm_ns_status=$(oc get cm namespace-scope -n ibm-common-services)
if [[ -n $cm_ns_status ]]; then
  echo "Config Map namespace-scope exist."
  break
fi
sleep 30
oc get pods -n ibm-common-services -l name=ibm-common-service-operator | awk '{print $1}' | grep -Ev NAME | xargs oc delete pods -n $OPERATOR_NAMESPACE
sleep 30
done


echo "Waiting for Bedrock operator pods ready"
while true; do
pod_status=$(oc get pods -n ibm-common-services | grep -Ev "NAME|1/1|2/2|3/3|5/5|Comp")
if [[ -z $pod_status ]]; then
  echo "All pods are running now"
  break
fi
echo "Waiting for Bedrock operator pods ready"
oc get pods -n ibm-common-services
sleep 30
if [[ `oc get po -n ibm-common-services` =~ "Error" ]]; then
  oc delete `oc get po -o name | grep ibm-common-service-operator`
else
  echo "No pods with Error"
fi
done
  
sleep 60

# Checking if the bedrock operator pods are ready and running. 

# checking status of ibm-namespace-scope-operator

./check-subscription-status.sh ibm-common-service-operator ibm-common-services state
./pod-status-check.sh ibm-namespace-scope-operator ibm-common-services

# checking status of operand-deployment-lifecycle-manager

./pod-status-check.sh operand-deployment-lifecycle-manager ibm-common-services

# checking status of ibm-common-service-operator

./pod-status-check.sh ibm-common-service-operator ibm-common-services

# Creating zen catalog source 

echo '*** executing **** oc create -f zen-catalog-source.yaml'


result=$(oc create -f zen-catalog-source.yaml)
echo $result

sleep 1m


echo '*** executing **** oc create -f cpd-operator-sub.yaml'
result=$(oc create -f cpd-operator-sub.yaml)
echo $result
sleep 60



# Create zen namespace

oc new-project zen
oc project zen

# Create the zen operator 

echo '*** executing **** oc create -f zen-operandrequest.yaml'


result=$(oc create -f zen-operandrequest.yaml)
echo $result
sleep 30




# Create lite CR: 

echo '*** executing **** oc create -f zen-lite-cr.yaml'


result=$(oc create -f zen-lite-cr.yaml)
echo $result

# check if the zen operator pod is up and running.

./pod-status-check.sh ibm-zen-operator ibm-common-services
./pod-status-check.sh ibm-cert-manager-operator ibm-common-services

./pod-status-check.sh cert-manager-cainjector ibm-common-services
./pod-status-check.sh cert-manager-controller ibm-common-services
./pod-status-check.sh cert-manager-webhook ibm-common-services

# check the lite cr status

./check-cr-status.sh ibmcpd ibmcpd-cr zen controlPlaneStatus

wget https://github.com/IBM/cloud-pak-cli/releases/download/v3.7.1/cloudctl-linux-amd64.tar.gz
wget https://github.com/IBM/cloud-pak-cli/releases/download/v3.7.1/cloudctl-linux-amd64.tar.gz.sig
tar -xvf cloudctl-linux-amd64.tar.gz -C /usr/local/bin