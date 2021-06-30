#!/bin/bash


## Db2asaservice 
wget https://raw.githubusercontent.com/IBM/cloud-pak/master/repo/case/ibm-db2aaservice-4.0.0.tgz

# # Install db2aaservice operator using CLI (OLM)

CASE_PACKAGE_NAME="ibm-db2aaservice-4.0.0.tgz"

oc project ${OP_NAMESPACE}

## Install Catalog 

cloudctl case launch --case ${CASE_PACKAGE_NAME} \
    --namespace openshift-marketplace \
    --action installCatalog \
    --inventory db2aaserviceOperatorSetup \
    --tolerance 1

## Install Operator

cloudctl case launch --case ${CASE_PACKAGE_NAME} \
    --namespace ${OP_NAMESPACE} \
    --action installOperator \
    --inventory db2aaserviceOperatorSetup \
    --tolerance 1

# Checking if the db2aaservice operator pods are ready and running. 
# checking status of db2aaservice-operator
./pod-status-check.sh ibm-db2aaservice-cp4d-operator-controller-manager ${OP_NAMESPACE}

# switch to zen namespace
oc project ${NAMESPACE}

# Install db2aaservice Customer Resource
echo '*** executing **** oc create -f db2aaservice-cr.yaml'
result=$(oc create -f db2aaservice-cr.yaml)
echo $result

# check the db2aaservice cr status
./check-cr-status.sh Db2aaserviceService db2aaservice-cr ${NAMESPACE} db2aaserviceStatus
