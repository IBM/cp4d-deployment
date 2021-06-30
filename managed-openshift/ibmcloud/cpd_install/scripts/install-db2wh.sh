#!/bin/bash


# Case package. 	
wget https://raw.githubusercontent.com/IBM/cloud-pak/master/repo/case/ibm-db2wh-4.0.0.tgz

# Install db2wh operator using CLI (OLM)	
CASE_PACKAGE_NAME="ibm-db2wh-4.0.0.tgz"

oc project ${OP_NAMESPACE}

## Install Catalog

cloudctl case launch --action installCatalog \
    --case ${CASE_PACKAGE_NAME} \
    --inventory db2whOperatorSetup \
    --namespace openshift-marketplace \
    --tolerance 1

## Install Operator

cloudctl case launch --action installOperator \
    --case ${CASE_PACKAGE_NAME} \
    --inventory db2whOperatorSetup \
    --namespace ${OP_NAMESPACE} \
    --tolerance 1

sleep 1m

# Checking if the db2wh operator podb2wh are ready and running. 	
# checking status of db2wh-operator	
./pod-status-check.sh ibm-db2wh-cp4d-operator ${OP_NAMESPACE}

# switch to zen namespace	
oc project ${NAMESPACE}

# Create db2wh CR: 	
echo '*** executing **** oc create -f db2wh-cr.yaml'
result=$(oc create -f db2wh-cr.yaml)
echo $result

# check the CCS cr status	
./check-cr-status.sh db2whService db2wh-cr ${NAMESPACE} db2whStatus