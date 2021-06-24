#!/bin/bash

# Set up image mirroring. Adding bootstrap artifactory so that the cluster can pull un-promoted catalog images (and zen images)

# echo  '*************************************'
# echo 'setting up imagecontentsource policy for ccs'
# echo  '*************************************'

# echo '*** executing **** oc create -f ccs-mirror.yaml'
# result=$(oc create -f ccs-mirror.yaml)
# echo $result
# sleep 5m


# # create ccs catalog source 

# echo '*** executing **** oc create -f ccs-catalog-source.yaml'
# result=$(oc create -f ccs-catalog-source.yaml)
# echo $result
# sleep 1m

# Create ccs subscription. This will deploy the ccs: 

# echo '*** executing **** oc create -f ccs-sub.yaml'
# result=$(oc create -f ccs-sub.yaml -n ibm-common-services)
# echo $result
# sleep 1m

# Install ccs operator using CLI (OLM)

curl -s https://${GITUSER_SHORT}:${GIT_TOKEN}@raw.github.ibm.com/PrivateCloud-analytics/cpd-case-repo/4.0.0/dev/case-repo-dev/ibm-ccs/1.0.0-746/ibm-ccs-1.0.0-746.tgz -o ibm-ccs-1.0.0-746.tgz
./install-ccs-operator.sh ibm-ccs-1.0.0-746.tgz ibm-common-services

# Checking if the ccs operator pods are ready and running. 

# checking status of ibm-cpc-ccs-operator

#OPERATOR_POD_NAME=$(oc get pods -n ibm-common-services | grep ibm-cpd-ccs-operator | awk '{print $1}')
./pod-status-check.sh ibm-cpd-ccs-operator ibm-common-services

# switch zen namespace

oc project zen

# Create CCS CR: 

echo '*** executing **** oc create -f ccs-cr.yaml'
result=$(oc create -f ccs-cr.yaml)
echo $result

# check the CCS cr status

./check-cr-status.sh ccs ccs-cr zen ccsStatus
