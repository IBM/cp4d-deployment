#!/bin/bash


# Set up image mirroring. Adding bootstrap artifactory so that the cluster can pull un-promoted catalog images (and zen images)

echo  '*************************************'
echo  'setting up imagecontentsource policy for bedrock'
echo  '*************************************'

echo '*** executing **** oc create -f bedrock-edge-mirror.yaml'


result=$(oc create -f bedrock-edge-mirror.yaml)
echo $result
sleep 5m

# Setup global_pull secret 
./setup-global-pull-secret-bedrock.sh ${ARTIFACTORY_USERNAME} ${ARTIFACTORY_APIKEY}

ibmcloud login --apikey ${IBMCLOUD_APIKEY} -g ${IBMCLOUD_RG_NAME} -r ${REGION}

./roks-update.sh ${CLUSTER_NAME}

# create bedrock catalog source 

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

# Checking if the bedrock operator pods are ready and running. 

# checking status of ibm-namespace-scope-operator

chmod +x pod-status-check.sh
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

# (Important) Edit operand registry *** 

oc get operandregistry -n ibm-common-services -o yaml > operandregistry.yaml
cp operandregistry.yaml operandregistry.yaml_original
# sed -i '/\\s\\s\\s\\s\\s\\spackageName: ibm-zen-operator/{n;n;s/.*/      sourceName: ibm-zen-operator-catalog/}' operandregistry.yaml 
# sed -zEi 's/    - channel: v3([^\\n]*\\n[^\\n]*name: ibm-zen-operator)/    - channel: stable-v1\\1/' operandregistry.yaml

sed -i '/\s\s\s\s\s\spackageName: ibm-zen-operator/{n;n;s/.*/      sourceName: ibm-zen-operator-catalog/}' operandregistry.yaml 
sed -zEi 's/    - channel: v3([^\n]*\n[^\n]*name: ibm-zen-operator)/    - channel: stable-v1\1/' operandregistry.yaml


echo '*** executing **** oc create -f operandregistry.yaml'
result=$(oc apply -f operandregistry.yaml)
echo $result

# Create zen namespace

oc new-project zen
oc project zen

# Create the zen operator 

echo '*** executing **** oc create -f zen-operandrequest.yaml'


result=$(oc create -f zen-operandrequest.yaml)
echo $result
sleep 5m


# check if the zen operator pod is up and running.

./pod-status-check.sh ibm-zen-operator ibm-common-services
./pod-status-check.sh ibm-cert-manager-operator ibm-common-services

# Create lite CR: 

echo '*** executing **** oc create -f zen-lite-cr.yaml'


result=$(oc create -f zen-lite-cr.yaml)
echo $result

# check the lite cr status

wget https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64 -O jq
mv jq /usr/local/bin
chmod +x /usr/local/bin/jq

chmod +x check-cr-status.sh
./check-cr-status.sh zenservice lite-cr zen zenStatus

wget https://github.com/IBM/cloud-pak-cli/releases/download/v3.7.1/cloudctl-linux-amd64.tar.gz
wget https://github.com/IBM/cloud-pak-cli/releases/download/v3.7.1/cloudctl-linux-amd64.tar.gz.sig
tar -xvf cloudctl-linux-amd64.tar.gz -C /usr/local/bin